const std = @import("std");

fn addActor(b: *std.Build, name: []const u8) void {
    const cmd = b.addSystemCommand(&.{
        "zig", "build", "--prefix", "../../actors-bin"
    });

    cmd.setCwd(b.path(b.pathJoin(&.{
        "actors", name
    })));
    cmd.has_side_effects = true;

    const step = b.step(name, b.fmt("Builds actor: {s}", .{name}));
    step.dependOn(&cmd.step);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ScryptKyddy",
        .root_module = exe_mod,
    });

    const toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("toml", toml.module("toml"));

    b.installArtifact(exe);

    // build steps for builtin actors
    addActor(b, "http-actor");
    addActor(b, "single-file-write-actor");

    //
    // run step
    // run with `zig build run`
    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
