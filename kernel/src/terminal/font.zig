//! Import and handle the Tamsyn font for the terminal to use to render text.

const std = @import("std");
const log = std.log.scoped(.font);

const Psf1Header = packed struct {
    /// Magic bytes for identification.
    magic: u16,
    /// PSF font mode.
    font_mode: u8,
    /// PSF character size.
    character_size: u8,
};

const Psf2Header = packed struct {
    /// Magic bytes to identify PSF
    magic: u32,
    /// zero
    version: u32,
    /// offset of bitmaps in file, 32
    header_size: u32,
    /// 0 if there's no unicode table
    flags: u32,
    /// number of glyphs
    glyps_count: u32,
    /// size of each glyph
    bytes_per_glyph: u32,
    /// height in pixels
    height: u32,
    /// width in pixels
    width: u32,

    pub fn isValid(self: Psf2Header) bool {
        return self.magic == PSF2_FONT_MAGIC;
    }
};

const PSF1_FONT_MAGIC: u16 = 0x0436;
const PSF2_FONT_MAGIC: u32 = 0x864ab572;

const RAW_FONT = @embedFile("Tamsyn7x14r.psf");

/// Initializes the font so that the terminal can use it to write characters to the framebuffer
pub fn init() void {
    log.info("Loading font", .{});

    // Create the slice that will allow us to access the framebuffer memory safely
    const raw_font_header: [*]volatile Psf2Header = @ptrCast(@alignCast(@constCast(RAW_FONT)));
    const font_header: Psf2Header = raw_font_header[0];
    if (!font_header.isValid()) {
        @panic("Invalid font header found");
    }
    log.debug("font header {}", .{font_header});

    log.info("Done", .{});
}
