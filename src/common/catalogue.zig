const std = @import("std");
const toml = @import("toml");

const DirectoryContext = @import("directory_context.zig").DirectoryContext;

pub const Scrypt = struct {
    id: []const u8,
    source: []const u8,
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

    pub fn parseDirectory(self: *Catalogue, source: []const u8) !void {
        var dir_ctx_cat = DirectoryContext.init(source, self.io, self.alloc);
        try dir_ctx_cat.discover();
        defer dir_ctx_cat.deinit();

        for (dir_ctx_cat.children_names.items) |entry| {
            // dir_ctx_cat already contains entry because getting it from the arraylist, so do not need to waste calls on
            // checking if it is in the directory
            const path = dir_ctx_cat.getFullPath(entry);
            self.parse(path);
        }
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
            self.scrypts.append(self.alloc, scrypt) catch |err| {
                std.log.warn("Could not parse {s} due to {}.", .{source, err});
                return;
            };
        }
    }
};

