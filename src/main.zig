const std = @import("std");

const DirectoryContext = @import("common/directory_context.zig").DirectoryContext;
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const argv = try init.minimal.args.toSlice(init.arena.allocator());

    const actor_directory = "actors-bin"; // temporary

    //// SECTION
    // dedicated to parts of the program that must run no matter what mode is particularly chosen

    // creates and owns its own DirectoryContext
    var actors_map = ActorsMapping.init(actor_directory, io, allocator) catch |err| {
        std.log.err("Could not create actors mapping due to error: {}", .{err});
        if (err == std.Io.Dir.OpenError.FileNotFound) {
            std.log.err("Are you sure the actor directory '{s}' exists?", .{actor_directory});
        }
        return err;
    };
    defer actors_map.deinit();
    try actors_map.registerActors();

    // at this point, all actors known to the program;
    for (actors_map.fetch_actors.items) |entry| {
        std.log.debug("<fetch> {s}", .{entry});
    }
    for (actors_map.install_actors.items) |entry| {
        std.log.debug("<install> {s}", .{entry});
    }

    // TODO: setup argument parser in common/arg_parser.zig; for now just use argv
    try actors_map.callActor(argv);
}