/// Disables interrupts from being generated.
pub inline fn disable() void {
    asm volatile ("cli");
}
