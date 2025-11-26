const std = @import("std");
const print = std.debug.print;

const imagelib = @import("image.zig");
const PixelFormat = imagelib.PixelFormat;
const Image = imagelib.Image;

const filterlib = @import("filter.zig");
const crclib = @import("crc.zig");

pub fn writeImage(file: std.fs.File, image: Image) !void {
    _ = try writeHeaderChunk(file);
    _ = try writeIhdrChunk(file, image);
    _ = try writeIdatChunk(file, image);
    _ = try writeIendChunk(file);
}

fn writeHeaderChunk(file: std.fs.File) !usize {
    return try file.write([_]u8{0x89} ++ "PNG" ++ splitBytes(0x0D0A1A0A));
}

fn writeIendChunk(file: std.fs.File) !usize {
    var chunk_type = [_]u8{ 'I', 'E', 'N', 'D' };
    var chunk_data = [0]u8{};
    return try writeChunk(file, &chunk_type, &chunk_data);
}

fn writeIhdrChunk(file: std.fs.File, image: Image) !usize {
    var chunk_type = [_]u8{ 'I', 'H', 'D', 'R' };
    var chunk_data = splitBytes(@truncate(image.width)) ++
        splitBytes(@truncate(image.height)) ++
        [5]u8{ 8, image.colorType(), 0, 0, @intFromBool(image.interlacing) };
    return try writeChunk(file, &chunk_type, &chunk_data);
}

fn writeIdatChunk(file: std.fs.File, image: Image) !usize {
    var chunk_type = [_]u8{ 'I', 'D', 'A', 'T' };
    const idat = try std.heap.page_allocator.alloc(u8, image.filterSize());
    defer std.heap.page_allocator.free(idat);
    try filterlib.filterIdat(image, idat);
    var fbs = std.io.fixedBufferStream(idat);
    var al = std.ArrayList(u8).init(std.heap.page_allocator);
    defer al.deinit();
    try std.compress.zlib.compress(
        fbs.reader(),
        al.writer(),
        .{ .level = .best },
    );
    return try writeChunk(file, &chunk_type, al.items);
}

fn writeChunk(file: std.fs.File, chunk_type: []u8, chunk_data: []u8) !usize {
    var crc = crclib.crcUpdate(0xFFFFFFFF, chunk_type);
    crc = crclib.crcUpdate(crc, chunk_data) ^ 0xFFFFFFFF;
    const crc_bytes = splitBytes(crc);
    // print("length: {d}\nchunk type: {c}\nchunk_data: {X:0>2}\ncrc: 0x{X}\n", .{ chunk_data.len, chunk_type, chunk_data, crc });
    _ = try file.write(&splitBytes(@truncate(chunk_data.len)));
    _ = try file.write(chunk_type);
    _ = try file.write(chunk_data);
    _ = try file.write(&crc_bytes);
    return 0;
}

fn splitBytes(value: u32) [4]u8 {
    var bytes: [4]u8 = undefined;
    inline for (std.mem.asBytes(&std.mem.nativeToBig(u32, value)), 0..) |byte, i| {
        bytes[i] = byte;
    }
    return bytes;
}
