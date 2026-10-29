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
        std.debug.print("{s}\n", .{entry});
        //
        // const file = try dir.dir.openFile(dir.io, entry, .{});
        //
        // const readbuf: [1024]u8 = undefined;
        // const filereader = file.reader(dir.io, readbuf);
        // filereader.interface.re
    }
}