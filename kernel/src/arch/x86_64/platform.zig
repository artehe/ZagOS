//! Kernel code for the x86_64 architecture

const std = @import("std");
const log = std.log.scoped(.platform);

pub const serial = @import("serial.zig");

// Some constants defined in the kernel linker script
extern const __stack_bottom: u8;
extern const __stack_top: u8;

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

/// Do essential work prior to initialising the rest of the OS
pub inline fn setup() void {
    // Setup the kernel's stack
    asm volatile ("mov %rsp, __stack_top");
}
