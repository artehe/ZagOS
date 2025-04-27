//! Basic Port I/O to access to various ports for the kernel to read and write data to.
//! For example, a keyboard or serial port.

/// Returns the byte retrieved as an input to the specified port.
pub inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        // The return value should be an 8bit unsigned integer and saved in the register "al".
        : [ret] "={al}" (-> u8),
          // The port should be in the register "dx".
        : [port] "{dx}" (port),
          // Use the "dx" and "al" registers.
        : "dx", "al"
    );
}

/// Output a byte to the specified port.
pub inline fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        // No return value
        :
        // Two arguments
        : [val] "{al}" (val),
          [port] "{dx}" (port),
          // Use the "dx" and "al" registers.
        : "dx", "al"
    );
}
