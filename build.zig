const std = @import("std");

pub fn build(b: *std.Build) !void {
    _ = b.addModule("composable-allocators", .{
        .source_file = .{ .path = "lib.zig" },
    });

    const tests = b.addTest(.{
        .root_source_file = .{ .path = "lib.zig" },
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}
