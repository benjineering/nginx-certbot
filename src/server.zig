const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const ArenaAllocator = std.heap.ArenaAllocator;

const FileReader = struct {
    root_path: []const u8,
    allocator: ArenaAllocator,

    fn init(root_path: []const u8) FileReader {
        return FileReader{ .root_path = root_path, .allocator = ArenaAllocator.init(std.heap.page_allocator) };
    }

    fn read(self: *FileReader, file_name: []const u8) error{ OutOfMemory, SharingViolation, PathAlreadyExists, FileNotFound, AccessDenied, PipeBusy, NameTooLong, InvalidUtf8, BadPathName, Unexpected, NetworkNotFound, InvalidHandle, SymLinkLoop, ProcessFdQuotaExceeded, SystemFdQuotaExceeded, NoDevice, SystemResources, FileTooBig, IsDir, NoSpaceLeft, NotDir, DeviceBusy, FileLocksNotSupported, FileBusy, WouldBlock }!u64 {
        const allocator = self.allocator.allocator();

        const file_path = try fmt.allocPrint(allocator, "{s}/{s}", .{ self.root_path, file_name });

        var file = try fs.openFileAbsolute(file_path, .{});
        defer file.close();

        const stat = try file.stat();
        return stat.size;
    }

    fn deinit(self: *FileReader) void {
        self.allocator.deinit();
    }
};

test "read - file exists" {
    const root_path = "/users/8enwi/onedrive/desktop";

    var reader = FileReader.init(root_path);
    defer reader.deinit();

    const actual_size = try reader.read("xxx");
    const expected_size: u64 = 43;
    try std.testing.expectEqual(expected_size, actual_size);
}
