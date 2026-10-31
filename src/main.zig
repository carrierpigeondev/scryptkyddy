const std = @import("std");

const DirectoryContext = @import("common/directory_context.zig").DirectoryContext;
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const actor_directory = "actors"; // temporary
    // currently actors VERY BASIC; JUST FETCHING and none of the complexities at the moment

    // create the directory context for the actors directory
    var dir_ctx = DirectoryContext.init(
        actor_directory,
        io,
        allocator
    );
    defer dir_ctx.deinit();
    try dir_ctx.discover(); // must be called prior to iterating children_names

    // must be made second, deferred second (freed first) because the dir_ctx owns the fullpaths of actors stored
    // in the mapping
    var actors_map = ActorsMapping.init(allocator);
    defer actors_map.deinit();

    // tmp display all actors
    // at the same time, register all the actors according to their functions
    for (dir_ctx.children_names.items) |entry| {
        // call the broadcast function to know which roles the actor implements
        const full_path = dir_ctx.getFullPath(entry);
        const broadcast_res = try std.process.run(dir_ctx.alloc, dir_ctx.io, .{
            .argv = &.{
                full_path, // must call full path
                "broadcast"
            }
        });

        defer dir_ctx.alloc.free(broadcast_res.stdout);
        defer dir_ctx.alloc.free(broadcast_res.stderr);

        const output= broadcast_res.stdout;
        var roles = std.mem.splitScalar(u8, output, '\n');

        while (roles.next()) |role| {
            if (std.mem.eql(u8, role, "fetch")) {
                try actors_map.fetch_actors.append(actors_map.alloc, full_path);
                continue;
            }

            if (std.mem.eql(u8, role, "install")) {
                try actors_map.install_actors.append(actors_map.alloc, full_path);
                continue;
            }
        }
    }

    for (actors_map.fetch_actors.items) |entry| {
        std.log.debug("<fetch> {s}\n", .{entry});
    }
}