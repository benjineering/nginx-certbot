const std = @import("std");
const log = std.log.scoped(.Settings);

const Settings = struct {
    domains: [][]const u8,

    fn getFromEnv() !Settings {
        const allocator = std.heap.page_allocator;
        _ = allocator;
    }

    fn deinit() void {}
};
