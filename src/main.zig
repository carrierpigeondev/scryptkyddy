const std = @import("std");

const util = @import("util.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const actor_directory = "builtin";

    _ = io;
    _ = allocator;
    _ = actor_directory;

    // read the actor directory
    // currently uses builtin, need to make the logic to use an actually real path, or set of paths
}