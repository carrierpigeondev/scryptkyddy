const std = @import("std");
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;
const EnvironmentLoader = @import("common/environment_loader.zig");

// removes all actors that are not runnable on the current system
// ...
// downsizes the cast of actors on your system .--.
pub fn downsize_cast(io: std.Io, alloc: std.mem.Allocator, env: *std.process.Environ.Map) !void {
    const env_res = EnvironmentLoader.loadEnvironmentVariables(env);

    var actors_map = ActorsMapping.init(env_res.actor_directory, io, alloc) catch |err| {
        std.log.err("Could not create actors mapping due to error: {}", .{err});
        if (err == std.Io.Dir.OpenError.FileNotFound) {
            std.log.err("Are you sure the actor directory '{s}' exists?", .{env_res.actor_directory});
        }
        return err;
    };
    defer actors_map.deinit();
    const unproductive_actors = try actors_map.registerActors(alloc);
    defer alloc.free(unproductive_actors);

    for (unproductive_actors) |ua| {
        std.log.info("Firing {s}", .{ua});
        const actor_dir = try std.Io.Dir.cwd().openDir(io, env_res.actor_directory, .{});
        try actor_dir.deleteFile(io, ua);
    }
}