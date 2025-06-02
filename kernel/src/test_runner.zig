//! Test runner for the kernel
//!
//! Note: we don't have an entry point here as we use `_start` which is already in `src/main.zig`

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.test_runner);

const arch = @import("arch/module.zig");
const kernel_panic = @import("panic.zig");
const logging = @import("logging.zig");

pub const QemuExitCode = enum(u8) {
    success = 0x10,
    failed = 0x11,
    _,
};

/// Set the standard library options and panic function
pub const panic = kernel_panic.panic;
pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = logging.logFn,
};

pub fn exitQemu(exit_code: QemuExitCode) void {
    switch (builtin.cpu.arch) {
        .x86_64 => {
            log.debug("Quitting Qemu", .{});
            const port = arch.platform.port;
            const exit_port = 0xF4;
            port.outb(exit_port, @intFromEnum(exit_code));
        },
        else => @compileError("Architecture not currently supported!"),
    }
}
