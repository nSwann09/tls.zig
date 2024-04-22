const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;
const cbc = @import("cbc.zig");
const client = @import("client.zig").client;

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    //var arena_instance = std.heap.ArenaAllocator.init(gpa);
    //const arena = arena_instance.allocator();

    const url = "https://google.com";
    const uri = try std.Uri.parse(url);
    const host = uri.host.?.percent_encoded;

    var tcp = try std.net.tcpConnectToHost(gpa, host, 443);
    defer tcp.close();

    //try tcp.writeAll(&client_hello);

    var cli = client(tcp);
    try cli.handshake(host);
    std.debug.print("handshake finished\n", .{});

    // var file = try std.fs.cwd().createFile("server_hello", .{});
    // defer file.close();
    // var buf: [4096]u8 = undefined;
    // while (true) {
    //     const n = try tcp.readAll(&buf);
    //     //std.debug.print("{x}\n", .{buf});
    //     try file.writer().writeAll(buf[0..n]);
    //     if (n < buf.len) break;
    // }
}

const client_hello = [_]u8{
    0x16, 0x03, 0x01, 0x00, 0xa5, 0x01, 0x00, 0x00, 0xa1, 0x03, 0x03, 0x00, 0x01, 0x02, 0x03, 0x04,
    0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14,
    0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x00, 0x00, 0x20, 0xcc, 0xa8,
    0xcc, 0xa9, 0xc0, 0x2f, 0xc0, 0x30, 0xc0, 0x2b, 0xc0, 0x2c, 0xc0, 0x13, 0xc0, 0x09, 0xc0, 0x14,
    0xc0, 0x0a, 0x00, 0x9c, 0x00, 0x9d, 0x00, 0x2f, 0x00, 0x35, 0xc0, 0x12, 0x00, 0x0a, 0x01, 0x00,
    0x00, 0x58, 0x00, 0x00, 0x00, 0x18, 0x00, 0x16, 0x00, 0x00, 0x13, 0x65, 0x78, 0x61, 0x6d, 0x70,
    0x6c, 0x65, 0x2e, 0x75, 0x6c, 0x66, 0x68, 0x65, 0x69, 0x6d, 0x2e, 0x6e, 0x65, 0x74, 0x00, 0x05,
    0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x0a, 0x00, 0x08, 0x00, 0x1d, 0x00,
    0x17, 0x00, 0x18, 0x00, 0x19, 0x00, 0x0b, 0x00, 0x02, 0x01, 0x00, 0x00, 0x0d, 0x00, 0x12, 0x00,
    0x10, 0x04, 0x01, 0x04, 0x03, 0x05, 0x01, 0x05, 0x03, 0x06, 0x01, 0x06, 0x03, 0x02, 0x01, 0x02,
    0x03, 0xff, 0x01, 0x00, 0x01, 0x00, 0x00, 0x12, 0x00, 0x00,
};

const server_hello = [_]u8{
    0x16, 0x03, 0x03, 0x00, 0x31, 0x02, 0x00, 0x00, 0x2d, 0x03, 0x03, 0x70, 0x71, 0x72, 0x73, 0x74,
    0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f, 0x80, 0x81, 0x82, 0x83, 0x84,
    0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x00, 0xc0, 0x13, 0x00, 0x00,
    0x05, 0xff, 0x01, 0x00, 0x01, 0x00,
};

test "parse server hello" {
    var stream = std.io.fixedBufferStream(&server_hello);
    const reader = stream.reader();

    const rh = try RecordHeader.parse(reader);
    try testing.expectEqual(RecordHeader.Kind.handshake, rh.kind);
    try testing.expectEqual(0x31, rh.size);

    const hh = try HandshakeHeader.parse(reader);
    try testing.expectEqual(HandshakeHeader.Kind.server_hello, hh.kind);
    try testing.expectEqual(0x2d, hh.size);

    const sh = try ServerHello.parse(reader);
    try testing.expectEqualSlices(u8, &[_]u8{
        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f,
        0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
        0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
    }, &sh.random);
    try testing.expectEqual(5, sh.extension_length);
}

