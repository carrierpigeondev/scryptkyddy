const std = @import("std");
const builtin = @import("builtin");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "link"
///   - argv[2] : Output Scrypt Path
///   - argv[3] : Output Symlink Path
pub fn link(io: std.Io, argv: []const []const u8) !void {
    // fails to compile due to .toMode() for a Windows target because it doesn't contain the function; therefore it
    // needs to be marked as do on everything other than windows
    if (comptime builtin.target.os.tag != .windows) {
        const f = try std.Io.Dir.cwd().openFile(io, argv[2], .{});
        defer f.close(io);

        const stat = try f.stat(io);
        const mode = stat.permissions.toMode() | 0o111;
        try f.setPermissions(io, std.Io.File.Permissions.fromMode(mode));

        return std.Io.Dir.cwd().symLink(io, argv[2], argv[3], .{}) catch |err| {
            if (err == std.Io.Dir.SymLinkError.PathAlreadyExists) {
                return;
            } else {
                return err;
            }
        };
    } else {
        std.log.err("Cannot run this Role on Windows.", .{});
    }
}