const std = @import("std");

pub const Complex32 = struct {
    real: f32,
    imag: f32,

    pub fn add(self: Complex32, other: Complex32) Complex32 {
        return Complex32{ .real = self.real + other.real, .imag = self.imag + other.imag };
    }

    pub fn mult(self: Complex32, other: Complex32) Complex32 {
        return Complex32{ .real = self.real * other.real - self.imag * other.imag, .imag = self.real * other.imag + self.imag * other.real };
    }

    pub fn sqlen(self: Complex32) f32 {
        return self.real * self.real + self.imag * self.imag;
    }
};

pub fn isInSet(c: Complex32, n: usize) usize {
    var z = Complex32{ .real = 0, .imag = 0 };
    for (0..n) |i| {
        z = z.mult(z).add(c);
        if (z.sqlen() > 4) {
            return i + 1;
        }
    }
    return 0;
}