const server_certificate = [_]u8{
    0x16, 0x03, 0x03, 0x03, 0x2f, 0x0b, 0x00, 0x03, 0x2b, 0x00, 0x03, 0x28, 0x00, 0x03, 0x25, 0x30,
    0x82, 0x03, 0x21, 0x30, 0x82, 0x02, 0x09, 0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x08, 0x15, 0x5a,
    0x92, 0xad, 0xc2, 0x04, 0x8f, 0x90, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d,
    0x01, 0x01, 0x0b, 0x05, 0x00, 0x30, 0x22, 0x31, 0x0b, 0x30, 0x09, 0x06, 0x03, 0x55, 0x04, 0x06,
    0x13, 0x02, 0x55, 0x53, 0x31, 0x13, 0x30, 0x11, 0x06, 0x03, 0x55, 0x04, 0x0a, 0x13, 0x0a, 0x45,
    0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x20, 0x43, 0x41, 0x30, 0x1e, 0x17, 0x0d, 0x31, 0x38, 0x31,
    0x30, 0x30, 0x35, 0x30, 0x31, 0x33, 0x38, 0x31, 0x37, 0x5a, 0x17, 0x0d, 0x31, 0x39, 0x31, 0x30,
    0x30, 0x35, 0x30, 0x31, 0x33, 0x38, 0x31, 0x37, 0x5a, 0x30, 0x2b, 0x31, 0x0b, 0x30, 0x09, 0x06,
    0x03, 0x55, 0x04, 0x06, 0x13, 0x02, 0x55, 0x53, 0x31, 0x1c, 0x30, 0x1a, 0x06, 0x03, 0x55, 0x04,
    0x03, 0x13, 0x13, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x2e, 0x75, 0x6c, 0x66, 0x68, 0x65,
    0x69, 0x6d, 0x2e, 0x6e, 0x65, 0x74, 0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86,
    0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00, 0x30, 0x82,
    0x01, 0x0a, 0x02, 0x82, 0x01, 0x01, 0x00, 0xc4, 0x80, 0x36, 0x06, 0xba, 0xe7, 0x47, 0x6b, 0x08,
    0x94, 0x04, 0xec, 0xa7, 0xb6, 0x91, 0x04, 0x3f, 0xf7, 0x92, 0xbc, 0x19, 0xee, 0xfb, 0x7d, 0x74,
    0xd7, 0xa8, 0x0d, 0x00, 0x1e, 0x7b, 0x4b, 0x3a, 0x4a, 0xe6, 0x0f, 0xe8, 0xc0, 0x71, 0xfc, 0x73,
    0xe7, 0x02, 0x4c, 0x0d, 0xbc, 0xf4, 0xbd, 0xd1, 0x1d, 0x39, 0x6b, 0xba, 0x70, 0x46, 0x4a, 0x13,
    0xe9, 0x4a, 0xf8, 0x3d, 0xf3, 0xe1, 0x09, 0x59, 0x54, 0x7b, 0xc9, 0x55, 0xfb, 0x41, 0x2d, 0xa3,
    0x76, 0x52, 0x11, 0xe1, 0xf3, 0xdc, 0x77, 0x6c, 0xaa, 0x53, 0x37, 0x6e, 0xca, 0x3a, 0xec, 0xbe,
    0xc3, 0xaa, 0xb7, 0x3b, 0x31, 0xd5, 0x6c, 0xb6, 0x52, 0x9c, 0x80, 0x98, 0xbc, 0xc9, 0xe0, 0x28,
    0x18, 0xe2, 0x0b, 0xf7, 0xf8, 0xa0, 0x3a, 0xfd, 0x17, 0x04, 0x50, 0x9e, 0xce, 0x79, 0xbd, 0x9f,
    0x39, 0xf1, 0xea, 0x69, 0xec, 0x47, 0x97, 0x2e, 0x83, 0x0f, 0xb5, 0xca, 0x95, 0xde, 0x95, 0xa1,
    0xe6, 0x04, 0x22, 0xd5, 0xee, 0xbe, 0x52, 0x79, 0x54, 0xa1, 0xe7, 0xbf, 0x8a, 0x86, 0xf6, 0x46,
    0x6d, 0x0d, 0x9f, 0x16, 0x95, 0x1a, 0x4c, 0xf7, 0xa0, 0x46, 0x92, 0x59, 0x5c, 0x13, 0x52, 0xf2,
    0x54, 0x9e, 0x5a, 0xfb, 0x4e, 0xbf, 0xd7, 0x7a, 0x37, 0x95, 0x01, 0x44, 0xe4, 0xc0, 0x26, 0x87,
    0x4c, 0x65, 0x3e, 0x40, 0x7d, 0x7d, 0x23, 0x07, 0x44, 0x01, 0xf4, 0x84, 0xff, 0xd0, 0x8f, 0x7a,
    0x1f, 0xa0, 0x52, 0x10, 0xd1, 0xf4, 0xf0, 0xd5, 0xce, 0x79, 0x70, 0x29, 0x32, 0xe2, 0xca, 0xbe,
    0x70, 0x1f, 0xdf, 0xad, 0x6b, 0x4b, 0xb7, 0x11, 0x01, 0xf4, 0x4b, 0xad, 0x66, 0x6a, 0x11, 0x13,
    0x0f, 0xe2, 0xee, 0x82, 0x9e, 0x4d, 0x02, 0x9d, 0xc9, 0x1c, 0xdd, 0x67, 0x16, 0xdb, 0xb9, 0x06,
    0x18, 0x86, 0xed, 0xc1, 0xba, 0x94, 0x21, 0x02, 0x03, 0x01, 0x00, 0x01, 0xa3, 0x52, 0x30, 0x50,
    0x30, 0x0e, 0x06, 0x03, 0x55, 0x1d, 0x0f, 0x01, 0x01, 0xff, 0x04, 0x04, 0x03, 0x02, 0x05, 0xa0,
    0x30, 0x1d, 0x06, 0x03, 0x55, 0x1d, 0x25, 0x04, 0x16, 0x30, 0x14, 0x06, 0x08, 0x2b, 0x06, 0x01,
    0x05, 0x05, 0x07, 0x03, 0x02, 0x06, 0x08, 0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x03, 0x01, 0x30,
    0x1f, 0x06, 0x03, 0x55, 0x1d, 0x23, 0x04, 0x18, 0x30, 0x16, 0x80, 0x14, 0x89, 0x4f, 0xde, 0x5b,
    0xcc, 0x69, 0xe2, 0x52, 0xcf, 0x3e, 0xa3, 0x00, 0xdf, 0xb1, 0x97, 0xb8, 0x1d, 0xe1, 0xc1, 0x46,
    0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b, 0x05, 0x00, 0x03,
    0x82, 0x01, 0x01, 0x00, 0x59, 0x16, 0x45, 0xa6, 0x9a, 0x2e, 0x37, 0x79, 0xe4, 0xf6, 0xdd, 0x27,
    0x1a, 0xba, 0x1c, 0x0b, 0xfd, 0x6c, 0xd7, 0x55, 0x99, 0xb5, 0xe7, 0xc3, 0x6e, 0x53, 0x3e, 0xff,
    0x36, 0x59, 0x08, 0x43, 0x24, 0xc9, 0xe7, 0xa5, 0x04, 0x07, 0x9d, 0x39, 0xe0, 0xd4, 0x29, 0x87,
    0xff, 0xe3, 0xeb, 0xdd, 0x09, 0xc1, 0xcf, 0x1d, 0x91, 0x44, 0x55, 0x87, 0x0b, 0x57, 0x1d, 0xd1,
    0x9b, 0xdf, 0x1d, 0x24, 0xf8, 0xbb, 0x9a, 0x11, 0xfe, 0x80, 0xfd, 0x59, 0x2b, 0xa0, 0x39, 0x8c,
    0xde, 0x11, 0xe2, 0x65, 0x1e, 0x61, 0x8c, 0xe5, 0x98, 0xfa, 0x96, 0xe5, 0x37, 0x2e, 0xef, 0x3d,
    0x24, 0x8a, 0xfd, 0xe1, 0x74, 0x63, 0xeb, 0xbf, 0xab, 0xb8, 0xe4, 0xd1, 0xab, 0x50, 0x2a, 0x54,
    0xec, 0x00, 0x64, 0xe9, 0x2f, 0x78, 0x19, 0x66, 0x0d, 0x3f, 0x27, 0xcf, 0x20, 0x9e, 0x66, 0x7f,
    0xce, 0x5a, 0xe2, 0xe4, 0xac, 0x99, 0xc7, 0xc9, 0x38, 0x18, 0xf8, 0xb2, 0x51, 0x07, 0x22, 0xdf,
    0xed, 0x97, 0xf3, 0x2e, 0x3e, 0x93, 0x49, 0xd4, 0xc6, 0x6c, 0x9e, 0xa6, 0x39, 0x6d, 0x74, 0x44,
    0x62, 0xa0, 0x6b, 0x42, 0xc6, 0xd5, 0xba, 0x68, 0x8e, 0xac, 0x3a, 0x01, 0x7b, 0xdd, 0xfc, 0x8e,
    0x2c, 0xfc, 0xad, 0x27, 0xcb, 0x69, 0xd3, 0xcc, 0xdc, 0xa2, 0x80, 0x41, 0x44, 0x65, 0xd3, 0xae,
    0x34, 0x8c, 0xe0, 0xf3, 0x4a, 0xb2, 0xfb, 0x9c, 0x61, 0x83, 0x71, 0x31, 0x2b, 0x19, 0x10, 0x41,
    0x64, 0x1c, 0x23, 0x7f, 0x11, 0xa5, 0xd6, 0x5c, 0x84, 0x4f, 0x04, 0x04, 0x84, 0x99, 0x38, 0x71,
    0x2b, 0x95, 0x9e, 0xd6, 0x85, 0xbc, 0x5c, 0x5d, 0xd6, 0x45, 0xed, 0x19, 0x90, 0x94, 0x73, 0x40,
    0x29, 0x26, 0xdc, 0xb4, 0x0e, 0x34, 0x69, 0xa1, 0x59, 0x41, 0xe8, 0xe2, 0xcc, 0xa8, 0x4b, 0xb6,
    0x08, 0x46, 0x36, 0xa0,
};

