const std = @import("std");
const install = @import("install.zig").install;
const bootstrap = @import("bootstrap.zig").bootstrap;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const env = init.environ_map;

    if (std.mem.eql(u8, argv[1], "!bootstrap")) {
        try bootstrap(io, env);
    } else {
        try install(io, allocator, argv, env);
    }
}