const std = @import("std");

// pub fn getPaths(path: []const u8, io: std.Io, allocator: std.mem.Allocator) ![]const []const u8 {
//     var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
//     defer dir.close(io);
//
//     var iter = dir.iterate();
//     while (try iter.next(io)) |entry| {
//         if (entry.kind != .file) continue;
//
//         const name = try allocator.dupe(u8, entry.name);
//         errdefer allocator.free(name);
//
//         // append the name
//     }
// }