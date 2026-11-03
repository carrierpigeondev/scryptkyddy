const std = @import("std");

const DirectoryContext = @import("common/directory_context.zig").DirectoryContext;
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const actor_directory = "actors-bin"; // temporary
    // currently actors VERY BASIC; JUST FETCHING and none of the complexities at the moment

    // creates and owns its own DirectoryContext
    var actors_map = try ActorsMapping.init(actor_directory, io, allocator);
    defer actors_map.deinit();
    try actors_map.registerActors();

    for (actors_map.fetch_actors.items) |entry| {
        std.log.debug("<fetch> {s}", .{entry});
    }
    for (actors_map.install_actors.items) |entry| {
        std.log.debug("<install> {s}", .{entry});
    }
}