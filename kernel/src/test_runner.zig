//! Test runner for the kernel
//!
//! Note: we don't have any entry point here. The entry point can't be renamed, so we
//! use `_start` which is already in `src/main.zig`

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.test_runner);

const kernel = @import("kernel");

/// Set the standard library options and panic function
pub const std_options = kernel.std_options;
pub const panic = kernel.panic;

/// The custom test runner
pub fn runTests() noreturn {
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

    switch (builtin.cpu.arch) {
        .x86_64 => {
            log.debug("Shutting down", .{});
        },
        else => @compileError("Architecture not currently supported!"),
    }
    unreachable;
}
