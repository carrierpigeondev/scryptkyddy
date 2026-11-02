const std = @import("std");

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "fetch\ninstall\n");
}

fn fetch(argv: []const []const u8) void {
    _ = argv;
    std.log.err("Not yet implemented. I lied.", .{});
}

fn install(argv: []const []const u8) void {
    _ = argv;
    std.log.err("Not yet implemented. I lied.", .{});
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
    } else if (std.mem.eql(u8, called_role, "fetch")) {
        fetch(argv);
    } else if (std.mem.eql(u8, called_role, "install")) {
        install(argv);
    }
}
