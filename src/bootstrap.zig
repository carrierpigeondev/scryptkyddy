const std = @import("std");
const builtin = @import("builtin");

const EnvironmentLoader = @import("common/environment_loader.zig");

fn per_os_setenv(alloc: std.mem.Allocator, io: std.Io, key: []const u8, val: []const u8) !void {
    if (builtin.os.tag == .windows) {
        _ = try std.process.run(alloc, io, .{
            .argv = &.{
                "setx", key, val
            },
        });
    } else if (builtin.os.tag == .linux) {
        // TODO: doesnt work, needs to write to a file and source it
        const s = try std.fmt.allocPrint(alloc, "{s}={s}", .{
            key, val,
        });
        defer alloc.free(s);
        _ = try std.process.run(alloc, io, .{
            .argv = &.{
                "export",
                s,
            },
        });
    } else {
        std.log.warn(
            \\Cannot set environment variables for the system because I do not know how.
            \\Feel free to contribute though :D
        , .{});
    }
}

pub fn bootstrap(io: std.Io, alloc: std.mem.Allocator, env: *std.process.Environ.Map) !void {
    std.log.warn("Bootstrap not yet implemented properly.", .{});
    
    //// STEP 1)
    // check for the necessary environment variables
    // if they do not exist, walk the user through creation
    const env_res = EnvironmentLoader.loadEnvironmentVariables(env);
    std.log.info(
        \\ScryptKyddy uses some important environment variables for its configuration, rather than using a dedicated
        \\configuration file. As such, the following environment variables must be set (along with a reminder of their
        \\values if you have already set them):
        \\  SCRYPTKYDDY_ACTORS: {s}
        \\  SCRYPTKYDDY_LOCALCATALOGUES: {s}
        \\  SCRYPTKYDDY_SCRYPTS: {s}
        \\  SCRYPTKYDDY_BIN: {s}
        , .{
        env_res.actor_directory, env_res.catalogue_directory,
        env_res.universal_scrypt_install_directory, env_res.universal_scrypt_symlink_directory,
    });
    
    if (!env_res.isComplete()) {
        std.log.warn("Oh no! Some of your environment variables are not set!", .{});
        std.log.warn(
            \\NOTE: This would ordinarily walk you through setting your environment variables, but the bootstrapper is
            \\not yet complete. So, you need to set them manually. Ok bye
            ,
            .{}
        );

        // TODO: prompt to walk through their creation
        std.log.info("Do you want to set your environment variables interactively? [Y/n]", .{});
        var buf: [1024]u8 = undefined;
        var stdin = std.Io.File.reader(.stdin(), io, &buf);
        const opt = (try stdin.interface.takeDelimiter('\n')) orelse "";

        // makes no sense to lowercase and waste instructions; just check not or & return
        if (!(std.mem.eql(u8, opt, "y") or std.mem.eql(u8, opt, "Y"))) {
            return;
        }

        if (env_res.actor_directory.len == 0) {
            std.log.info("Actors Directory not defined. Define it now:", .{});
            const actors_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
            try per_os_setenv(alloc, io, "SCRYPTKYDDY_ACTORS", actors_dir);
        }

        if (env_res.catalogue_directory.len == 0) {
            std.log.info("Local Catalogues Directory not defined. Define it now:", .{});
            const catalogues_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
            try per_os_setenv(alloc, io, "SCRYPTKYDDY_LOCALCATALOGUES", catalogues_dir);
        }

        if (env_res.universal_scrypt_install_directory.len == 0) {
            std.log.info("Scrypts Directory not defined. Define it now:", .{});
            const scrypts_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
            try per_os_setenv(alloc, io, "SCRYPTKYDDY_SCRYPTS", scrypts_dir);
        }

        if (env_res.universal_scrypt_symlink_directory.len == 0) {
            std.log.info("Symlink Directory not defined. Define it now:", .{});
            const symlink_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
            try per_os_setenv(alloc, io, "SCRYPTKYDDY_BIN", symlink_dir);
        }

        return;
    }

    //// STEP 2)
    // ensure that the environment variables set by the user point to directories that exist
    // if they do not exist, walk the user through creation

    // createDirPath does not error if the directory already exists, so can safely call without checking
    std.log.info("Ensuring directory exists: {s}", .{env_res.actor_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.actor_directory);

    std.log.info("Ensuring directory exists: {s}", .{env_res.catalogue_directory});
    const local_catalogue_dir = try std.Io.Dir.cwd().createDirPathOpen(
        io, env_res.catalogue_directory, .{}
    );

    std.log.info("Ensuring directory exists: {s}", .{env_res.universal_scrypt_install_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.universal_scrypt_install_directory);

    std.log.info("Ensuring directory exists: {s}", .{env_res.universal_scrypt_symlink_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.universal_scrypt_symlink_directory);

    //// STEP 3)
    // ensure that there is a default catalogue written in the local catalogues directory
    try local_catalogue_dir.writeFile(io, .{
        .data =
            \\[[scrypts]]
            \\    id = "extra-actors"
            \\    source = "https://raw.githubusercontent.com/carrierpigeondev/extra-actors/refs/heads/master/extra-actors-catalogue.toml"
            \\    [[scrypts.roles]]
            \\        role = "fetch"
            \\        actor = "http-actor"
            \\    [[scrypts.roles]]
            \\        role = "install"
            \\        actor = "single-file-write-actor"
            \\[[scrypts]]
            \\    id = "extra-catalogues"
            \\    source = "https://raw.githubusercontent.com/carrierpigeondev/extra-catalogues/refs/heads/main/extra-catalogues-catalogue.toml"
            \\    [[scrypts.roles]]
            \\        role = "fetch"
            \\        actor = "http-actor"
            \\    [[scrypts.roles]]
            \\        role = "install"
            \\        actor = "single-file-write-actor"
        ,
        .sub_path = "00_default_catalogue.toml"
    });
}