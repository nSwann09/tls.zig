const std = @import("std");
const assert = std.debug.assert;
const tls = std.crypto.tls;

const record = @import("record.zig");
const Cipher = @import("cipher.zig").Cipher;
const HandshakeType = @import("handshake_common.zig").HandshakeType;

pub const Options = @import("handshake.zig").Options;

pub fn Connection(comptime Stream: type) type {
    return struct {
        stream: Stream, // underlying stream
        rec_rdr: record.Reader(Stream),

        cipher: Cipher = undefined,
        cipher_client_seq: usize = 0,
        cipher_server_seq: usize = 0,

        write_buf: [tls.max_ciphertext_record_len]u8 = undefined,
        read_buf: []const u8 = "",
        received_close_notify: bool = false,

        const Self = @This();

        /// Encrypts and writes single tls record to the stream.
        fn writeRecord(c: *Self, content_type: tls.ContentType, bytes: []const u8) !void {
            assert(bytes.len <= tls.max_cipertext_inner_record_len);
            const rec = try c.cipher.encrypt(&c.write_buf, c.cipher_client_seq, content_type, bytes);
            c.cipher_client_seq += 1;
            try c.stream.writeAll(rec);
        }

        /// Returns next record of cleartext data.
        /// Can be used in iterator like loop without memcpy to another buffer:
        ///   while (try client.next()) |buf| { ... }
        pub fn next(c: *Self) ReadError!?[]const u8 {
            const content_type, const data = try c.nextRecord() orelse return null;
            if (content_type != .application_data) return error.TlsUnexpectedMessage;
            return data;
        }

        fn nextRecord(c: *Self) ReadError!?struct { tls.ContentType, []const u8 } {
            if (c.eof()) return null;
            while (true) {
                const content_type, const cleartext = try c.rec_rdr.nextDecrypt(c.cipher, c.cipher_server_seq) orelse return null;
                c.cipher_server_seq += 1;

                switch (content_type) {
                    .application_data => {},
                    .handshake => {
                        const handshake_type: HandshakeType = @enumFromInt(cleartext[0]);
                        // skip new session ticket and read next record
                        if (handshake_type == .new_session_ticket)
                            continue;
                    },
                    .alert => {
                        if (cleartext.len < 2) return error.TlsAlertUnknown;
                        const level: tls.AlertLevel = @enumFromInt(cleartext[0]);
                        const desc: tls.AlertDescription = @enumFromInt(cleartext[1]);
                        _ = level;
                        try desc.toError();
                        // server side clean shutdown
                        c.received_close_notify = true;
                        return null;
                    },
                    else => return error.TlsUnexpectedMessage,
                }
                return .{ content_type, cleartext };
            }
        }

        pub fn eof(c: *Self) bool {
            return c.received_close_notify and c.read_buf.len == 0;
        }

        pub fn close(c: *Self) !void {
            if (c.received_close_notify) return;
            const close_notify_alert = [2]u8{
                @intFromEnum(tls.AlertLevel.warning),
                @intFromEnum(tls.AlertDescription.close_notify),
            };
            try c.writeRecord(.alert, &close_notify_alert);
        }

        // read, write interface

        pub const ReadError = Stream.ReadError || tls.AlertDescription.Error ||
            error{
            TlsBadVersion,
            TlsUnexpectedMessage,
            TlsRecordOverflow,
            TlsDecryptError,
            TlsBadRecordMac,
            BufferOverflow,
        };
        pub const WriteError = Stream.WriteError ||
            error{BufferOverflow};

        pub const Reader = std.io.Reader(*Self, ReadError, read);
        pub const Writer = std.io.Writer(*Self, WriteError, write);

        pub fn reader(c: *Self) Reader {
            return .{ .context = c };
        }

        pub fn writer(c: *Self) Writer {
            return .{ .context = c };
        }

        /// Encrypts cleartext and writes it to the underlying stream as single
        /// tls record. Max single tls record payload length is 1<<14 (16K)
        /// bytes.
        pub fn write(c: *Self, bytes: []const u8) WriteError!usize {
            const n = @min(bytes.len, tls.max_cipertext_inner_record_len);
            try c.writeRecord(.application_data, bytes[0..n]);
            return n;
        }

        /// Encrypts cleartext and writes it to the underlying stream. If needed
        /// splits cleartext into multiple tls record.
        pub fn writeAll(c: *Self, bytes: []const u8) WriteError!void {
            var index: usize = 0;
            while (index < bytes.len) {
                index += try c.write(bytes[index..]);
            }
        }

        pub fn read(c: *Self, buffer: []u8) ReadError!usize {
            if (c.read_buf.len == 0) {
                c.read_buf = try c.next() orelse return 0;
            }
            const n = @min(c.read_buf.len, buffer.len);
            @memcpy(buffer[0..n], c.read_buf[0..n]);
            c.read_buf = c.read_buf[n..];
            return n;
        }

        /// Returns the number of bytes read. If the number read is smaller than
        /// `buffer.len`, it means the stream reached the end.
        pub fn readAll(c: *Self, buffer: []u8) ReadError!usize {
            return c.readAtLeast(buffer, buffer.len);
        }

        /// Returns the number of bytes read, calling the underlying read function
        /// the minimal number of times until the buffer has at least `len` bytes
        /// filled. If the number read is less than `len` it means the stream
        /// reached the end.
        pub fn readAtLeast(c: *Self, buffer: []u8, len: usize) ReadError!usize {
            assert(len <= buffer.len);
            var index: usize = 0;
            while (index < len) {
                const amt = try c.read(buffer[index..]);
                if (amt == 0) break;
                index += amt;
            }
            return index;
        }

        /// Returns the number of bytes read. If the number read is less than
        /// the space provided it means the stream reached the end.
        pub fn readv(c: *Self, iovecs: []std.posix.iovec) !usize {
            var vp: VecPut = .{ .iovecs = iovecs };
            while (true) {
                if (c.read_buf.len == 0) {
                    c.read_buf = try c.next() orelse break;
                }
                const n = vp.put(c.read_buf);
                const read_buf_len = c.read_buf.len;
                c.read_buf = c.read_buf[n..];
                if ((n < read_buf_len) or
                    (n == read_buf_len and !c.rec_rdr.hasMore()))
                    break;
            }
            return vp.total;
        }
    };
}

