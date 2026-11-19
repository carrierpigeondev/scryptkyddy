const std = @import("std");

const DirectoryContext = @import("directory_context.zig").DirectoryContext;

const http_actor = @import("../builtin-actors/http-actor.zig");
const single_file_write_actor = @import("../builtin-actors/single-file-write-actor.zig");
const symlink_actor = @import("../builtin-actors/symlink-actor.zig");

/// maps current actors to arraylists for their available roles
pub const ActorsMapping = struct {
    alloc: std.mem.Allocator,
    dir_ctx: DirectoryContext,

    fetch_actors: std.ArrayList([]const u8),
    install_actors: std.ArrayList([]const u8),

    // e.g., check checksums with different algorithms (SHA256, MD5, etc.)
    integrity_actors: std.ArrayList([]const u8),
    // e.g., GCC, MSVC, Zig, etc.
    compile_actors: std.ArrayList([]const u8),
    // e.g., symlink (with exec permission add) actor for Linux or hardlink for Windows
    link_actors: std.ArrayList([]const u8),

    pub fn init(actor_directory: []const u8, io: std.Io, allocator: std.mem.Allocator) !ActorsMapping {
        var dir_ctx = DirectoryContext.init(
            actor_directory,
            io,
            allocator
        );
        try dir_ctx.discover();

        return .{
            .alloc = allocator,
            .dir_ctx = dir_ctx,
            .fetch_actors = .empty,
            .install_actors = .empty,
            .integrity_actors = .empty,
            .compile_actors = .empty,
            .link_actors = .empty,
        };
    }

    pub fn deinit(self: *ActorsMapping) void {
        self.dir_ctx.deinit();

        // the DirectoryContext for the actors owns and frees the paths themselves, so no 2nd free here
        self.fetch_actors.deinit(self.alloc);
        self.install_actors.deinit(self.alloc);
        self.integrity_actors.deinit(self.alloc);
        self.compile_actors.deinit(self.alloc);
        self.link_actors.deinit(self.alloc);
    }

    pub fn registerActors(self: *ActorsMapping) !void {
        // parses through all actors in the directory context
        for (self.dir_ctx.children_names.items) |entry| {
            // call the broadcast function to know which roles the actor implements
            const full_path = self.dir_ctx.getFullPath(entry);
            const broadcast_res = std.process.run(self.dir_ctx.alloc, self.dir_ctx.io, .{
                .argv = &.{
                    full_path, // must call full path
                    "broadcast"
                }
            }) catch |err| {
                // this will occur whenever a system cannot execute command (i.e., exe on Linux; elf on Windows)
                std.log.warn("Failed to run the actor {s} due to {}. Forced to skip.", .{entry, err});
                continue;
            };

            defer self.dir_ctx.alloc.free(broadcast_res.stdout);
            defer self.dir_ctx.alloc.free(broadcast_res.stderr);
            const output= broadcast_res.stdout;

            var roles = std.mem.splitScalar(u8, output, '\n');
            while (roles.next()) |role| {
                if (std.mem.eql(u8, role, "fetch")) {
                    try self.fetch_actors.append(self.alloc, full_path);
                    continue;
                }
                if (std.mem.eql(u8, role, "install")) {
                    try self.install_actors.append(self.alloc, full_path);
                    continue;
                }
                if (std.mem.eql(u8, role, "integrity")) {
                    try self.integrity_actors.append(self.alloc, full_path);
                    continue;
                }
                if (std.mem.eql(u8, role, "compile")) {
                    try self.compile_actors.append(self.alloc, full_path);
                    continue;
                }
                if (std.mem.eql(u8, role, "link")) {
                    try self.link_actors.append(self.alloc, full_path);
                    continue;
                }
            }
        }
    }

    pub const CallActorInputOptions = struct {
        allowsInput: bool = false,
        input: []u8 = undefined,
    };

    /// caller MUST MANUALLY FREE memory of returned value using the self.dir_ctx.alloc
    pub fn callActor(self: *ActorsMapping, name: []const u8, role: []const u8, additional_args: []const []const u8, opt: CallActorInputOptions) ![]u8 {
        // builtin actors are called differently since they are a part of this project (since they are needed for
        // bootstrapping other actors; therefore, not in the actorsMapping

        // only fetch implemented for http-actor; so, if a user wants to make their own http-actor with a different role
        // theres no need to impede on their interesting life choices
        if (std.mem.eql(u8, name, "http-actor") and std.mem.eql(u8, role, "fetch")) {
            const _argv = try std.mem.concat(
                self.dir_ctx.alloc,
                []const u8,
                &.{
                    &[_][]const u8{ "http-actor", role },
                    additional_args,
                },
            );
            defer self.dir_ctx.alloc.free(_argv);
            return http_actor.fetch(self.dir_ctx.io, self.dir_ctx.alloc, _argv);
        }

        // only install implemented for single-file-write-actor; so, if a user wants to make their own
        // single-file-write-actor with a different role theres no need to impede on their interesting life choices
        if (std.mem.eql(u8, name, "single-file-write-actor") and std.mem.eql(u8, role, "install")) {
            const _argv = try std.mem.concat(
                self.dir_ctx.alloc,
                []const u8,
                &.{
                    &[_][]const u8{ "single-file-write-actor", role },
                    additional_args,
                },
            );
            defer self.dir_ctx.alloc.free(_argv);
            return single_file_write_actor.install(self.dir_ctx.io, self.dir_ctx.alloc, opt.input, _argv);
        }

        // only link implemented for symlink-actor; so, if a user wants to make their own
        // symlink-actor with a different role theres no need to impede on their interesting life choices
        if (std.mem.eql(u8, name, "symlink-actor") and std.mem.eql(u8, role, "link")) {
            const _argv = try std.mem.concat(
                self.dir_ctx.alloc,
                []const u8,
                &.{
                    &[_][]const u8{ "symlink-actor", role },
                    additional_args,
                },
            );
            defer self.dir_ctx.alloc.free(_argv);
            try symlink_actor.link(self.dir_ctx.io, _argv);
            return try self.dir_ctx.alloc.dupe(u8, ""); // must return something allocated so that the memory
                                                               // can be properly 'freed'
        }

        // actually error instead of waiting for something else to fail, which was the old way of doing things
        if (!self.dir_ctx.containsFile(name)) return error.ActorNotDefined;

        const full_path = self.dir_ctx.getFullPath(name);
        if (!self.isActorValid(full_path, role)) return error.ActorInvalidRole;

        const argv = try std.mem.concat(
            self.dir_ctx.alloc,
            []const u8,
            &.{
                &[_][]const u8{ full_path, role },
                additional_args,
            },
        );
        defer self.dir_ctx.alloc.free(argv);

        if (opt.allowsInput) {
            var child = try std.process.spawn(self.dir_ctx.io, .{
                .argv = argv,
                .stdin = .pipe,
                .stdout = .pipe,
            });
            errdefer child.kill(self.dir_ctx.io);

            try child.stdin.?.writeStreamingAll(self.dir_ctx.io, opt.input);

            child.stdin.?.close(self.dir_ctx.io);
            child.stdin = null;

            var rbuf: [4096]u8 = undefined;
            var r = child.stdout.?.readerStreaming(self.dir_ctx.io, &rbuf);
            const stdout = try r.interface.allocRemaining(self.dir_ctx.alloc,.unlimited,);
            errdefer self.dir_ctx.alloc.free(stdout);

            const term = try child.wait(self.dir_ctx.io);

            if (!term.success()) {
                return error.ActorProcessFailed;
            }

            return stdout;

        } else {
            const res = try std.process.run(self.dir_ctx.alloc, self.dir_ctx.io, .{
                .argv = argv,
            });

            // allocated by self.dir_ctx.alloc; cannot dealloc because needed by caller function
            return res.stdout;
        }
    }

    pub fn isActorValid(self: *ActorsMapping, full_path: []const u8, role: []const u8) bool {
        if (std.mem.eql(u8, role, "fetch")) {
            for (self.fetch_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        if (std.mem.eql(u8, role, "install")) {
            for (self.install_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        if (std.mem.eql(u8, role, "integrity")) {
            for (self.integrity_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        if (std.mem.eql(u8, role, "compile")) {
            for (self.compile_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        if (std.mem.eql(u8, role, "link")) {
            for (self.link_actors.items) |entry| {
                if (std.mem.eql(u8, entry, full_path)) {
                    return true;
                }
            }
        }
        return false;
    }
};