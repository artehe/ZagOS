//! Framebuffer initialization and direct operations.

const limine = @import("limine");
const FramebufferRequest = limine.FramebufferRequest;
const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.framebuffer);

/// Bits per pixel.
const BPP = 32;

/// Represents a pixel to be rendered to the screen using a 24 bit colour
/// depth (0xRRGGBB)
const Pixel = packed struct {
    red: u8,
    green: u8,
    blue: u8,
    reserved: u8,
};

/// The framebuffer request structure which is filled by the Limine bootloader.
export var framebuffer_request: FramebufferRequest linksection(".limine_requests") = .{};

/// Slice of the framebuffer memory.
var framebuffer: []volatile Pixel = undefined;
/// Height of the framebuffer in pixels.
var height: usize = undefined;
/// Width of the framebuffer in pixels.
var width: usize = undefined;

// Clear the framebuffer
fn clear() void {
    const blank_pixel: Pixel = .{
        .red = 0x00,
        .blue = 0x00,
        .green = 0x00,
        .reserved = 0x00,
    };
    @memset(framebuffer, blank_pixel);
}

/// Initialize the framebuffer, Note: This must be called before any other function
/// in the module.
pub fn init() void {
    log.info("Loading Framebuffer", .{});

    // Ensure that we have got a framebuffer generated for us
    if (framebuffer_request.response) |framebuffer_response| {
        const framebuffers = framebuffer_response.getFramebuffers();
        if (framebuffers.len < 1) {
            @panic("Expected to recieve at least 1 framebuffer, found 0");
        }

        // Ensure that the framebuffer uses 4 bytes per pixel.
        const selected_frambuffer = framebuffers[0];
        assert(selected_frambuffer.bpp == BPP);

        // Extract the dimentions we need.
        width = selected_frambuffer.width;
        height = selected_frambuffer.height;

        // Create the slice that will allow us to access the framebuffer memory safely
        const raw_framebuffer: [*]volatile Pixel = @ptrCast(@alignCast(selected_frambuffer.address));
        framebuffer = raw_framebuffer[0 .. width * height];
    } else {
        @panic("No framebuffer response found");
    }

    // Finally ensure that the screen is blanked before we finish
    clear();

    log.info("Done", .{});
}
