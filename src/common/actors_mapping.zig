const std = @import("std");

const DirectoryContext = @import("directory_context.zig").DirectoryContext;

/// maps current actors to arraylists for their available roles
pub const ActorsMapping = struct {
    alloc: std.mem.Allocator,
    dir_ctx: DirectoryContext,

    fetch_actors: std.ArrayList([]const u8),
    install_actors: std.ArrayList([]const u8),

    pub fn init(actor_directory: []const u8, io: std.Io, allocator: std.mem.Allocator) !ActorsMapping {
        var dir_ctx = DirectoryContext.init(
            actor_directory,
            io,
            allocator
        );
        try dir_ctx.discover();

        return .{
            .alloc = allocator,
            .dir_ctx = dir_ctx,
            .fetch_actors = std.ArrayList([]const u8).empty,
            .install_actors = std.ArrayList([]const u8).empty,
        };
    }

    pub fn deinit(self: *ActorsMapping) void {
        self.dir_ctx.deinit();

        // the DirectoryContext for the actors owns and frees the paths themselves, so no 2nd free here
        self.fetch_actors.deinit(self.alloc);
        self.install_actors.deinit(self.alloc);
    }

    pub fn registerActors(self: *ActorsMapping) !void {
        // parses through all actors in the directory context
        for (self.dir_ctx.children_names.items) |entry| {
            // call the broadcast function to know which roles the actor implements
            const full_path = self.dir_ctx.getFullPath(entry);
            const broadcast_res = std.process.run(self.dir_ctx.alloc, self.dir_ctx.io, .{
                .argv = &.{
                    full_path, // must call full path
                    "broadcast"
                }
            }) catch |err| {
                // this will occur whenever a system cannot execute command (i.e., exe on Linux; elf on Windows)
                std.log.warn("Failed to run the actor {s} due to {}. Forced to skip.", .{entry, err});
                continue;
            };

            defer self.dir_ctx.alloc.free(broadcast_res.stdout);
            defer self.dir_ctx.alloc.free(broadcast_res.stderr);
            const output= broadcast_res.stdout;

            var roles = std.mem.splitScalar(u8, output, '\n');
            while (roles.next()) |role| {
                if (std.mem.eql(u8, role, "fetch")) {
                    try self.fetch_actors.append(self.alloc, full_path);
                    continue;
                }
                if (std.mem.eql(u8, role, "install")) {
                    try self.install_actors.append(self.alloc, full_path);
                    continue;
                }
            }
        }
    }
};