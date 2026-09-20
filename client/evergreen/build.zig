pub fn build(b: *Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .windows, .cpu_arch = .x86_64 } });

    const exe = b.addExecutable(.{
        .name = "AzurPromilia",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addAnonymousImport(
        "config.zon",
        .{ .root_source_file = b.path("config.zon") },
    );

    exe.root_module.addObjectFile(.{
        .src_path = .{
            .owner = b,
            .sub_path = "./assets/IconGroup103.res",
        },
    });

    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(b.path("assets/doro/colorful"), "doro-colorful");
    _ = wf.addCopyFile(b.path("assets/doro/colorless"), "doro-colorless");
    const doro_zig = wf.add("doro.zig",
        \\pub const colorful = @embedFile("doro-colorful");
        \\pub const colorless = @embedFile("doro-colorless");
    );
    const doro_mod = b.createModule(.{
        .root_source_file = doro_zig,
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("doro", doro_mod);

    b.installArtifact(exe);
}

const Build = std.Build;
const std = @import("std");
