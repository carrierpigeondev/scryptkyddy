const std = @import("std");

pub const DirectoryContext = struct {
    path: []const u8,

    io: std.Io,
    alloc: std.mem.Allocator,

    dir: std.Io.Dir,
    children_names: std.ArrayList([]const u8),
    
    _allocations: std.ArrayList([]const u8), // arraylist to deallocate

    /// initializes a new `DirectoryContext`; however, must still `.discover()` in order to populate the `.dir` and
    /// `.children_names` fields (to use other functions like `.containsFile()` or `.readFileAlloc()`
    pub fn init(path: []const u8, io: std.Io, allocator: std.mem.Allocator) DirectoryContext {
        return DirectoryContext {
            .path = path,
            .io = io,
            .alloc = allocator,
            .dir = undefined,
            .children_names = std.ArrayList([]const u8).empty,
            ._allocations = std.ArrayList([]const u8).empty,
        };
    }

    /// must be called in order to free memory that has been allocated by `.alloc`
    pub fn deinit(self: *DirectoryContext) void {
        // destroy loose allocations
        for (self._allocations.items) |entry| {
            self.alloc.free(entry);
        }
        self._allocations.deinit(self.alloc);
        
        // destroy the children name entries before deinit arraylist
        for (self.children_names.items) |entry| {
            self.alloc.free(entry);
        }

        // deinit the arraylist
        self.children_names.deinit(self.alloc);

        // close the directory
        self.dir.close(self.io);
    }

    /// populates the `.dir` and `.children_names` fields
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
            
            try self.children_names.append(self.alloc, name);
        }
    }

    /// returns true if the `.children_names` field contains value of `name`
    pub fn containsFile(self: *DirectoryContext, name: []const u8) bool {
        for (self.children_names.items) |entry| {
            if (std.mem.eql(u8, entry, name)) {
                return true;
            }
        }
        return false;
    }

    /// use in conjunction with containsFile() for safe reading
    /// this will not return an error, but undefined if unable to read
    /// allocates memory and must be freed by self.alloc
    pub fn readFileAlloc(self: *DirectoryContext, name: []const u8) []u8 {
        return self.dir.readFileAlloc(self.io, name, self.alloc, .unlimited) catch |err| {
            std.log.warn("Cannot read file {s} in directory {s} due to {}.", .{name, self.path, err});
            return undefined;
        };
    }
    
    pub fn getFullPath(self: *DirectoryContext, name: []const u8) []u8 {
        const joined_path = std.Io.Dir.path.join(self.alloc, &.{self.path, name}) catch |err| {
            std.log.warn("Cannot join paths {s} and {s} due to {}.", .{self.path, name, err});
            return "";
        };
        errdefer self.alloc.free(joined_path);

        self._allocations.append(self.alloc, joined_path) catch |err| {
            std.log.err("Failed to allocate memory for the joined path {s} due to {}.", .{joined_path, err});
        };
        return joined_path;
    }
};