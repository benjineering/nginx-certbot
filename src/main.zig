
fn certsExists(domain: []const u8) !bool {}
fn createCert(domain: []const u8) !void {}
fn renewCerts() !void {}

pub fn main() void! {
    const 

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
}
