//! The entry point to the kernel and where the magic begins

const builtin = @import("builtin");
const limine = @import("limine");
const std = @import("std");
const log = std.log.scoped(.main);

const arch = @import("arch/module.zig");
const limine_reuqests = @import("limine_requests.zig");
const logging = @import("logging.zig");
const kernel_panic = @import("panic.zig");
const terminal = @import("terminal/module.zig");
const testing = @import("testing.zig");

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

    // Initialize the terminal.
    terminal.init();
    logging.enableTerminal();
    log.info("Welcome to ZagOS", .{});

    // Initialize the rest of the system.
    arch.platform.init();

    // The kernel should NEVER return so loop endlessly.
    log.info("Reached end of kernel main, looping forever", .{});
    arch.platform.hang();
}

// As this need to be in the root source file, all we do is call our actual kernel panic handler
pub fn panic(msg: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    kernel_panic.panic(msg, stack_trace, return_address);
}

/// The Kernel's entry point
export fn _start() callconv(.C) noreturn {
    arch.platform.setup();

    // Do not proceed if the kernel's base revision is not supported or valid.
    if (!base_revision.isSupported()) {
        @panic("Base revision not supported by bootloader");
    }
    if (!base_revision.isValid()) {
        @panic("Base revision not valid");
    }

    if (builtin.is_test) {
        testing.testMain();
    } else {
        main();
    }
    unreachable;
}
