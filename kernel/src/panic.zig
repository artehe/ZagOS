//! Handles kernel panics, providing helpful debug information to find the source of the issue

const std = @import("std");
const builtin = std.builtin;
const log = std.log.scoped(.panic);

const arch = @import("arch/module.zig");
const logging = @import("logging.zig");

/// Handles kernel panics, such @panic() or integer overflows.
pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    // TODO handle these and putput a proper stack trace etc etc
    _ = stack_trace;
    _ = return_address;

    log.err("\n======== Kernel Panic ========!!!", .{});
    log.err("<Message>: {s}", .{msg});
    log.info("Kernel will now hang forever", .{});
    log.err("======== End Panic ========\n", .{});

    arch.platform.hang();
}
