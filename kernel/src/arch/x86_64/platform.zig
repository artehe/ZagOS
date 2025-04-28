//! Kernel code for the x86_64 architecture

const std = @import("std");
const log = std.log.scoped(.platform);

pub const serial = @import("serial.zig");

// Some constants defined in the kernel linker script
extern const __kernel_start: usize;
extern const __kernel_end: usize;

/// Stop any interrupts from being triggered and then loop endlessly
pub fn hang() noreturn {
    asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

/// The specific initialisation for this platform (architecture).
pub fn init() void {
    log.info("Initialising kernel for x86_64", .{});
    // TODO gdt.init();
}
