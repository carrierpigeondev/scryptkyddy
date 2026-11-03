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

    pub fn callActor(self: *ActorsMapping, argv: []const []const u8) !void {
        const name = argv[1];
        const role = argv[2];

        if (!self.dir_ctx.containsFile(name)) return error.ActorNotDefined;

        const full_path = self.dir_ctx.getFullPath(name);

        if (!self.isActorValid(full_path, role)) return error.ActorInvalidRole;

        std.log.info("{s}", .{full_path});
        // TODO: actually call the actor; remove above line when done; just to debug that it is valid
    }

    pub fn isActorValid(self: *ActorsMapping, full_path: []const u8, role: []const u8) bool {
        if (std.mem.eql(u8, role, "fetch")) {
            for (self.fetch_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        if (std.mem.eql(u8, role, "install")) {
            for (self.install_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        return false;
    }
};