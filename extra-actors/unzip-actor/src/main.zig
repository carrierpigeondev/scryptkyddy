const std = @import("std");
const zip = @import("archive").algorithms.zip;

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "install");
}

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Output Directory
///   - argv[3] : Output Name
///   - argv[4] : Output Symlink Path
///
///  extracts contents, detects the primary file name, (NYI: and creates a symlink)

fn install(io: std.Io, alloc: std.mem.Allocator, argv: []const []const u8) !void {
    var stdin_buffer: [4096]u8 = undefined;

    // // NOTE:
    // This MUST be a .readerStreaming and not a .reader despite the latter working on Linux; I presume some issue is
    // present only in the Windows implementation on how Zig reads from an anonymous pipe, specifically with binary
    // data, which is exactly what is needed here; however, .readStreaming does indeed work on both platforms (I'm
    // pretty sure, haven't test Linux as of writing this comment, so I'm just assuming, and you know what they say
    // about assuming-- it is perfectly fine for 'production' code. haha, I hope no one uses this garbage in production)
    var r = std.Io.File.stdin().readerStreaming(io, &stdin_buffer);
    const input_contents = try r.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(input_contents);

    const outdir = try std.Io.Dir.cwd().createDirPathOpen(io, argv[2], .{});
    defer outdir.close(io);

    var zip_archive: zip.ZipArchive = try .init(alloc, input_contents);
    defer zip_archive.deinit();

    var executable_path: ?[]const u8 = null;
    for (zip_archive.entries.items) |entry| {
        // handles the case of empty directories needing to be created
        if (std.mem.endsWith(u8, entry.name, "/")) {
            const dir = try outdir.createDirPathOpen(io, entry.name, .{});
            dir.close(io);
            continue; // since not a file, continue to next entry
        }

        // when the entry is a file, create its parent directories (handles the majority of cases where dir needs to be
        // created) and continue because the entry itself is a file
        if (std.fs.path.dirname(entry.name)) |parent| {
            const dir = try outdir.createDirPathOpen(io, parent, .{});
            dir.close(io);
        }

        const extracted_contents = try entry.extract(alloc, input_contents);
        defer alloc.free(extracted_contents);

        try outdir.writeFile(io, .{
            .data = extracted_contents,
            .sub_path = entry.name,
        });

        if (std.mem.eql(u8, std.fs.path.basename(entry.name), argv[3])) {
            executable_path = entry.name;
        }
    }

    // do not create symlink if left empty
    if (std.mem.eql(u8, argv[4], "")) {
        return;
    }

    // then also create the symlink to the found executable or error if nothing was detected
    //
    // the files are already extracted however, so the user... if they know what they're doing... can manually symlink
    // or maybe even do something with a postinstallation role down the line
    const entry_path = executable_path orelse return error.ExecutableNotFound;

    const path_of_file = try std.fs.path.join(alloc, &.{
        argv[2], entry_path,
    });
    defer alloc.free(path_of_file);

    return std.Io.Dir.cwd().symLink(io, path_of_file, argv[4], .{}) catch |err| {
        if (err == std.Io.Dir.SymLinkError.PathAlreadyExists) {
            return;
        } else {
            return err;
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const argv = try init.minimal.args.toSlice(init.arena.allocator());

    if (argv.len < 2) {
        std.log.err("No role specified.", .{});
        return;
    }

    const called_role = argv[1];
    if (std.mem.eql(u8, called_role, "broadcast")) {
        try broadcast(init.io);
    } else if (std.mem.eql(u8, called_role, "install")) {
        try install(init.io, init.gpa, argv);
    }
}
