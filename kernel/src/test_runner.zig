//! Test runner for the kernel, this is loaded as the root when we launch in test mode so we define
//! some core functionality like panic and logging
//!
//! Note: we don't have an entry point here as we use `_start` which is already in `src/main.zig`

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.runner);

const arch = @import("arch/module.zig");
const kernel_panic = @import("panic.zig");
const logging = @import("logging.zig");
const testing = @import("testing/module.zig");
const QemuExitCode = testing.QemuExitCode;

/// Set the standard library options and panic function
pub const panic = kernel_panic.panic;
pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = logging.testLogFn,
};

pub fn testRunner() noreturn {
    // Run all the located tests
    const test_functions_list = builtin.test_functions;
    logging.writeFormattedString("Found {} tests\n", .{test_functions_list.len});

    var pass_count: usize = 0;
    var skip_count: usize = 0;

    for (test_functions_list, 1..) |test_function, i| {
        logging.writeFormattedString("test {}/{} {s} ... ", .{
            i,
            test_functions_list.len,
            test_function.name,
        });

        if (test_function.func()) |_| {
            logging.writeFormattedString("[PASS]\n", .{});
            pass_count += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                logging.writeFormattedString("[SKIP]\n", .{});
                skip_count += 1;
            },
            else => {
                logging.writeFormattedString("[FAIL]\n Error: {}\n", .{err});
                testing.exitQemu(QemuExitCode.failed);
            },
        }
    }

    const total_run_tests = pass_count;
    logging.writeFormattedString("Finished!\n", .{});
    logging.writeFormattedString("{d} of {d} run test(s) passed\n", .{ pass_count, total_run_tests });
    if (skip_count > 0) {
        logging.writeFormattedString("{d} test(s) skipped\n", .{skip_count});
    }

    testing.exitQemu(QemuExitCode.success);
    unreachable;
}
