//! A simple terminal interface to write to the screen from inside the kernel.
//! Primarily using a framebuffer we requested from the bootloader.

const std = @import("std");
const log = std.log.scoped(.terminal);

const framebuffer = @import("framebuffer.zig");

/// Initializes the terminalr eady for use.
pub fn init() void {
    log.info("Loading terminal", .{});

    // Initialise the frame buffer and clear the screen.
    framebuffer.init();
    framebuffer.clear();

    const pixel = framebuffer.Pixel.init(0, 0, 255);
    for (0..100) |x| {
        for (0..100) |y| {
            const position: framebuffer.Position = .{
                .x = 20 + x,
                .y = 100 + y,
            };
            framebuffer.setPixel(position, pixel);
        }
    }

    log.info("Done", .{});
}
