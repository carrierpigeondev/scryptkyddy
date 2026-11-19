const std = @import("std");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Output Directory
///   - argv[3] : Output Name
///
///  writes contents to a single file of the same name as the symlink in the output directory, and creates the symlink
///
///  contains extra input_contents arg since called as a function, not as a subprocess like other actors because it is a
///  builtin actor. for an actual example of how you ought to make an install actor, see install() from the unzip-actor,
///  which actually reads from stdin
///
///  in other kind of install role must write to stdout the path it installs to; because builtin, return []u8
pub fn install(io: std.Io, alloc: std.mem.Allocator, input_contents: []const u8, argv: []const []const u8) ![]u8 {
    // api spec requires creating a directory for the file, not just writing the file
    const outdir = try std.Io.Dir.cwd().createDirPathOpen(io, argv[2], .{});
    defer outdir.close(io);

    // writes only a single file which is the necessary executable
    try outdir.writeFile(io, .{
        .data = input_contents,
        .sub_path = argv[3],
    });

    // would write to stdout in normal Role; here returns
    // e.g., unzip actor writes the returned path
    return try std.fs.path.join(alloc, &.{
        argv[2], argv[3]
    });
}