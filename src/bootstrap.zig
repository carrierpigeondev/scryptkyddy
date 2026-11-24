const std = @import("std");
const builtin = @import("builtin");

const EnvironmentLoader = @import("common/environment_loader.zig");

fn per_os_setenv(alloc: std.mem.Allocator, io: std.Io, file: std.Io.File, key: []const u8, val: []const u8) !void {
    if (builtin.os.tag == .windows) {
        _ = try std.process.run(alloc, io, .{
            .argv = &.{
                "setx", key, val
            },
        });
    } else if (builtin.os.tag == .linux or builtin.os.tag == .freebsd) { // could work with other *bsd; untested
        const append_string = try std.fmt.allocPrint(alloc, "export {s}=\"{s}\"\n", .{
            key, val,
        });
        defer alloc.free(append_string);
        try file.writePositionalAll(io, append_string, try file.length(io));
    } else {
        std.log.warn(
            \\Cannot set environment variables for the system because I do not know how.
            \\Feel free to contribute though :D
        , .{});
    }
}

fn ask_set_env(io: std.Io, alloc: std.mem.Allocator, env_res: EnvironmentLoader.EnvironmentVariableResult) !void {
    std.log.warn("Oh no! Some of your environment variables are not set!", .{});
    std.log.info("Do you want to set your environment variables interactively? [Y/n]", .{});
    var buf: [1024]u8 = undefined;
    var stdin = std.Io.File.reader(.stdin(), io, &buf);
    const opt = (try stdin.interface.takeDelimiter('\n')) orelse "";

    // makes no sense to lowercase and waste instructions; just check not or & return
    if (!(std.mem.eql(u8, opt, "y") or std.mem.eql(u8, opt, "Y"))) {
        return;
    }

    var file: std.Io.File = undefined; // allows for Windows to work in that it is never accessed

    // again, this might work on other operating systems, but not confirmed to work so will not offer full support
    if (builtin.os.tag == .linux or builtin.os.tag == .freebsd) {
        std.log.info("What file do you want to append 'export's to?", .{});
        stdin = std.Io.File.reader(.stdin(), io, &buf);
        const profile_path = (try stdin.interface.takeDelimiter('\n')) orelse "";

        file = try std.Io.Dir.cwd().openFile(io, profile_path, .{ .mode = .write_only });
    } else {
        std.log.info(
            \\Platform not Linux or FreedBSD;
            \\If you are not on Windows, these steps may not work for you.
                ,
            .{}
        );
    }

    if (env_res.actor_directory.len == 0) {
        std.log.info("Actors Directory not defined. Define it now:", .{});
        const actors_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
        try per_os_setenv(alloc, io, file, "SCRYPTKYDDY_ACTORS", actors_dir);
    }

    if (env_res.catalogue_directory.len == 0) {
        std.log.info("Local Catalogues Directory not defined. Define it now:", .{});
        const catalogues_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
        try per_os_setenv(alloc, io, file, "SCRYPTKYDDY_LOCALCATALOGUES", catalogues_dir);
    }

    if (env_res.universal_scrypt_install_directory.len == 0) {
        std.log.info("Scrypts Directory not defined. Define it now:", .{});
        const scrypts_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
        try per_os_setenv(alloc, io, file, "SCRYPTKYDDY_SCRYPTS", scrypts_dir);
    }

    if (env_res.universal_scrypt_symlink_directory.len == 0) {
        std.log.info("Symlink Directory not defined. Define it now:", .{});
        const symlink_dir = (try stdin.interface.takeDelimiter('\n')) orelse "";
        try per_os_setenv(alloc, io, file, "SCRYPTKYDDY_BIN", symlink_dir);
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
        try ask_set_env(io, alloc, env_res);
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
