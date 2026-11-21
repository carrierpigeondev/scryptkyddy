const std = @import("std");
const Catalogue = @import("common/catalogue.zig").Catalogue;
const Scrypt = @import("common/catalogue.zig").Scrypt;
const EnvironmentLoader = @import("common/environment_loader.zig");

/// tries to build a tree of what catalogues provide what other catalogues, then refresh the most top-level
/// catalogue(s) (ones that do not have something that provides them) and runs the necessary actors for every single
/// scrypt down to the lowest level to the point that no new catalogues would be installed
///
/// needs to do construction -- cannot necessarily record which transactions occur because the files could be easily
/// added or removed; therefore its has been determined (i have determined) to (inefficiently and unoptimizedly) make
/// a tree of catalogues here
pub fn recatalogue(io: std.Io, alloc: std.mem.Allocator, env: *std.process.Environ.Map, exec_name: []const u8) !void {
    const env_res = EnvironmentLoader.loadEnvironmentVariables(env);

    var catalogue = Catalogue.init(alloc, io);
    defer catalogue.deinit();
    // creates and owns its own DirectoryContext during lifetime of the function (defers deinit to end of the call,
    // not until end of life of catalogue because all thats needed from catalogue is the information, not necessarily
    // the actual toml files after being parsed or their parent directory (of which is the DirectoryContext)
    var d = try catalogue.parseDirectory(env_res.catalogue_directory);
    defer d.deinit();

    var recatalougeable_catalogues: std.ArrayList(Scrypt) = .empty;
    defer recatalougeable_catalogues.deinit(alloc);

    for (catalogue.scrypts.items) |scrypt| {
        if (d.containsFile(scrypt.id)) {
            try recatalougeable_catalogues.append(alloc, scrypt);
            continue;
        }

        // also check the scrypt + toml since it is not enforced to have .toml; but sometimes might?
        const scrypt_plus_toml = try std.fmt.allocPrint(alloc, "{s}.toml", .{scrypt.id});
        defer alloc.free(scrypt_plus_toml);
        if (d.containsFile(scrypt_plus_toml)) {
            try recatalougeable_catalogues.append(alloc, scrypt);
            continue;
        }
    }

    var commands_to_run: std.ArrayList([]const []const u8) = .empty;
    defer {
        for (commands_to_run.items) |cmd| {
            alloc.free(cmd);
        }
        commands_to_run.deinit(alloc);
    }

    std.log.info("Ok to run the following commands?", .{});
    for (recatalougeable_catalogues.items) |rc| {
        const cmd = try alloc.dupe([]const u8, &.{
            exec_name, rc.id,
        });
        try commands_to_run.append(alloc, cmd);
    }

    for (commands_to_run.items) |cmd| {
        for (cmd) |arg| {
            std.debug.print("{s} ", .{arg});
        }
        std.debug.print("\n", .{});
    }
}