const std = @import("std");

/// maps current actors to arraylists for their available roles
pub const ActorsMapping = struct {
    alloc: std.mem.Allocator,

    fetch_actors: std.ArrayList([]const u8),
    install_actors: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ActorsMapping {
        return .{
            .alloc = allocator,
            .fetch_actors = std.ArrayList([]const u8).empty,
            .install_actors = std.ArrayList([]const u8).empty,
        };
    }

    pub fn deinit(self: *ActorsMapping) void {
        // the DirectoryContext for the actors owns and frees the paths themselves, so no 2nd free here
        self.fetch_actors.deinit(self.alloc);
        self.install_actors.deinit(self.alloc);
    }
};