test "parse server certificate" {
    var stream = std.io.fixedBufferStream(&server_certificate);
    const reader = stream.reader();

    const rh = try RecordHeader.parse(reader);
    try testing.expectEqual(RecordHeader.Kind.handshake, rh.kind);
    try testing.expectEqual(815, rh.size);

    const hh = try HandshakeHeader.parse(reader);
    try testing.expectEqual(HandshakeHeader.Kind.server_certificate, hh.kind);
    try testing.expectEqual(811, hh.size);

    const sc = try ServerCertificate.parse(reader);
    try testing.expectEqual(805, sc.cert.len);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x08, 0x46, 0x36, 0xa0 }, sc.cert[801..]);
}

const server_key_exchange = [_]u8{
    0x16, 0x03, 0x03, 0x01, 0x2c, 0x0c, 0x00, 0x01, 0x28, 0x03, 0x00, 0x1d, 0x20, 0x9f, 0xd7, 0xad, 0x6d,
    0xcf, 0xf4, 0x29, 0x8d, 0xd3, 0xf9, 0x6d, 0x5b, 0x1b, 0x2a, 0xf9, 0x10, 0xa0, 0x53, 0x5b, 0x14, 0x88,
    0xd7, 0xf8, 0xfa, 0xbb, 0x34, 0x9a, 0x98, 0x28, 0x80, 0xb6, 0x15, 0x04, 0x01, 0x01, 0x00, 0x04, 0x02,
    0xb6, 0x61, 0xf7, 0xc1, 0x91, 0xee, 0x59, 0xbe, 0x45, 0x37, 0x66, 0x39, 0xbd, 0xc3, 0xd4, 0xbb, 0x81,
    0xe1, 0x15, 0xca, 0x73, 0xc8, 0x34, 0x8b, 0x52, 0x5b, 0x0d, 0x23, 0x38, 0xaa, 0x14, 0x46, 0x67, 0xed,
    0x94, 0x31, 0x02, 0x14, 0x12, 0xcd, 0x9b, 0x84, 0x4c, 0xba, 0x29, 0x93, 0x4a, 0xaa, 0xcc, 0xe8, 0x73,
    0x41, 0x4e, 0xc1, 0x1c, 0xb0, 0x2e, 0x27, 0x2d, 0x0a, 0xd8, 0x1f, 0x76, 0x7d, 0x33, 0x07, 0x67, 0x21,
    0xf1, 0x3b, 0xf3, 0x60, 0x20, 0xcf, 0x0b, 0x1f, 0xd0, 0xec, 0xb0, 0x78, 0xde, 0x11, 0x28, 0xbe, 0xba,
    0x09, 0x49, 0xeb, 0xec, 0xe1, 0xa1, 0xf9, 0x6e, 0x20, 0x9d, 0xc3, 0x6e, 0x4f, 0xff, 0xd3, 0x6b, 0x67,
    0x3a, 0x7d, 0xdc, 0x15, 0x97, 0xad, 0x44, 0x08, 0xe4, 0x85, 0xc4, 0xad, 0xb2, 0xc8, 0x73, 0x84, 0x12,
    0x49, 0x37, 0x25, 0x23, 0x80, 0x9e, 0x43, 0x12, 0xd0, 0xc7, 0xb3, 0x52, 0x2e, 0xf9, 0x83, 0xca, 0xc1,
    0xe0, 0x39, 0x35, 0xff, 0x13, 0xa8, 0xe9, 0x6b, 0xa6, 0x81, 0xa6, 0x2e, 0x40, 0xd3, 0xe7, 0x0a, 0x7f,
    0xf3, 0x58, 0x66, 0xd3, 0xd9, 0x99, 0x3f, 0x9e, 0x26, 0xa6, 0x34, 0xc8, 0x1b, 0x4e, 0x71, 0x38, 0x0f,
    0xcd, 0xd6, 0xf4, 0xe8, 0x35, 0xf7, 0x5a, 0x64, 0x09, 0xc7, 0xdc, 0x2c, 0x07, 0x41, 0x0e, 0x6f, 0x87,
    0x85, 0x8c, 0x7b, 0x94, 0xc0, 0x1c, 0x2e, 0x32, 0xf2, 0x91, 0x76, 0x9e, 0xac, 0xca, 0x71, 0x64, 0x3b,
    0x8b, 0x98, 0xa9, 0x63, 0xdf, 0x0a, 0x32, 0x9b, 0xea, 0x4e, 0xd6, 0x39, 0x7e, 0x8c, 0xd0, 0x1a, 0x11,
    0x0a, 0xb3, 0x61, 0xac, 0x5b, 0xad, 0x1c, 0xcd, 0x84, 0x0a, 0x6c, 0x8a, 0x6e, 0xaa, 0x00, 0x1a, 0x9d,
    0x7d, 0x87, 0xdc, 0x33, 0x18, 0x64, 0x35, 0x71, 0x22, 0x6c, 0x4d, 0xd2, 0xc2, 0xac, 0x41, 0xfb,
};

