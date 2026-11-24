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

    const catalogues = d.children_names.items;
    const n = catalogues.len;

    // remove all the stuff because it needs to be redone
    _ = n;
    _ = exec_name;
}