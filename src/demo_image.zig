const std = @import("std");

const imagelib = @import("image.zig");
const PixelFormat = imagelib.PixelFormat;
const Image = imagelib.Image;
const pnglib = @import("png.zig");

pub fn main() !void {
    const work_dir = std.fs.cwd();
    const file_path = "sad.png";
    const file_flags = std.fs.File.CreateFlags{};
    const file = try work_dir.createFile(file_path, file_flags);

    const width: usize = 28;
    const height: usize = 28;
    const pixel_format = PixelFormat.grayscale;
    const data = try std.heap.page_allocator.alloc(u8, height * width * 3);
    const image = Image{ .data = data, .width = width, .height = height, .pixel_format = pixel_format, .interlacing = false };
    var red: u8 = undefined;
    var u: f32 = undefined;
    var v: f32 = undefined;
    for (0..height) |i| {
        for (0..width) |j| {
            u = 2 * @as(f32, @floatFromInt(j)) / (width - 1) - 1;
            v = 2 * @as(f32, @floatFromInt(i)) / (height - 1) - 1;
            red = f2u(@cos(3.1 * (u + v)));
            image.setPixel(i, j, red, red, red);
        }
    }
    try pnglib.writeImage(file, image);
}

fn f2u(a: f32) u8 {
    return @intFromFloat(127 * (a + 1));
}
