//! The entry point to the kernel and where the magic begins

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.main);
const SystemTable = std.os.uefi.tables.SystemTable;

const arch = @import("arch/module.zig");
const limine = @import("limine.zig");
const logging = @import("logging.zig");
const kernel_panic = @import("panic.zig");
const terminal = @import("terminal/module.zig");

// As this need to be in the root source file, all we do is call our actual kernel panic handler
pub const panic = kernel_panic.panic;

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
    arch.platform.halt();
}

/// The main function when running kernel tests.
fn testMain() noreturn {
    // A unique case where we want to import the type in the function as this is
    // only used for tests
    const runner = @import("test_runner.zig");
    runner.testRunner();
    unreachable;
}

/// The Kernel's entry point
export fn _start() callconv(.C) noreturn {
    arch.platform.setup();
    limine.init();
    if (builtin.is_test) {
        testMain();
    } else {
        main();
    }
    unreachable;
}