test "parse server key exchange" {
    var stream = std.io.fixedBufferStream(&server_key_exchange);
    const reader = stream.reader();

    const rh = try RecordHeader.parse(reader);
    try testing.expectEqual(RecordHeader.Kind.handshake, rh.kind);
    try testing.expectEqual(300, rh.size);

    const hh = try HandshakeHeader.parse(reader);
    try testing.expectEqual(HandshakeHeader.Kind.server_key_exchange, hh.kind);
    try testing.expectEqual(296, hh.size);
}

const RecordHeader = struct {
    const Kind = enum(u8) {
        alert = 0x15,
        handshake = 0x16,
        data = 0x17,
    };

    kind: Kind,
    version: ProtocolVersion,
    size: u16,

    fn parse(reader: anytype) !RecordHeader {
        const k = try reader.readByte();
        if (k < 0x15 or k > 0x17) return error.UnknownRecordHeaderKind;
        const p = try reader.readInt(u16, .big);
        if (p != 0x0303) return error.UnknownRecordHeaderVersion;
        const size = try reader.readInt(u16, .big);
        return .{
            .kind = @enumFromInt(k),
            .version = .tls12,
            .size = size,
        };
    }
};

const ProtocolVersion = enum(u16) {
    tls12 = 0x0303,
};

