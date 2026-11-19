const std = @import("std");

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "link"
///   - argv[2] : Output Scrypt Path
///   - argv[3] : Output Symlink Path
pub fn link(io: std.Io, argv: []const []const u8) !void {
    return std.Io.Dir.cwd().symLink(io, argv[2], argv[3], .{}) catch |err| {
        if (err == std.Io.Dir.SymLinkError.PathAlreadyExists) {
            return;
        } else {
            return err;
        }
    };
}