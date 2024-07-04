const std = @import("std");
const tls = @import("tls");
const Certificate = std.crypto.Certificate;
const cmn = @import("common.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    // We are running binary from project root
    const dir = try std.fs.cwd().openDir("example/cert", .{});

    // Init certificate bundle with ca
    var root_ca: Certificate.Bundle = .{};
    defer root_ca.deinit(gpa);
    //try root_ca.rescan(gpa);
    try root_ca.addCertsFromFilePath(gpa, dir, "minica.pem");

    // Make tcp connection
    const host = "localhost";
    const port = 9443;
    var tcp = try std.net.tcpConnectToHost(gpa, host, port);
    defer tcp.close();

    // Upgrade tcp connection to tls
    var diagnostic: tls.ClientOptions.Diagnostic = .{};
    var conn = try tls.client(tcp, .{
        .host = host,
        .root_ca = root_ca,
        //.insecure_skip_verify = true,
        //.cipher_suites = &.{tls.CipherSuite.AES_256_GCM_SHA384},
        .diagnostic = &diagnostic,
    });

    // Show response
    var n: usize = 0;
    while (try conn.next()) |data| {
        n += data.len;
        std.debug.print("{s}", .{data});
    }
    try conn.close();
    std.debug.print("{} bytes read\n", .{n});

    cmn.showDiagnostic(&diagnostic, host);
}