const ChiperSuite = enum(u16) {
    TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA = 0xc013,
};

const HandshakeHeader = struct {
    const Kind = enum(u8) {
        server_hello = 0x02,
        server_certificate = 0x0b,
        server_key_exchange = 0x0c,
    };
    kind: Kind,
    size: u24,

    fn parse(reader: anytype) !HandshakeHeader {
        const k = try reader.readByte();
        if (!(k == 0x02 or k == 0x0b or k == 0x0c)) return error.UnknownHandshakeHeaderKind;
        const size = try reader.readInt(u24, .big);
        return .{
            .kind = @enumFromInt(k),
            .size = size,
        };
    }
};

const ServerHello = struct {
    version: ProtocolVersion,
    random: [32]u8,
    session_id: u8,
    chiper_suite: ChiperSuite,
    extension_length: u16,

    fn parse(reader: anytype) !ServerHello {
        const v = try reader.readInt(u16, .big);
        if (v != 0x0303) return error.UnknownServerHelloVersion;

        var random: [32]u8 = undefined;
        try reader.readNoEof(&random);

        const session_id = try reader.readByte();

        const cs = try reader.readInt(u16, .big);
        if (cs != 0xc013) return error.UnknownServerHelloChiperSuite;

        const cm = try reader.readByte();
        _ = cm; // compression method

        const el = try reader.readInt(u16, .big);
        try reader.skipBytes(el, .{});

        return .{
            .version = @enumFromInt(v),
            .random = random,
            .session_id = session_id,
            .chiper_suite = @enumFromInt(cs),
            .extension_length = el,
        };
    }
};

