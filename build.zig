const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ProtectedZoneTesting",
        .root_module = exe_mod,
    });

    // const raylib_dep = b.dependency("raylib_zig", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .platform = .rgfw,
    // });
    // exe.root_module.addImport("raylib", raylib_dep.module("raylib"));
    // exe.root_module.linkLibrary(raylib_dep.artifact("raylib"));

    const pMathz_dep = b.dependency("pMathz", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("pMathz", pMathz_dep.module("pMathz"));
    exe.root_module.linkLibrary(pMathz_dep.artifact("pMathz"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
