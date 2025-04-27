const std = @import("std");

/// An enum of the CPU architechtures supported.
const Arch = enum {
    x86_64,
};

/// Get target query for the kernel based on the target value
fn getTargetQuery(arch: Arch) std.Target.Query {
    return switch (arch) {
        .x86_64 => {
            // Disable all hardware floating point features.
            var disabled_features: std.Target.Cpu.Feature.Set = .empty;
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx));
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.avx2));
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.mmx));
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse));
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.sse2));
            disabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.x87));

            // Enable software floating point instead.
            var enabled_features: std.Target.Cpu.Feature.Set = .empty;
            enabled_features.addFeature(@intFromEnum(std.Target.x86.Feature.soft_float));

            return std.Target.Query{
                .abi = .none,
                .cpu_arch = .x86_64,
                .cpu_features_sub = disabled_features,
                .cpu_features_add = enabled_features,
                .ofmt = .elf,
                .os_tag = .freestanding,
            };
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
            // Build the kernel
            const kernel = b.addExecutable(.{
                .code_model = .kernel, // Higher half kernel.
                .linkage = .static, // Disable dynamic linking.
                .name = "kernel.elf",
                .omit_frame_pointer = false, // Needed for stack traces.
                .optimize = optimize,
                .pic = false, // Disable position independent code.
                .root_source_file = b.path("src/main.zig"),
                .target = resolved_target_query,
            });

            // Add the Limine library as a dependency.
            const limine_zig = b.dependency("limine_zig", .{
                .allow_deprecated = false,
                .api_revision = 3,
            });
            const limine_module = limine_zig.module("limine");
            kernel.root_module.addImport("limine", limine_module);

            // Disable features that are problematic in kernel space.
            kernel.root_module.red_zone = false;
            kernel.root_module.stack_check = false;
            kernel.root_module.stack_protector = false;
            kernel.want_lto = false;

            // Delete unused sections to reduce the kernel size.
            kernel.link_function_sections = true;
            kernel.link_data_sections = true;
            kernel.link_gc_sections = true;

            // Force the page size to 4 KiB to prevent binary bloat.
            kernel.link_z_max_page_size = 0x1000;

            // Link with a custom linker script.
            kernel.setLinkerScript(b.path("src/arch/x86_64/linker.ld"));

            b.installArtifact(kernel);
        },
    }
}
