//! The entry point to the kernel and where the magic begins

const limine = @import("limine");
const std = @import("std");
const builtin = std.builtin;
const log = std.log.scoped(.main);

const arch = @import("arch.zig");
const limine_reuqests = @import("limine_requests.zig");
const framebuffer = @import("framebuffer.zig");
const logging = @import("logging.zig");

/// Sets the base revision of the limine protocol which is supported by the kernel
export var base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);

/// Set the standard library options
pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = logging.logFn,
};

/// The kernel's main function where most of the setup and then future runnin happens
fn main() noreturn {
    log.info("Hello World from ZagOS Kernel", .{});

    framebuffer.init();

    // Initialize the rest of the system.
    arch.platform.init();

    // The kernel should NEVER return so loop endlessly.
    log.info("Reached end of kernel main, looping forever", .{});
    arch.platform.hang();
}

/// Handles kernel panics, such @panic() or integer overflows.
pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    // TODO handle these and putput a proper stack trace etc etc
    _ = stack_trace;
    _ = return_address;

    log.err("!!! Kernel Panic !!!", .{});
    log.err("{s}", .{msg});
    log.err("!!! End Panic !!!", .{});

    log.info("!!! Panic hanging forever !!!", .{});
    arch.platform.hang();
}

/// The Kernel's entry point
export fn _start() callconv(.C) noreturn {
    arch.platform.setup();

    // Do not proceed if the kernel's base revision is not supported by the bootloader.
    if (!base_revision.isSupported()) {
        @panic("Base revision not supported by bootloader");
    }

    main();
    unreachable;
}
