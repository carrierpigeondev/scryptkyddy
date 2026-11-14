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

    // NOTE:
    // This MUST be a .readerStreaming and not a .reader despite the latter working on Linux; I presume some issue is
    // present only in the Windows implementation on how Zig reads from an anonymous pipe, specifically with binary
    // data, which is exactly what is needed here; however, .readStreaming does indeed work on both platforms (I'm
    // pretty sure, haven't test Linux as of writing this comment, so I'm just assuming, and you know what they say
    // about assuming-- it is perfectly fine for 'production' code. haha, I hope no one uses this garbage in production)
    var r = std.Io.File.stdin().readerStreaming(io, &stdin_buffer);

    const input_contents = try r.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(input_contents);

    // api spec requires creating a directory for the file, not just writing the file
    const outdir = try std.Io.Dir.cwd().createDirPathOpen(io, argv[2], .{});
    defer outdir.close(io);

    // create a file of the name given by the symlink, since it best provides what the program should be called as this
    // writes only a single file which is the necessary executable
    try outdir.writeFile(io, .{
        .data = input_contents,
        .sub_path = std.fs.path.basename(argv[3]),
    });

    // api compliance, create a proper symlink
    const path_of_file = try std.fs.path.join(alloc, &.{
        argv[2], std.fs.path.basename(argv[3])
    });
    defer alloc.free(path_of_file);

    try std.Io.Dir.cwd().symLink(io, path_of_file, argv[3], .{});
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
