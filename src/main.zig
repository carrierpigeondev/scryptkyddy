const std = @import("std");
const toml = @import("toml");

const DirectoryContext = @import("common/directory_context.zig").DirectoryContext;
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;
const Catalogue = @import("common//catalogue.zig").Catalogue;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const argv = try init.minimal.args.toSlice(init.arena.allocator());

    const actor_directory = "actors-bin"; // temporary
    const catalogue_directory = ".config"; // temporary

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


    var catalogue = Catalogue.init(allocator, io);
    defer catalogue.deinit();
    try catalogue.parseDirectory(catalogue_directory);

    for (catalogue.scrypts.items) |scrypt| {
        std.log.info("{s}: {s}", .{scrypt.id, scrypt.source});
    }
    _ = argv;

    // TODO: setup argument parser in common/arg_parser.zig; for now just use argv
    //try actors_map.callActor(argv);
}