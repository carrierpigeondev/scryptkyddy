const std = @import("std");
const toml = @import("toml");

const DirectoryContext = @import("directory_context.zig").DirectoryContext;

pub const Role = struct {
    role: []const u8,
    actor: []const u8,
    args: ?[]const []const u8
};

pub const Scrypt = struct {
    id: []const u8,
    source: []const u8,
    roles: []Role,
};

pub const CatalogueFile = struct {
    scrypts: []Scrypt,
};

pub const Catalogue = struct {
    scrypts: std.ArrayList(Scrypt),
    parser: toml.Parser(CatalogueFile),
    alloc: std.mem.Allocator,
    io: std.Io,

    results: std.ArrayList(toml.Parsed(CatalogueFile)),

    pub fn init(alloc: std.mem.Allocator, io: std.Io) Catalogue {
        var parser = toml.Parser(CatalogueFile).init(alloc);
        parser.options.disallow_unknown_fields = true;

        return Catalogue {
            .scrypts = .empty,
            .parser = parser,
            .alloc = alloc,
            .io = io,

            .results = .empty,
        };
    }

    pub fn deinit(self: *Catalogue) void {
        self.parser.deinit();
        for (self.results.items) |result| {
            result.deinit();
        }

        self.results.deinit(self.alloc);
        self.scrypts.deinit(self.alloc);
    }

    pub fn parseDirectory(self: *Catalogue, source: []const u8) !DirectoryContext {
        var dir_ctx_cat = DirectoryContext.init(source, self.io, self.alloc);
        try dir_ctx_cat.discover();
        errdefer dir_ctx_cat.deinit();

        for (dir_ctx_cat.children_names.items) |entry| {
            // dir_ctx_cat already contains entry because getting it from the arraylist, so do not need to waste calls on
            // checking if it is in the directory
            const path = dir_ctx_cat.getFullPath(entry);
            self.parse(path);
        }

        return dir_ctx_cat;
    }

    /// will not return an error, but provide a warning and add nothing
    pub fn parse(self: *Catalogue, source: []const u8) void {
        const result = self.parser.parseFile(self.io, source) catch |err| {
            std.log.warn("Could not parse {s} due to {}.", .{source, err});
            return;
        };
        self.results.append(self.alloc, result) catch |err| {
            std.log.warn("Could not parse {s} due to {}.", .{source, err});
            return;
        }; // to deinit at end of life

        const value = result.value;
        for (value.scrypts) |scrypt| {
            // need to check to ensure has all necessary roles (fetch and install)
            var has_fetch = false;
            var has_install = false;
            for (scrypt.roles) |role| {
                if (std.mem.eql(u8, role.role, "fetch")) {
                    has_fetch = true;
                } else if (std.mem.eql(u8, role.role, "install")) {
                    has_install = true;
                }
            }
            if (!(has_fetch and has_install)) {
                std.log.warn("Could not add {s} from {s} due to lacking either fetch or install.", .{scrypt.id, source});
                continue;
            }

            self.scrypts.append(self.alloc, scrypt) catch |err| {
                std.log.warn("Could not add {s} from {s} due to {}.", .{scrypt.id, source, err});
                continue;
            };
        }
    }
};

