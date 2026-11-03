const std = @import("std");

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "fetch");
}

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "fetch"
///   - argv[2] : URL
///
///  writes to stdout the contents from web request to URL
fn fetch(io: std.Io, alloc: std.mem.Allocator, argv: []const []const u8) !void {
    var client = std.http.Client {
        .allocator = alloc,
        .io = io,
    };
    defer client.deinit();

    var res_body = std.Io.Writer.Allocating.init(alloc);
    defer res_body.deinit();

    _ = try client.fetch(.{
        .location = .{
            .url = argv[2], // argv[2] is URL; whereas argv[1] is role (here: "fetch")
        },
        .method = .GET,
        .response_writer = &res_body.writer,
    });

    try std.Io.File.stdout().writeStreamingAll(io, res_body.written());
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
        try fetch(init.io, init.gpa, argv);
    }
}
