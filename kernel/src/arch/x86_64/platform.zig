//! Kernel code for the x86_64 architecture

const std = @import("std");
const log = std.log.scoped(.platform);

const gdt = @import("gdt.zig");
pub const interrupts = @import("interrupts/module.zig");
pub const port = @import("port.zig");
pub const serial = @import("serial.zig");

pub extern const __stack_bottom: anyopaque;
pub extern const __stack_top: anyopaque;

/// Loop endlessly
pub fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

/// The specific initialisation for this platform (architecture).
pub fn init() void {
    log.info("Initialising kernel architecture: x86_64", .{});

    gdt.init();
    interrupts.init();

    log.info("Done", .{});
}

/// Do some essential work (where the processor can't continue without that work)
pub inline fn setup() void {
    asm volatile ("mov %rsp, %[stack_top]"
        :
        : [stack_top] "m" (@intFromPtr(&__stack_top)),
    );
}
