const std = @import("std");

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "install");
}

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Output Directory
///   - argv[3] : Output Symlink Path
///
///  writes contents to a single file of the same name as the symlink in the output directory, and creates the symlink

fn install(io: std.Io, alloc: std.mem.Allocator, argv: []const []const u8) !void {
    var stdin_buffer: [4096]u8 = undefined;
    var r = std.Io.File.stdin().reader(io, &stdin_buffer);

    const input_contents = try r.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(input_contents);

    std.debug.print("{}", .{input_contents.len});

    const file = try std.Io.Dir.cwd().createFile(io, argv[2], .{});
    defer file.close(io);

    var wbuf: [1024]u8 = undefined;
    var w = file.writer(io, &wbuf);

    try w.seekTo(0);
    try w.interface.writeAll(input_contents);
    try w.interface.flush();
}

pub fn main(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());

    if (argv.len < 2) {
        std.log.err("No role specified.", .{});
        return;
    }

    const called_role = argv[1];
    if (std.mem.eql(u8, called_role, "broadcast")) {
        try broadcast(init.io);
    } else if (std.mem.eql(u8, called_role, "install")) {
        try install(init.io, init.gpa, argv);
    }
}
