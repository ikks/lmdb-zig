const std = @import("std");

pub fn build(b: *std.Build) void {
    var target = b.standardTargetOptions(.{});
    if (target.result.isGnuLibC()) target.result.abi = .musl;
    const optimize = b.standardOptimizeOption(.{});

    const dep_lmdb_c = b.dependency("lmdb_c", .{
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "lmdb-zig",
        .root_source_file = b.path("lmdb.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();

    lib.addCSourceFiles(.{
        .root = dep_lmdb_c.path("libraries/liblmdb"),
        .files = &.{ "mdb.c", "midl.c" },
        .flags = &.{"-fno-sanitize=undefined"},
    });

    lib.installHeadersDirectory(dep_lmdb_c.path("libraries/liblmdb"), "", .{
        .include_extensions = &.{"lmdb.h"},
    });

    const mod = b.addModule("lmdb-zig-mod", .{
        .root_source_file = b.path("lmdb.zig"),
    });

    mod.addIncludePath(dep_lmdb_c.path(""));

    b.installArtifact(lib);

    const tests = b.addTest(.{
        .name = "test",
        .root_source_file = mod.root_source_file.?,
        .target = target,
        .optimize = optimize,
    });

    tests.linkLibrary(lib);
    b.installArtifact(tests);

    const test_step = b.step("test", "Run libary tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
