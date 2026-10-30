const std = @import("std");

pub const DirectoryContext = struct {
    path: []const u8,

    io: std.Io,
    alloc: std.mem.Allocator,

    dir: std.Io.Dir,
    childrenNames: std.ArrayList([]const u8),

    pub fn init(path: []const u8, io: std.Io, allocator: std.mem.Allocator) DirectoryContext {
        return DirectoryContext {
            .path = path,
            .io = io,
            .alloc = allocator,
            .dir = undefined,
            .childrenNames = std.ArrayList([]const u8).empty,
        };
    }

    pub fn deinit(self: *DirectoryContext) void {
        // destroy the children name entries before deinit arraylist
        for (self.childrenNames.items) |entry| {
            self.alloc.free(entry);
        }

        // deinit the arraylist
        self.childrenNames.deinit(self.alloc);

        // close the directory
        self.dir.close(self.io);
    }

    pub fn discover(self: *DirectoryContext) !void {
        // open the directory
        // needs to keep the directory so that it can be opened
        self.dir = try std.Io.Dir.cwd().openDir(self.io, self.path, .{ .iterate = true });
        errdefer self.dir.close(self.io);

        // iterate over the directories and duplicate their names to the arraylist so theres no undefined behavior
        // on the next iteration (errdefer on dupe since DirectoryContext.deinit() closes it)
        var iter = self.dir.iterate();
        while (try iter.next(self.io)) |entry| {
            if (entry.kind != .file) continue; // just files
            
            const name = try self.alloc.dupe(u8, entry.name);
            errdefer self.alloc.free(name);
            
            try self.childrenNames.append(self.alloc, name);
        }
    }

    pub fn containsFile(self: *DirectoryContext, name: []const u8) bool {
        for (self.childrenNames.items) |entry| {
            if (std.mem.eql(u8, entry, name)) {
                return true;
            }
        }
        return false;
    }

    // use in conjunction with containsFile() for safe reading
    // this will not return an error, but undefined if unable to read
    // allocates memory and must be freed by self.alloc
    pub fn readFileAlloc(self: *DirectoryContext, name: []const u8) []u8 {
        return self.dir.readFileAlloc(self.io, name, self.alloc, .unlimited) catch |err| {
            std.log.warn("Cannot read file {s} in directory {s} due to {}.", .{name, self.path, err});
            return undefined;
        };
    }
};