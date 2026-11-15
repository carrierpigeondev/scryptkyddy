const std = @import("std");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Output Directory
///   - argv[3] : Output Name
///   - argv[4] : Output Symlink Path
///
///  writes contents to a single file of the same name as the symlink in the output directory, and creates the symlink
///
///  contains extra input_contents arg since called as a function, not as a subprocess like other actors because it is a
///  builtin actor. for an actual example of how you ought to make an install actor, see install() from the unzip-actor,
///  which actually reads from stdin
pub fn install(io: std.Io, alloc: std.mem.Allocator, input_contents: []const u8, argv: []const []const u8) !void {
    // api spec requires creating a directory for the file, not just writing the file
    const outdir = try std.Io.Dir.cwd().createDirPathOpen(io, argv[2], .{});
    defer outdir.close(io);

    // writes only a single file which is the necessary executable
    try outdir.writeFile(io, .{
        .data = input_contents,
        .sub_path = argv[3],
    });

    // do not create symlink if left empty
    if (std.mem.eql(u8, argv[4], "")) {
        return;
    }

    // api compliance, create a proper symlink
    const path_of_file = try std.fs.path.join(alloc, &.{
        argv[2], argv[3]
    });
    defer alloc.free(path_of_file);

    return std.Io.Dir.cwd().symLink(io, path_of_file, argv[4], .{}) catch |err| {
        if (err == std.Io.Dir.SymLinkError.PathAlreadyExists) {
            return;
        } else {
            return err;
        }
    };
}