const std = @import("std");

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "install");
}

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Contents
///   - argv[3] : Output Directory
///   - argv[4] : Output Symlink Path
///
///  writes contents to a single file of the same name as the symlink in the output directory, and creates the symlink
fn install(io: std.Io, argv: []const []const u8) !void {
    // TODO: make behave

    try std.Io.File.stdout().writeStreamingAll(io, argv[2]);
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
        try install(init.io, argv);
    }
}
