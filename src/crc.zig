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

pub fn crcUpdate(crc: u32, buf: []u8) u32 {
    var c: u32 = crc;
    if (!crc_table_computed) {
        crcInit();
    }
    for (buf) |byte| {
        c = crc_table[(c ^ byte) & 0xFF] ^ (c >> 8);
    }
    return c;
}
