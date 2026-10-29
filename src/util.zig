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
};