const ServerCertificate = struct {
    var buffer: [4096]u8 = undefined;

    cert: []const u8,

    fn parse(reader: anytype) !ServerCertificate {
        const certs_len = try reader.readInt(u24, .big);
        const cert_len = try reader.readInt(u24, .big);
        // read first certificate skip others
        try reader.readNoEof(buffer[0..cert_len]);
        if (certs_len > cert_len + 3) {
            try reader.skipBytes(certs_len - cert_len - 3, .{});
        }
        return .{
            .cert = buffer[0..cert_len],
        };
    }
};

// test "enum" {
//     const e: RecordHeader.Kind = @enumFromInt(0x14);
//     std.debug.print("e: {}\n", .{e});
// }

test "client key exchange generation" {
    const bytesToHex = std.fmt.bytesToHex;
    const Sha256 = std.crypto.auth.hmac.sha2.HmacSha256;
    const CipherT = std.crypto.tls.ApplicationCipherT(cbc.CBCAes128, std.crypto.hash.Sha1);

    var client_private_key: [32]u8 = undefined;
    var server_random: [32]u8 = undefined;
    var client_random: [32]u8 = undefined;
    var server_public_key: [32]u8 = undefined;
    _ = try fmt.hexToBytes(client_private_key[0..], "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f");
    _ = try fmt.hexToBytes(server_random[0..], "707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f");
    _ = try fmt.hexToBytes(client_random[0..], "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f");
    _ = try fmt.hexToBytes(server_public_key[0..], "9fd7ad6dcff4298dd3f96d5b1b2af910a0535b1488d7f8fabb349a982880b615");

    // public from private key
    {
        const client_public_key = try std.crypto.dh.X25519.recoverPublicKey(client_private_key);
        try std.testing.expectEqualStrings(
            "358072d6365880d1aeea329adf9121383851ed21a28e3b75e965d0d2cd166254",
            &bytesToHex(client_public_key, .lower),
        );
    }

    var master_secret: [32 + 16]u8 = undefined;
    {
        // pre master secret calculation
        const pre_master_secret = try std.crypto.dh.X25519.scalarmult(client_private_key, server_public_key);
        try std.testing.expectEqualStrings(
            "df4a291baa1eb7cfa6934b29b474baad2697e29f1f920dcc77c8a0a088447624",
            &bytesToHex(pre_master_secret, .lower),
        );

        // master secret calculation
        const prefix = "master secret";
        var a_seed: [prefix.len + 32 * 2]u8 = undefined;
        @memcpy(a_seed[0..prefix.len], prefix);
        @memcpy(a_seed[prefix.len..][0..32], &client_random);
        @memcpy(a_seed[prefix.len + 32 ..], &server_random);

        var a1: [32]u8 = undefined;
        var a2: [32]u8 = undefined;
        Sha256.create(&a1, &a_seed, &pre_master_secret);
        Sha256.create(&a2, &a1, &pre_master_secret);

        var p_seed: [a_seed.len + 32]u8 = undefined;
        @memcpy(p_seed[0..a1.len], &a1);
        @memcpy(p_seed[a1.len..], &a_seed);

        var p1: [32]u8 = undefined;
        var p2: [32]u8 = undefined;
        Sha256.create(&p1, &p_seed, &pre_master_secret);

        @memcpy(p_seed[0..a1.len], &a2);
        @memcpy(p_seed[a1.len..], &a_seed);
        Sha256.create(&p2, &p_seed, &pre_master_secret);

        @memcpy(master_secret[0..32], &p1);
        @memcpy(master_secret[32..], p2[0..16]);

        try testing.expectEqualStrings(
            "916abf9da55973e13614ae0a3f5d3f37b023ba129aee02cc9134338127cd7049781c8e19fc1eb2a7387ac06ae237344c",
            &bytesToHex(master_secret, .lower),
        );
    }

    var cipher: CipherT = undefined;
    { // final encryption keys
        const prefix = "key expansion";
        var a_seed: [prefix.len + 32 * 2]u8 = undefined;
        @memcpy(a_seed[0..prefix.len], prefix);
        @memcpy(a_seed[prefix.len..][0..32], &server_random);
        @memcpy(a_seed[prefix.len + 32 ..], &client_random);

        const a0 = a_seed;
        var a1: [32]u8 = undefined;
        var a2: [32]u8 = undefined;
        var a3: [32]u8 = undefined;
        var a4: [32]u8 = undefined;
        Sha256.create(&a1, &a0, &master_secret);
        Sha256.create(&a2, &a1, &master_secret);
        Sha256.create(&a3, &a2, &master_secret);
        Sha256.create(&a4, &a3, &master_secret);

        var p1: [32]u8 = undefined;
        var p2: [32]u8 = undefined;
        var p3: [32]u8 = undefined;
        var p4: [32]u8 = undefined;

        var p_seed: [a_seed.len + 32]u8 = undefined;
        @memcpy(p_seed[32..], &a_seed);
        @memcpy(p_seed[0..32], &a1);
        Sha256.create(&p1, &p_seed, &master_secret);
        @memcpy(p_seed[0..32], &a2);
        Sha256.create(&p2, &p_seed, &master_secret);
        @memcpy(p_seed[0..32], &a3);
        Sha256.create(&p3, &p_seed, &master_secret);
        @memcpy(p_seed[0..32], &a4);
        Sha256.create(&p4, &p_seed, &master_secret);

        var p: [32 * 4]u8 = undefined;
        @memcpy(p[0..32], &p1);
        @memcpy(p[32..64], &p2);
        @memcpy(p[64..96], &p3);
        @memcpy(p[96..], &p4);

        const client_secret = p[0..20];
        const server_secret = p[20..40];
        const client_key = p[40..56];
        const server_key = p[56..72];
        const client_iv = p[72..88];
        const server_iv = p[88..104];

        try testing.expectEqualStrings("1b7d117c7d5f690bc263cae8ef60af0f1878acc2", &bytesToHex(client_secret, .lower));
        try testing.expectEqualStrings("2ad8bdd8c601a617126f63540eb20906f781fad2", &bytesToHex(server_secret, .lower));
        try testing.expectEqualStrings("f656d037b173ef3e11169f27231a84b6", &bytesToHex(client_key, .lower));
        try testing.expectEqualStrings("752a18e7a9fcb7cbcdd8f98dd8f769eb", &bytesToHex(server_key, .lower));
        try testing.expectEqualStrings("a0d2550c9238eebfef5c32251abb67d6", &bytesToHex(client_iv, .lower));
        try testing.expectEqualStrings("434528db4937d540d393135e06a11bb8", &bytesToHex(server_iv, .lower));

        cipher = .{
            .client_secret = p[0..20].*,
            .server_secret = p[20..40].*,
            .client_key = p[40..56].*,
            .server_key = p[56..72].*,
            .client_iv = p[72..88].*,
            .server_iv = p[88..104].*,
        };
    }

    const mac_length = CipherT.Hash.digest_length;

    var buf: [1024 * 16 + 1024]u8 = undefined;
    const sequence: u64 = 1;
    const nonce = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    };
    const data = "ping";

    // encrypt data
    const ciphertext = brk: {
        const rechdr = [_]u8{ 0x17, 0x03, 0x03 };

        std.mem.writeInt(u64, buf[0..8], sequence, .big);
        @memcpy(buf[8..][0..3], &rechdr);
        std.mem.writeInt(u16, buf[11..][0..2], @intCast(data.len), .big);
        @memcpy(buf[13..][0..data.len], data);
        const mac_buf = buf[0 .. 13 + data.len];

        var mac: [mac_length]u8 = undefined;
        CipherT.Hmac.create(&mac, mac_buf, &cipher.client_secret);

        @memcpy(buf[0..data.len], data);
        @memcpy(buf[data.len..][0..mac.len], &mac);

        const unpadded_len = data.len + mac.len;
        const padded_len = CipherT.AEAD.paddedLength(unpadded_len);
        const padding_byte: u8 = @intCast(padded_len - unpadded_len - 1);
        @memset(buf[unpadded_len..padded_len], padding_byte);
        const cleartext = buf[0..padded_len];

        const z = CipherT.AEAD.init(cipher.client_key);
        const ciphertext = buf[0..CipherT.AEAD.paddedLength(cleartext.len)];
        z.encrypt(ciphertext, cleartext, nonce);

        const expected_cipertext = [_]u8{
            0x6c, 0x42, 0x1c, 0x71, 0xc4, 0x2b, 0x18, 0x3b, 0xfa, 0x06, 0x19, 0x5d, 0x13, 0x3d, 0x0a, 0x09,
            0xd0, 0x0f, 0xc7, 0xcb, 0x4e, 0x0f, 0x5d, 0x1c, 0xda, 0x59, 0xd1, 0x47, 0xec, 0x79, 0x0c, 0x99,
            0xC9, 0x05, 0x85, 0x2B, 0xBD, 0x68, 0x7C, 0xCF, 0xC8, 0xD4, 0xD1, 0x2C, 0xFA, 0x54, 0xA4, 0x38,
        };
        try testing.expectEqualSlices(u8, &expected_cipertext, ciphertext);
        break :brk ciphertext;
    };

    // decrypt
    {
        const z = CipherT.AEAD.init(cipher.client_key);
        const decrypted = buf[0..CipherT.AEAD.unpaddedLength(ciphertext.len)];
        try z.decrypt(decrypted, ciphertext, nonce);
        const padding_len = decrypted[decrypted.len - 1] + 1;
        const cleartext = decrypted[0 .. decrypted.len - padding_len - mac_length];

        try testing.expectEqualSlices(u8, data, cleartext);
    }
}
