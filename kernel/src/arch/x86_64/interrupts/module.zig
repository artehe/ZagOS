//! Handles all of the interrupts for the kernel, whether they are enabled or disabled
//! as well as registering new ones.

const std = @import("std");
const log = std.log.scoped(.interrupts);

const idt = @import("idt.zig");

/// Disables interrupts from being generated.
pub inline fn disable() void {
    asm volatile ("cli");
}

/// Enables interrupts allowing them to be generated and processed by the IDT
pub inline fn enable() void {
    asm volatile ("sti");
}

/// Load the configured IDT
pub fn init() void {
    log.info("Loading Interrupts", .{});

    // We want to ensure interrupts are disabled while we configure this.
    disable();

    idt.init();

    // Just before returning from here we want to enable interrupts as they
    // should be safe to run now
    enable();

    log.info("Done", .{});
}
