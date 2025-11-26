const std = @import("std");
const print = std.debug.print;

const imagelib = @import("image.zig");
const Image = imagelib.Image;

pub fn filterIdat(image: Image, idat: []u8) !void {
    print("in filter.zig\n", .{});
    var filter_type: u8 = undefined;
    const filter_stride: usize = image.stride() + 1;
    print("filtering idat\n", .{});
    for (0..image.height) |i| {
        filter_type = try selectFilter(image, i);
        // print("filter({d}) chosen on line {d}\n", .{ filter_type, i });
        idat[i * filter_stride] = filter_type;
        applyFilter(image, i, filter_type, idat[i * filter_stride + 1 .. (i + 1) * filter_stride]);
    }
}

fn selectFilter(image: Image, i: usize) !u8 {
    var best_filter: u8 = 0;
    var best_cost: usize = 0xFFFFFFFF;
    const filtered_line = try std.heap.page_allocator.alloc(u8, image.stride());
    defer std.heap.page_allocator.free(filtered_line);
    for (0..5) |filter_type| {
        applyFilter(image, i, @truncate(filter_type), filtered_line);
        const cost = sad(filtered_line);
        if (cost < best_cost) {
            best_cost = cost;
            best_filter = @truncate(filter_type);
        }
    }
    return best_filter;
}

fn sad(filtered_line: []u8) usize {
    var cost: usize = 0;
    for (filtered_line) |byte| {
        if (byte <= 128) {
            cost += byte;
        } else {
            cost += 255 - byte;
        }
    }
    return cost;
}

fn applyFilter(image: Image, i: usize, filter_type: u8, filtered_line: []u8) void {
    switch (filter_type) {
        0 => std.mem.copyForwards(u8, filtered_line, image.getRow(i)),
        1 => applyFilterSub(image, i, filtered_line),
        2 => applyFilterUp(image, i, filtered_line),
        3 => applyFilterAverage(image, i, filtered_line),
        4 => applyFilterPaeth(image, i, filtered_line),
        else => @panic("not a valid filter type"),
    }
}

fn applyFilterSub(image: Image, i: usize, dest: []u8) void {
    for (0..image.stride()) |j| {
        dest[j] = image.getByte(i, j) -% image.getA(i, j);
    }
}

fn applyFilterUp(image: Image, i: usize, filtered_line: []u8) void {
    for (0..image.stride()) |j| {
        filtered_line[j] = image.getByte(i, j) -% image.getB(i, j);
    }
}

fn avgByte(a: u8, b: u8) u8 {
    return @truncate((@as(u16, a) + @as(u16, b)) / 2);
}

fn applyFilterAverage(image: Image, i: usize, filtered_line: []u8) void {
    for (0..image.stride()) |j| {
        filtered_line[j] = image.getByte(i, j) -% avgByte(image.getA(i, j), image.getB(i, j));
    }
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const ai: i32 = @intCast(a);
    const bi: i32 = @intCast(b);
    const ci: i32 = @intCast(c);
    const p = ai + bi - ci;
    const pa = if (p - ai >= 0) p - ai else ai - p;
    const pb = if (p - bi >= 0) p - bi else bi - p;
    const pc = if (p - ci >= 0) p - ci else ci - p;
    if (pa <= pb and pa <= pc) {
        return a;
    } else if (pb <= pc) {
        return b;
    } else {
        return c;
    }
}

fn applyFilterPaeth(image: Image, i: usize, filtered_line: []u8) void {
    for (0..image.stride()) |j| {
        filtered_line[j] = image.getByte(i, j) -% paeth(image.getA(i, j), image.getB(i, j), image.getC(i, j));
    }
}
