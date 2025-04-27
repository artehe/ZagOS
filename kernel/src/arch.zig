//! Kernel code for the different CPU architecturess

const builtin = @import("builtin");

pub const platform = switch (builtin.cpu.arch) {
    .x86_64 => @import("arch/x86_64/platform.zig"),
    else => @compileError("Architecture not currently supported!"),
};
