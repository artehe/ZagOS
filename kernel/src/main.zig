//! The entry point to the kernel and where the magic begins

const builtin = @import("builtin");
const limine = @import("limine");
const std = @import("std");
const log = std.log.scoped(.main);

const arch = @import("arch/module.zig");
const limine_requests = @import("limine_requests.zig");
const logging = @import("logging.zig");
const kernel_panic = @import("panic.zig");
const terminal = @import("terminal/module.zig");
const test_runner = @import("test_runner.zig");

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
    arch.platform.hang();
}

/// The Kernel's entry point
export fn _start() callconv(.C) noreturn {
    arch.platform.setup();
    if (builtin.is_test) {
        test_runner.runTests();
    } else {
        main();
    }
    unreachable;
}

test "testing simple sum" {
    const a: u8 = 2;
    const b: u8 = 2;
    try std.testing.expect((a + b) == 4);
}
