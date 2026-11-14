const std = @import("std");
const zip = @import("archive").algorithms.zip;

fn broadcast(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, "install");
}

/// according to API spec:
///   - argv[0] : program name
///   - argv[1] : "install"
///   - argv[2] : Output Directory
///   - argv[3] : Output Symlink Path
///
///  extracts contents, detects the primary file name, (NYI: and creates a symlink)

fn install(io: std.Io, alloc: std.mem.Allocator, argv: []const []const u8) !void {
    var stdin_buffer: [4096]u8 = undefined;

    var r = std.Io.File.stdin().readerStreaming(io, &stdin_buffer);
    const input_contents = try r.interface.allocRemaining(alloc, .unlimited);
    defer alloc.free(input_contents);

    const outdir = try std.Io.Dir.cwd().createDirPathOpen(io, argv[2], .{});
    defer outdir.close(io);

    var zip_archive: zip.ZipArchive = try .init(alloc, input_contents);
    defer zip_archive.deinit();

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
    }
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
