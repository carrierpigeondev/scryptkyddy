const std = @import("std");

const EnvironmentLoader = @import("common/environment_loader.zig");

pub fn bootstrap(io: std.Io, env: *std.process.Environ.Map) !void {
    //// STEP 1)
    // check for the necessary environment variables
    // if they do not exist, walk the user through creation
    const env_res = EnvironmentLoader.loadEnvironmentVariables(env);
    if (!env_res.isComplete()) {
        std.log.warn("Bootstrap not yet implemented properly.", .{});
        std.log.info(
            \\Environment variables are missing! Here are the one's that are necessary:
            \\  SCRYPTKYDDY_ACTORS: {s}
            \\  SCRYPTKYDDY_LOCALCATALOGUES: {s}
            \\  SCRYPTKYDDY_SCRYPTS: {s}
            \\  SCRYPTKYDDY_BIN: {s}
        , .{
            env_res.actor_directory, env_res.catalogue_directory,
            env_res.universal_scrypt_install_directory, env_res.universal_scrypt_symlink_directory,
        });

        // TODO: prompt to walk through their creation

        return;
    }

    //// STEP 2)
    // ensure that the environment variables set by the user point to directories that exist
    // if they do not exist, walk the user through creation

    // createDirPath does not error if the directory already exists, so can safely call without checking
    std.log.info("Ensuring directory exists: {s}", .{env_res.actor_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.actor_directory);
    std.log.info("Ensuring directory exists: {s}", .{env_res.catalogue_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.catalogue_directory);
    std.log.info("Ensuring directory exists: {s}", .{env_res.universal_scrypt_install_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.universal_scrypt_install_directory);
    std.log.info("Ensuring directory exists: {s}", .{env_res.universal_scrypt_symlink_directory});
    try std.Io.Dir.cwd().createDirPath(io, env_res.universal_scrypt_symlink_directory);

    //// STEP 3)
    // ask the user if they want to add the basic http-actor and single-file-write-actor, which are necessary to add
    // scrypts, as well as more actors and more catalogues (otherwise not really functional)

    std.log.warn("not yet implemented; try `zig build http-actor -Dactors=$SCRYPTKYDDY_ACTORS` and `zig build single-file-write-actor -Dactors=$SCRYPTKYDDY_ACTORS`", .{});
}