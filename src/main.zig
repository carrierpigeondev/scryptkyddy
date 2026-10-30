const std = @import("std");

const util = @import("util.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const actor_directory = "src";

    var dir = util.DirectoryContext.init(
        actor_directory,
        io,
        allocator
    );
    defer dir.deinit();
    try dir.discover(); // must be called prior to iterating childrenNames

    for (dir.childrenNames.items) |entry| {
        std.debug.print(">> {s} >>\n", .{entry});

        const contents = dir.readFileAlloc(entry);
        std.debug.print("{s}\n", .{contents});
        dir.alloc.free(contents);
    }
}