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
    arch.platform.hang();
}

/// The main function when running kernel tests.
fn testMain() noreturn {
    // A unique case where we want to import the type in the function as this is
    // only used for tests
    const test_runner = @import("test_runner.zig");
    const QemuExitCode = test_runner.QemuExitCode;

    // Run all the located tests
    const test_functions_list = builtin.test_functions;
    log.info("Found {} tests", .{test_functions_list.len});

    var fail_count: usize = 0;
    var pass_count: usize = 0;
    var skip_count: usize = 0;

    for (test_functions_list, 1..) |test_function, i| {
        if (test_function.func()) |_| {
            log.info("test {}/{} {s} passed", .{ i, test_functions_list.len, test_function.name });
            pass_count += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                log.warn("test {}/{} {s} skipped", .{ i, test_functions_list.len, test_function.name });
                skip_count += 1;
            },
            else => {
                log.err("test {}/{} {s} failed with {s}", .{ i, test_functions_list.len, test_function.name, @errorName(err) });
                fail_count += 1;
            },
        }
    }

    const total_run_tests = pass_count + fail_count;
    log.info("Finished!", .{});
    log.info("{d} of {d} run test(s) passed", .{ pass_count, total_run_tests });
    if (skip_count > 0) {
        log.info("{d} test(s) skipped", .{skip_count});
    }

    if (fail_count > 0) {
        test_runner.exitQemu(QemuExitCode.failed);
    } else {
        test_runner.exitQemu(QemuExitCode.success);
    }
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

test "trivial_assertion" {
    try std.testing.expect(1 == 0);
}

test "simple_sum" {
    const a: u8 = 2;
    const b: u8 = 2;
    try std.testing.expect((a + b) == 4);
}
