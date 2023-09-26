const std = @import("std");
const http = std.http;
const log = std.log.scoped(.server);
const mem = std.mem;
const fs = std.fs;

const server_addr = "127.0.0.1";
const server_port = 8000;

const contentPath = "C:\\Users\\8enwi\\OneDrive\\Desktop\\";

fn runServer(server: *http.Server, allocator: std.mem.Allocator) !void {
    outer: while (true) {
        var response = try server.accept(.{
            .allocator = allocator,
        });

        defer response.deinit();

        while (response.reset() != .closing) {
            response.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handleRequest(&response, allocator);
        }
    }
}

fn handleRequest(response: *http.Server.Response, allocator: std.mem.Allocator) !void {
    log.info("{s} {s} {s}", .{ @tagName(response.request.method), @tagName(response.request.version), response.request.target });

    const body = try response.reader().readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    if (std.mem.startsWith(u8, response.request.target, "/.well-known/acme-challenge")) {
        const fileNameIndex = std.mem.lastIndexOf(u8, response.request.target, "/");
        const fileName = response.request.target[fileNameIndex..];

        var filePath = allocator.alloc(u8, contentPath.len + fileName.len);
        mem.copy(u8, filePath[0..], contentPath);
        mem.copy(u8, filePath[contentPath.len..], fileName);

        var file = try fs.openFileAbsolute(filePath, .{});
        defer file.close();

        response.transfer_encoding = .{ .content_length = 10 };

        try response.headers.append("content-type", "text/plain");

        try response.do();
        if (response.request.method != .HEAD) {
            try response.writeAll("Zig ");
            try response.writeAll("Bits!\n");
            try response.finish();
        }
    } else {
        response.status = .not_found;
        try response.do();
        try response.writeAll("not found\n");
        try response.finish();
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var server = http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    log.info("Server is running at {s}:{d}", .{ server_addr, server_port });

    const address = std.net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    while (true) {
        runServer(&server, allocator) catch |err| {
            log.err("server error: {}\n", .{err});

            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }

            std.os.exit(1);
        };
    }
}
