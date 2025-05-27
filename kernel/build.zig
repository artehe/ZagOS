const std = @import("std");

/// An enum of the CPU architechtures supported.
const Arch = enum {
    x86_64,
};

/// Get target query for the kernel based on the target value
fn getTargetQuery(arch: Arch) std.Target.Query {
    return switch (arch) {
        .x86_64 => {
            var query = std.Target.Query{
                .abi = .none,
                .cpu_arch = .x86_64,
                .ofmt = .elf,
                .os_tag = .freestanding,
            };

            // Disable all hardware floating point features and enable software floating point.
            const Target = std.Target.x86;
            query.cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx });
            query.cpu_features_add = Target.featureSet(&.{ .popcnt, .soft_float });

            return query;
        },
    };
}

pub fn build(b: *std.Build) void {
    // Create an option to specify the target CPU arch we want to build for
    const arch = b.option(
        Arch,
        "arch",
        "Target architecture to build for",
    ) orelse .x86_64;

    // Optimization level(s) to use
    const optimize = b.standardOptimizeOption(.{});

    const target_query = getTargetQuery(arch);
    const resolved_target_query = b.resolveTargetQuery(target_query);

    // Create the kernel executable.
    switch (arch) {
        .x86_64 => {
            // We depend on the limine_zig package, which provides a module for
            // interacting with the Limine bootloader.
            const limine_zig = b.dependency("limine_zig", .{
                .api_revision = 3,
            });
            const limine_module = limine_zig.module("limine");

            // Build the kernel 'module'
            const kernel_module = b.addModule("kernel", .{
                .optimize = optimize,
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target_query,
            });

            // Specify the code model specific options.
            kernel_module.red_zone = false;
            kernel_module.code_model = .kernel;

            // Add the limine module as an import to the kernel module.
            kernel_module.addImport("limine", limine_module);

            // Create the kernel executable
            const kernel_exe = b.addExecutable(.{
                .name = "kernel",
                .root_module = kernel_module,
            });
            kernel_exe.setLinkerScript(b.path("src/arch/x86_64/linker.ld"));
            b.installArtifact(kernel_exe);

            // Also create a test kernel
            const kernel_test = b.addTest(.{
                .name = "kernel_test",
                .root_module = kernel_module,
                .test_runner = .{
                    .path = b.path("src/test_runner.zig"),
                    .mode = .simple,
                },
                .target = resolved_target_query,
            });
            kernel_test.root_module.addImport("kernel", kernel_module);
            kernel_test.setLinkerScript(b.path("src/arch/x86_64/linker.ld"));
            b.installArtifact(kernel_test);
        },
    }
}
