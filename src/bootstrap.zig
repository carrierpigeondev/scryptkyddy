const std = @import("std");

const EnvironmentLoader = @import("common/environment_loader.zig");

pub fn bootstrap(io: std.Io, env: *std.process.Environ.Map) !void {

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


    //// STEP 4)
    // ask the user if they want to add the basic http-actor and single-file-write-actor, which are necessary to add
    // scrypts, as well as more actors and more catalogues (otherwise not really functional)

    std.log.warn("not yet implemented; try `zig build http-actor -Dactors=$SCRYPTKYDDY_ACTORS` and `zig build single-file-write-actor -Dactors=$SCRYPTKYDDY_ACTORS`", .{});
}