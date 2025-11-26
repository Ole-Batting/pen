const std = @import("std");
const print = std.debug.print;

fn sword32(value: u32) [4]u8 {
    var bytes: [4]u8 = undefined;
    inline for (std.mem.asBytes(&std.mem.nativeToBig(u32, value)), 0..) |byte, i| {
        bytes[i] = byte;
    }
    return bytes;
}

fn write_header(file: std.fs.File) !usize {
    return try file.write([_]u8{0x89} ++ "PNG" ++ sword32(0x0D0A1A0A));
}

var crc_table: [256]u32 = undefined;
var crc_table_computed = false;

fn crcInit() void {
    var c: u32 = undefined;
    for (0..256) |n| {
        c = @truncate(n);
        for (0..8) |_| {
            if ((c & 1) == 1) {
                c = 0xEDB88320 ^ (c >> 1);
            } else {
                c = c >> 1;
            }
        }
        crc_table[n] = c;
    }
    crc_table_computed = true;
}

fn crcUpdate(crc: u32, buf: []u8) u32 {
    var c: u32 = crc;
    if (!crc_table_computed) {
        crcInit();
    }
    for (buf) |byte| {
        c = crc_table[(c ^ byte) & 0xFF] ^ (c >> 8);
    }
    return c;
}

fn write_chunk(file: std.fs.File, chunk_type: []u8, chunk_data: []u8) !usize {
    var crc = crcUpdate(0xFFFFFFFF, chunk_type);
    crc = crcUpdate(crc, chunk_data) ^ 0xFFFFFFFF;
    const crc_bytes = sword32(crc);
    print("length: {d}\nchunk type: {c}\nchunk_data: {X:0>2}\ncrc: 0x{X}\n", .{ chunk_data.len, chunk_type, chunk_data, crc });
    _ = try file.write(&sword32(@truncate(chunk_data.len)));
    _ = try file.write(chunk_type);
    _ = try file.write(chunk_data);
    _ = try file.write(&crc_bytes);
    return 0;
}

// TODO: use enums for options
fn write_ihdr(
    file: std.fs.File,
    width: usize,
    height: usize,
    bdepth: u8,
    cdepth: u8,
    itlc: bool,
) !usize {
    var chunk_type = [_]u8{ 'I', 'H', 'D', 'R' };
    var chunk_data = sword32(@truncate(width)) ++ sword32(@truncate(height)) ++ [5]u8{ bdepth, cdepth, 0, 0, @intFromBool(itlc) };
    return try write_chunk(file, &chunk_type, &chunk_data);
}

fn write_iend(file: std.fs.File) !usize {
    var chunk_type = [_]u8{ 'I', 'E', 'N', 'D' };
    var chunk_data = [0]u8{};
    return try write_chunk(file, &chunk_type, &chunk_data);
}

fn filter_idat(
    source: []u8,
    dest: []u8,
    width: usize,
    height: usize,
    channels: usize,
    filter_type: u8,
) void {
    const stride = width * channels;
    var src_index: usize = 0;
    var dst_index: usize = 0;
    for (0..height) |row| {
        dest[dst_index] = filter_type;
        dst_index += 1;
        switch (filter_type) {
            1 => { // Sub: Byte A (to the left)
                for (0..channels) |c| {
                    dest[dst_index + c] = source[src_index + c];
                }
                for (channels..stride) |i| {
                    dest[dst_index + i] = source[src_index + i] -% source[src_index + i - channels];
                }
            },
            2 => { // Up: Byte B (above)
                if (row == 0) {
                    std.mem.copyForwards(u8, dest[dst_index .. dst_index + stride], source[src_index .. src_index + stride]);
                } else {
                    for (0..stride) |i| {
                        dest[dst_index + i] = source[src_index + i] -% source[src_index + i - stride];
                    }
                }
            },
            // 3 => { // Average: Mean of bytes A and B, rounded down
            //     var a: u8 = undefined;
            //     var b: u8 = undefined;
            //     for (0..stride) |i| {
            //         if
            //     }
            else => {
                std.mem.copyForwards(u8, dest[dst_index .. dst_index + stride], source[src_index .. src_index + stride]);
            },
        }
        src_index += stride;
        dst_index += stride;
    }
}

fn write_idat(
    allocator: *std.mem.Allocator,
    file: std.fs.File,
    image_data: []u8,
    width: usize,
    height: usize,
    channels: usize,
    filter_type: u8,
) !usize {
    const image_data_filtered = try allocator.alloc(u8, height * (width * channels + 1));
    defer allocator.free(image_data_filtered);
    filter_idat(image_data, image_data_filtered, width, height, channels, filter_type);
    // print("filtered: {X:0>2}\n", .{image_data_filtered});
    var fbs = std.io.fixedBufferStream(image_data_filtered);
    var al = std.ArrayList(u8).init(allocator.*);
    defer al.deinit();
    try std.compress.zlib.compress(
        fbs.reader(),
        al.writer(),
        .{ .level = .best },
    );
    var chunk_type = [4]u8{ 'I', 'D', 'A', 'T' };
    return try write_chunk(file, &chunk_type, al.items);
}

fn write(
    allocator: *std.mem.Allocator,
    file: std.fs.File,
    image_data: []u8,
    width: usize,
    height: usize,
    channels: usize,
    filter_type: u8,
) !usize {
    _ = try write_header(file);
    _ = try write_ihdr(
        file,
        width,
        height,
        8,
        2,
        false,
    );
    _ = try write_idat(allocator, file, image_data, width, height, channels, filter_type);
    _ = try write_iend(file);
    return 0;
}

pub fn main() !void {
    const work_dir = std.fs.cwd();
    const file_path = "filter_2.png";
    const flags = std.fs.File.CreateFlags{};
    const file = try work_dir.createFile(file_path, flags);
    var allocator = std.heap.page_allocator;

    const width: usize = 16;
    const height: usize = 16;
    const channels: usize = 3;
    var image_data = try allocator.alloc(u8, height * width * channels);
    var index: usize = undefined;
    for (0..height) |i| {
        for (0..width) |j| {
            index = (i * width * channels) + (j * channels);
            image_data[index] = @truncate(16 * i); // red scales vertically
            image_data[index + 1] = @truncate(16 * j); // green scales horizontally
            image_data[index + 2] = 0; // blue constant 0
        }
    }

    const filter_type: u8 = 2;
    const retval = try write(&allocator, file, image_data, width, height, channels, filter_type);
    print("main: {d}\n", .{retval});
}
