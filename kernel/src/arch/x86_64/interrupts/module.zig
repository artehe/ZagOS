/// Disables interrupts from being generated.
pub inline fn disable() void {
    asm volatile ("cli");
}

/// Enables interrupts allowing them to be generated and processed by the IDT
pub inline fn enable() void {
    asm volatile ("sti");
}
