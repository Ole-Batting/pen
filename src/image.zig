const std = @import("std");
const print = std.debug.print;

const PixelFormatOption = struct {
    color_type: u8,
    channels: usize,
};

pub const PixelFormat = enum {
    grayscale,
    truecolor,
    indexed,
    grayscale_alpha,
    truecolor_alpha,
};

pub const Image = struct {
    data: []u8,
    height: usize,
    width: usize,
    pixel_format: PixelFormat,
    interlacing: bool,

    pub fn filterSize(self: Image) usize {
        return self.height * (self.width * self.bpp() + 1);
    }

    pub fn stride(self: Image) usize {
        return self.width * self.bpp();
    }

    pub fn getRow(self: Image, i: usize) []u8 {
        return self.data[i * self.stride() .. (i + 1) * self.stride()];
    }

    pub fn getByte(self: Image, i: usize, j: usize) u8 {
        return self.data[i * self.stride() + j];
    }

    pub fn setPixel(self: Image, i: usize, j: usize, r: u8, g: u8, b: u8) void {
        self.data[i * self.stride() + j * self.bpp()] = r;
        self.data[i * self.stride() + j * self.bpp() + 1] = g;
        self.data[i * self.stride() + j * self.bpp() + 2] = b;
    }

    pub fn getA(self: Image, i: usize, j: usize) u8 {
        if (j < self.bpp()) {
            return 0;
        } else {
            return self.getByte(i, j - self.bpp());
        }
    }

    pub fn getB(self: Image, i: usize, j: usize) u8 {
        if (i == 0) {
            return 0;
        } else {
            return self.getByte(i - 1, j);
        }
    }

    pub fn getC(self: Image, i: usize, j: usize) u8 {
        if (i == 0 or j < self.bpp()) {
            return 0;
        } else {
            return self.getByte(i - 1, j - self.bpp());
        }
    }

    pub fn bpp(self: Image) usize {
        return switch (self.pixel_format) {
            .grayscale, .indexed => 1,
            .grayscale_alpha => 2,
            .truecolor => 3,
            .truecolor_alpha => 4,
        };
    }

    pub fn colorType(self: Image) u8 {
        return switch (self.pixel_format) {
            .grayscale => 0,
            .truecolor => 2,
            .indexed => 3,
            .grayscale_alpha => 4,
            .truecolor_alpha => 6,
        };
    }
};
