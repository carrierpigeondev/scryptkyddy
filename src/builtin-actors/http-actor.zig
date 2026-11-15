const std = @import("std");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "fetch"
///   - argv[2] : URL
///
///  writes to stdout the contents from web request to URL
pub fn fetch(io: std.Io, alloc: std.mem.Allocator, argv: []const []const u8) ![]u8 {
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

    // a normal actor ought to write to stdout, but since this is called as a function and not a subprocess as a builtin
    // actor, it returns the contents instead
    return try res_body.toOwnedSlice();
}