const std = @import("std");
const toml = @import("toml");

const EnvironmentLoader = @import("common/environment_loader.zig");
const DirectoryContext = @import("common/directory_context.zig").DirectoryContext;
const ActorsMapping = @import("common/actors_mapping.zig").ActorsMapping;
const Catalogue = @import("common//catalogue.zig").Catalogue;
const Role = @import("common//catalogue.zig").Role;


pub fn install(io: std.Io, allocator: std.mem.Allocator, argv: []const [:0]const u8, env: *std.process.Environ.Map) !void {
    //// SECTION
    // load essential paths from environment
    //
    // force the user to have these paths set in their environment, because really the user must know what they are
    // actually doing; do not allow any defaults to be set here ever; but I will give some suggestions for the very cool
    // developer reading the code right now, to instruct users (maybe it'll be added to documentation or the planned
    // tutorial engine)--
    //
    // each is configured individually, but I will be referring to a prefix as SCRYPTKYDDY_ROOT which is:
    // /home/[user]/.local/share/scryptkyddy
    //
    // using the names assigned in the code:
    // actor_directory: {SCRYPTKYDDY_ROOT}/bin -actors
    // catalogue_directory: {SCRYPTKYDDY_ROOT}/local-catalogue
    // universal_scrypt_install_directory: {SCRYPTKYDDY_ROOT}/scrypts
    // universal_scrypt_symlink_directory: {SCRYPTKYDDY_ROOT}/bin
    //
    // and, for the environment variable names that ScryptKyddy actually checks:
    // actor_directory -> SCRYPTKYDDY_ACTORS
    // catalogue_directory -> SCRYPTKYDDY_LOCALCATALOGUES
    // universal_scrypt_install_directory -> SCRYPTKYDDY_SCRYPTS
    // universal_scrypt_symlink_directory -> SCRYPTKYDDY_BIN
    //
    // ensure that universal_scrypt_symlink_directory (SCRYPTKYDDY_BIN) path is in $PATH for it to be callable symlinks
    const env_res = EnvironmentLoader.loadEnvironmentVariables(env);
    if (!env_res.isComplete()) {
        std.log.err(
            \\Necessary environment variables not defined. Please check the following:
            \\  SCRYPTKYDDY_ACTORS: {s}
            \\  SCRYPTKYDDY_LOCALCATALOGUES: {s}
            \\  SCRYPTKYDDY_SCRYPTS: {s}
            \\  SCRYPTKYDDY_BIN: {s}
        , .{
            env_res.actor_directory, env_res.catalogue_directory,
            env_res.universal_scrypt_install_directory, env_res.universal_scrypt_symlink_directory,
        });
        return error.UndefinedEnvironmentVariable;
    }


    //// SECTION
    // dedicated to parts of the program that must run no matter what mode is particularly chosen

    // creates and owns its own DirectoryContext
    var actors_map = ActorsMapping.init(env_res.actor_directory, io, allocator) catch |err| {
        std.log.err("Could not create actors mapping due to error: {}", .{err});
        if (err == std.Io.Dir.OpenError.FileNotFound) {
            std.log.err("Are you sure the actor directory '{s}' exists?", .{env_res.actor_directory});
        }
        return err;
    };
    defer actors_map.deinit();
    try actors_map.registerActors();

    var catalogue = Catalogue.init(allocator, io);
    defer catalogue.deinit();
    // creates and owns its own DirectoryContext during lifetime of the function (defers deinit to end of the call,
    // not until end of life of catalogue because all thats needed from catalogue is the information, not necessarily
    // the actual toml files after being parsed or their parent directory (of which is the DirectoryContext)
    try catalogue.parseDirectory(env_res.catalogue_directory);

    std.log.info("Assembled catalogue of {} scrypts from {} parts.", .{
        catalogue.scrypts.items.len,
        catalogue.results.items.len
    });


    //// SECTION
    // dedicated to getting necessary information prior to scrypt actors

    // TODO: get from argv properly, with a custom argparser
    var scrypt_name: []const u8 = argv[1];

    // different output directory and name if has a modifier suffix
    var is_actor = false;
    var is_catalogue = false;
    if (std.mem.endsWith(u8, scrypt_name, "@Actor")) {
        scrypt_name = scrypt_name[0 .. scrypt_name.len - 6]; // get all before "@Actor"
        is_actor = true;
    } else if (std.mem.endsWith(u8, scrypt_name, "@Catalogue")) {
        scrypt_name = scrypt_name[0 .. scrypt_name.len - 10]; // get all before "@Catalogue"
        is_catalogue = true;
    }

    // placeholders in order to load from scrypt
    var fetch_actor_name: []const u8 = "";
    var fetch_actor_url: []const u8 = "";
    var install_actor_name: []const u8 = "";

    var integrity_role: *Role = undefined;
    var compile_role: *Role = undefined;
    var link_role: *Role = undefined;

    // populates the above variables
    var scrypt_was_found = false;
    for (catalogue.scrypts.items) |scrypt| {
        if (!std.mem.eql(u8, scrypt.id, scrypt_name)) continue;
        scrypt_was_found = true; // scrypt here is the same id as target scrypt
        // as it ceases on the first encounter of a scrypt with the id, priority can be managed by the user through the
        // order of files in the directory (or, later when impl, list of remotes in a config file)

        for (scrypt.roles) |*role| {
            if (std.mem.eql(u8, role.role, "fetch")) {
                fetch_actor_name = role.actor;
                fetch_actor_url = scrypt.source;
            } else if (std.mem.eql(u8, role.role, "install")) {
                install_actor_name = role.actor;
            } else if (std.mem.eql(u8, role.role, "integrity")) {
                integrity_role = role;
            } else if (std.mem.eql(u8, role.role, "compile")) {
                compile_role = role;
            } else if (std.mem.eql(u8, role.role, "link")) {
                link_role = role;
            }
        }
        break; // here is the break and thus chooses of first priority
    }
    if (!scrypt_was_found) {
        std.log.err("Scrypt {s} not found in catalogue. Check if the name is correct.", .{scrypt_name});
        return error.ScryptNotFound;
    }

    // join together paths for the installation directory: e.g., ?/scryptkyddy/scrypts
    // const scrypt_install_directory = try std.fs.path.join(allocator, &.{
    //     env_res.universal_scrypt_install_directory,
    //     scrypt_name,
    // });

    const scrypt_install_directory = if (is_actor) env_res.actor_directory
    else if (is_catalogue) env_res.catalogue_directory
    else // a regular scrypt, so should use regular path
        try std.fs.path.join(allocator, &.{
            env_res.universal_scrypt_install_directory,
            scrypt_name,
        });
    defer if (!is_actor and !is_catalogue) {
        allocator.free(scrypt_install_directory);
    };

    // and for the bin directory (symlinks): e.g., ?/scryptkyddy/bin
    const scrypt_symlink_path = if (is_actor or is_catalogue) ""
    else
        try std.fs.path.join(allocator, &.{
            env_res.universal_scrypt_symlink_directory,
            scrypt_name,
        });
    defer if (!is_actor and !is_catalogue) {
        allocator.free(scrypt_symlink_path);
    };

    //// SECTION
    // dedicated to running actors

    const contents = try actors_map.callActor(fetch_actor_name, "fetch", &.{
        fetch_actor_url,
    }, .{});
    defer actors_map.dir_ctx.alloc.free(contents);

    const install_stdout = try actors_map.callActor(install_actor_name, "install", &.{
        scrypt_install_directory,
        scrypt_name,
        scrypt_symlink_path,
    }, .{
        .allowsInput = true,
        .input = contents,
    });
    defer actors_map.dir_ctx.alloc.free(install_stdout);

    std.log.info("Successfully installed {s} from {s} to directory {s}/. Try it out!", .{
        scrypt_name, fetch_actor_url, env_res.universal_scrypt_symlink_directory
    });

    std.log.warn("NOTICE: you may need to make the symlink executable", .{});
}