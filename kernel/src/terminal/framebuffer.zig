//! Framebuffer initialization and direct operations.

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.framebuffer);

const limine = @import("../limine.zig");

pub const Colour = packed struct {
    blue: u8,
    green: u8,
    red: u8,

    pub fn init(red: u8, green: u8, blue: u8) Colour {
        return .{
            .red = red,
            .green = green,
            .blue = blue,
        };
    }
};

/// The position within the framebuffer.
pub const Position = struct {
    x: usize,
    y: usize,
};

/// Represents a pixel to be inserted into the frame buffer using and RGB based colour mode
pub const Pixel = packed struct {
    color: Colour,
    padding: u8 = 0,

    pub fn init(color: Colour) Pixel {
        return .{
            .color = color,
        };
    }
};

/// Bits per pixel.
const bits_per_pixel = 32;

/// Slice of the framebuffer memory.
var framebuffer: []volatile Pixel = undefined;
/// The line length + padding at the end of the line. Note: this variable can also known as stride
/// in some documentation
var pitch: usize = undefined;
/// The size of the framebuffer in bytes
var size: usize = undefined;

/// Height of the framebuffer in pixels.
pub var height: usize = undefined;
/// Width of the framebuffer in pixels.
pub var width: usize = undefined;

// Clear the framebuffer
pub fn clear() void {
    const blank_pixel = Pixel.init(Colour.init(0x00, 0x00, 0x00));
    @memset(framebuffer, blank_pixel);
}

/// Scrolls the screen up one line of characters
pub fn scrollUp(line_height: usize, colour: Colour) void {
    const screen = height * width;
    const line = line_height * width;

    // Copy the entire screen one line up.
    for (0..size) |i| {
        framebuffer[i] = framebuffer[i + line];
    }

    // Clear the last line.
    @memset(framebuffer[screen - line .. screen], Pixel.init(colour));
}

/// Sets a pixel in the framebuffer at the provided position
pub fn writePixel(position: Position, pixel: Pixel) void {
    // Use pitch to calculate the pixel offset of target line
    const line_offset = position.y * pitch;
    // Add x position to get the absolute pixel offset in buffer
    const pixel_offset = line_offset + position.x;

    framebuffer[pixel_offset] = pixel;
}

/// Initialize the framebuffer ready for use
pub fn init() void {
    log.info("Loading Framebuffer", .{});

    // Ensure that we have got a framebuffer generated for us
    if (limine.framebuffer_request.response) |framebuffer_response| {
        // Get the framebuffer we will use
        const framebuffers = framebuffer_response.getFramebuffers();
        const selected_frambuffer = framebuffers[0];

        // Extract the dimentions we need.
        height = selected_frambuffer.height;
        width = selected_frambuffer.width;

        // Calculate the actual pitch based on the bytes per pixel
        pitch = selected_frambuffer.pitch / (bits_per_pixel / 8);

        // Calculate the total size of the framebuffer
        size = width * height;
        log.debug("size: {}, width {}, height {}, pitch {}", .{ size, width, height, pitch });

        // Create the slice that will allow us to access the framebuffer memory safely
        const raw_framebuffer: [*]volatile Pixel = @ptrCast(@alignCast(selected_frambuffer.address));
        framebuffer = raw_framebuffer[0..size];
    } else {
        @panic("No framebuffer response found");
    }

    log.info("Done", .{});
}
