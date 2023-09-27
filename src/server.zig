const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const io = std.io;
const net = std.net;
const http = std.http;
const ArenaAllocator = std.heap.ArenaAllocator;

const log = std.log.scoped(.server);

const FileReader = struct {
    root_path: []const u8,

    fn read(self: *FileReader, file_name: []const u8, writer: anytype) !u64 {

        // TODO: we probs don't need an arena here
        var arena = ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const file_path = try fmt.allocPrint(allocator, "{s}/{s}", .{ self.root_path, file_name });

        var file = try fs.openFileAbsolute(file_path, .{});
        defer file.close();

        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, stat.size);

        _ = try file.readAll(buffer);

        const write_length = try writer.*.write(buffer);

        return write_length;
    }
};

test "FileReader.read" {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const root_path = try fs.cwd().realpathAlloc(allocator, "test-data");

    var reader = FileReader{ .root_path = root_path };

    var buffer = try allocator.alloc(u8, 1024);
    var writer = io.FixedBufferStream([]u8){ .buffer = buffer, .pos = 0 };

    const actual_size = try reader.read("xxx", &writer);

    const expected_size: u64 = 7;
    try std.testing.expectEqual(expected_size, actual_size);

    try std.testing.expect(std.mem.eql(u8, "abc123!", buffer[0..actual_size]));
}

const Server = struct {
    arena: ArenaAllocator,
    address: net.Address,
    server: http.Server,
    file_reader: FileReader,

    fn init(address: []const u8, port: u16, acme_challenge_path: []const u8) error{InvalidIPAddressFormat}!Server {
        var arena = ArenaAllocator.init(std.heap.page_allocator);
        return Server{
            .arena = arena,
            .address = try net.Address.parseIp(address, port),
            .server = http.Server.init(arena.allocator(), .{}),
            .file_reader = FileReader{ .root_path = acme_challenge_path },
        };
    }

    fn deinit(self: *Server) void {
        self.server.deinit();
        self.arena.deinit();
    }

    // TODO: simplify error signature
    fn start(self: *Server) !void {
        var allocator = self.arena.allocator();

        try self.server.listen(self.address);

        outer: while (true) {
            var response = try self.server.accept(.{
                .allocator = allocator,
            });

            defer response.deinit();

            while (response.reset() != .closing) {
                response.wait() catch |err| switch (err) {
                    error.HttpHeadersInvalid => continue :outer,
                    error.EndOfStream => continue,
                    else => return err,
                };

                try self.handleRequest(&response);
            }
        }
    }

    fn stop() void {}

    fn handleRequest(self: *Server, response: http.Server.Response) !void {
        log.info("{s} {s} {s}", .{ @tagName(response.request.method), @tagName(response.request.version), response.request.target });

        var allocator = self.arena.allocator();
        const body = try response.reader().readAllAlloc(allocator, 8192);
        defer allocator.free(body);

        if (response.request.headers.contains("connection")) {
            try response.headers.append("connection", "keep-alive");
        }

        if (!std.mem.startsWith(u8, response.request.target, "/.well-known/acme-challenge")) {
            response.status = .not_found;
            try response.do();
            try response.writeAll("not found\n");
            try response.finish();
            return;
        }

        const file_name_start = std.mem.lastIndexOf(u8, response.request.target, "/");
        const file_name = response.request.target[file_name_start..];

        const content_length = try self.file_reader.read(file_name, response.writer());
        response.transfer_encoding = .{ .content_length = content_length };

        try response.headers.append("content-type", "text/plain");

        try response.do();
        if (response.request.method != .HEAD) {
            try response.writeAll("Zig ");
            try response.writeAll("Bits!\n");
        }

        try response.finish();
    }
};

test "Server.start and stop" {
    var server = try Server.init("127.0.0.1", 1982);
    defer server.deinit();

    try server.start();
    //server.stop();
}
