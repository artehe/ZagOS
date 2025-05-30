//! Test runner for the kernel
//!
//! Note: we don't have an entry point here as we use `_start` which is already in `src/main.zig`

const std = @import("std");

const kernel_panic = @import("panic.zig");
const logging = @import("logging.zig");

/// Set the standard library options and panic function
pub const panic = kernel_panic.panic;
pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = logging.logFn,
};