const testing = std.testing;
const data12 = @import("testdata/tls12.zig");
const testu = @import("testu.zig");

test "encrypt decrypt" {
    var output_buf: [1024]u8 = undefined;
    const stream = testu.Stream.init(&(data12.server_pong ** 3), &output_buf);
    var conn: Connection(@TypeOf(stream)) = .{ .stream = stream, .rec_rdr = record.reader(stream) };
    conn.cipher = try Cipher.initTLS12(.ECDHE_RSA_WITH_AES_128_CBC_SHA, &data12.key_material, testu.random(0));

    conn.stream.output.reset();
    { // encrypt verify data from example
        conn.cipher_client_seq = 0; //
        _ = testu.random(0x40); // sets iv to 40, 41, ... 4f
        try conn.writeRecord(.handshake, &data12.client_finished);
        try testing.expectEqualSlices(u8, &data12.verify_data_encrypted_msg, conn.stream.output.getWritten());
    }

    conn.stream.output.reset();
    { // encrypt ping
        const cleartext = "ping";
        _ = testu.random(0); // sets iv to 00, 01, ... 0f
        conn.cipher_client_seq = 1;

        try conn.writeAll(cleartext);
        try testing.expectEqualSlices(u8, &data12.encrypted_ping_msg, conn.stream.output.getWritten());
    }
    { // decrypt server pong message
        conn.cipher_server_seq = 1;
        try testing.expectEqualStrings("pong", (try conn.next()).?);
    }
    { // test reader interface
        conn.cipher_server_seq = 1;
        var rdr = conn.reader();
        var buffer: [4]u8 = undefined;
        const n = try rdr.readAll(&buffer);
        try testing.expectEqualStrings("pong", buffer[0..n]);
    }
    { // test readv interface
        conn.cipher_server_seq = 1;
        var buffer: [9]u8 = undefined;
        var iovecs = [_]std.posix.iovec{
            .{ .base = &buffer, .len = 3 },
            .{ .base = buffer[3..], .len = 3 },
            .{ .base = buffer[6..], .len = 3 },
        };
        const n = try conn.readv(iovecs[0..]);
        try testing.expectEqual(4, n);
        try testing.expectEqualStrings("pong", buffer[0..n]);
    }
}

// Copied from: https://github.com/ziglang/zig/blob/455899668b620dfda40252501c748c0a983555bd/lib/std/crypto/tls/Client.zig#L1354
/// Abstraction for sending multiple byte buffers to a slice of iovecs.
pub const VecPut = struct {
    iovecs: []const std.posix.iovec,
    idx: usize = 0,
    off: usize = 0,
    total: usize = 0,

    /// Returns the amount actually put which is always equal to bytes.len
    /// unless the vectors ran out of space.
    pub fn put(vp: *VecPut, bytes: []const u8) usize {
        if (vp.idx >= vp.iovecs.len) return 0;
        var bytes_i: usize = 0;
        while (true) {
            const v = vp.iovecs[vp.idx];
            const dest = v.base[vp.off..v.len];
            const src = bytes[bytes_i..][0..@min(dest.len, bytes.len - bytes_i)];
            @memcpy(dest[0..src.len], src);
            bytes_i += src.len;
            vp.off += src.len;
            if (vp.off >= v.len) {
                vp.off = 0;
                vp.idx += 1;
                if (vp.idx >= vp.iovecs.len) {
                    vp.total += bytes_i;
                    return bytes_i;
                }
            }
            if (bytes_i >= bytes.len) {
                vp.total += bytes_i;
                return bytes_i;
            }
        }
    }
};
