const std = @import("std");
const install = @import("install.zig").install;
const bootstrap = @import("bootstrap.zig").bootstrap;
const downsize_cast = @import("downsize-cast.zig").downsize_cast;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const argv = try init.minimal.args.toSlice(init.arena.allocator());
    const env = init.environ_map;

    if (std.mem.eql(u8, argv[1], "!bootstrap")) {
        try bootstrap(io, allocator, env);
    } else if (std.mem.startsWith(u8, argv[1], "!downsize")) {
        try downsize_cast(io, allocator, env);
    }
    else {
        try install(io, allocator, argv, env);
    }
}