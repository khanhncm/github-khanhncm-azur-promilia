const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .windows, .cpu_arch = .x86_64 } });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addAnonymousImport("config.zon", .{
        .root_source_file = b.path("config.zon"),
    });

    const exe = b.addExecutable(.{
        .name = "AzurPromilia",
        .root_module = exe_mod,
    });

    exe_mod.addObjectFile(b.path("assets/IconGroup103.res"));

    b.installArtifact(exe);
}

