const std = @import("std");
const print = std.debug.print;

const imagelib = @import("image.zig");
const PixelFormat = imagelib.PixelFormat;
const Image = imagelib.Image;
const pnglib = @import("png.zig");
const mandelbrot = @import("mandelbrot.zig");

pub fn main() !void {
    const work_dir = std.fs.cwd();
    const file_path = "mandelbrot.png";
    const file_flags = std.fs.File.CreateFlags{};
    const file = try work_dir.createFile(file_path, file_flags);

    const width: usize = 2440;
    const height: usize = 2440;
    const pixel_format = PixelFormat.truecolor;
    const data = try std.heap.page_allocator.alloc(u8, height * width * 3);
    const image = Image{ .data = data, .width = width, .height = height, .pixel_format = pixel_format, .interlacing = false };

    // set bounds and apply mandelbrot
    const x0: f32 = -2;
    const x1: f32 = 2;
    const y0: f32 = 2;
    const y1: f32 = -2;
    const n_iters_max: usize = 128;

    // set color map
    const n_cmap_steps: usize = 24; // must be divisible with 3

    const r1: u8 = 255;
    const g1: u8 = 255;
    const b1: u8 = 204;

    const r2: u8 = 179;
    const g2: u8 = 64;
    const b2: u8 = 25;

    const r3: u8 = 0;
    const g3: u8 = 204;
    const b3: u8 = 153;

    print("calculating mandelbrot\n", .{});
    var c: mandelbrot.Complex32 = undefined;
    var res: usize = undefined;
    for (0..height) |i| {
        for (0..width) |j| {
            c = mandelbrot.Complex32{
                .real = (x1 - x0) * @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(width - 1)) + x0,
                .imag = (y1 - y0) * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(height - 1)) + y0,
            };
            res = mandelbrot.isInSet(c, n_iters_max);
            const x: usize = @mod(res, n_cmap_steps);
            if (res == 0) {
                image.setPixel(i, j, 0, 0, 0);
            } else {
                image.setPixel(
                    i,
                    j,
                    threePointCicularLerp(r1, r2, r3, x, n_cmap_steps),
                    threePointCicularLerp(g1, g2, g3, x, n_cmap_steps),
                    threePointCicularLerp(b1, b2, b3, x, n_cmap_steps),
                );
            }
        }
    }
    try pnglib.writeImage(file, image);
}

fn f2u(a: f32) u8 {
    return @intFromFloat(127 * (a + 1));
}

fn lerp(a: u8, b: u8, t: f32) u8 {
    const af: f32 = @floatFromInt(a);
    const bf: f32 = @floatFromInt(b);
    return @intFromFloat(af * (1 - t) + bf * t);
}

fn threePointCicularLerp(a: u8, b: u8, c: u8, x: usize, m: usize) u8 {
    const m3 = m / 3;
    var t: f32 = undefined;
    if (x <= m3) {
        t = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(m3));
        return lerp(a, b, t);
    } else if (x <= 2 * m3) {
        t = @as(f32, @floatFromInt(x - m3)) / @as(f32, @floatFromInt(m3));
        return lerp(b, c, t);
    } else {
        t = @as(f32, @floatFromInt(x - 2 * m3)) / @as(f32, @floatFromInt(m3));
        return lerp(c, a, t);
    }
}
