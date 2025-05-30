//! A simple terminal interface to write to the screen from inside the kernel.
//! Primarily using a framebuffer we requested from the bootloader.

const std = @import("std");
const fmt = std.fmt;
const Writer = std.io.Writer;
const log = std.log.scoped(.terminal);

const font = @import("font.zig");
const framebuffer = @import("framebuffer.zig");
const Colour = framebuffer.Colour;

const active_font = font.BuildFont("Tamsyn7x14r.psf").init();

/// Current background color.
const background_colour: Colour = Colour.init(0x00, 0x00, 0x00);
/// Current foreground color.
const foreground_colour: Colour = Colour.init(0xFF, 0xFF, 0xFF);
/// Writer to format all of the strings and prepare to output them to the framebuffer
const writer = Writer(void, error{}, writerCallback){
    .context = {},
};

/// The current cursor position.
var cursor_position: framebuffer.Position = .{
    .x = 0,
    .y = 0,
};
/// Width of the screen in characters.
var screen_width: usize = undefined;
/// Height of the screen in characters.
var screen_height: usize = undefined;

/// Draws a font glyph at the given coordinates.
fn drawGlyph(character: u8, x: usize, y: usize, fg: Colour, bg: Colour) void {
    var position: framebuffer.Position = .{
        .x = x,
        .y = y,
    };

    var glyph_iterator = active_font.pixelIterator(character);
    while (glyph_iterator.next()) |is_pixel_set| {
        var colour = bg;
        if (is_pixel_set) {
            colour = fg;
        }

        framebuffer.writePixel(position, framebuffer.Pixel.init(colour));

        position.x += 1;
        if (position.x >= x + active_font.glyph_width) {
            position.x = x;
            position.y += 1;
        }
    }
}

/// Scroll's the screen up one line and resets the cursor's horizontal position
fn scrollUp() void {
    framebuffer.scrollUp(active_font.glyph_height, background_colour);
    cursor_position.x = 0;
}

/// Outputs the character to the framebuffer
fn writeCharacter(character: u8) void {
    switch (character) {
        // Newline.
        '\n' => {
            cursor_position.x = 0;
            cursor_position.y += 1;

            // If we've run out of space, scroll the screen.
            if (cursor_position.y >= screen_height) {
                scrollUp();
            }
        },

        // Carriage Return
        '\r' => {
            cursor_position.x = 0;
        },

        // Any other character.
        else => {
            // If we've run out of space, scroll the screen.
            if (cursor_position.y >= screen_height) {
                scrollUp();
            }

            const x: usize = (cursor_position.x % screen_width) * active_font.glyph_width;
            const y: usize = cursor_position.y * active_font.glyph_height;
            drawGlyph(character, x, y, foreground_colour, background_colour);

            // Update the position of the cursor now that we've written a character
            cursor_position.x += 1;
            if (cursor_position.x > screen_width) {
                cursor_position.x = 0;
                cursor_position.y += 1;
            }
        },
    }
}

/// The callback from the writer which formats the string that was passed to it
fn writerCallback(_: void, data: []const u8) error{}!usize {
    for (data) |byte| {
        writeCharacter(byte);
    }
    return data.len;
}

/// Writes to the screen's framebuffer according to the specified format string.
pub fn print(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}

pub fn printString(str: []const u8) void {
    for (str) |byte| {
        writeCharacter(byte);
    }
}

/// Initializes the terminal ready for use.
pub fn init() void {
    log.info("Loading terminal", .{});

    // Initialise the framebuffer and clear the screen.
    framebuffer.init();
    framebuffer.clear();

    // Calculate the screen dimensions.
    screen_width = framebuffer.width / active_font.glyph_width;
    screen_height = framebuffer.height / active_font.glyph_height;
    log.debug(
        "Screen dimentions for loaded font {}x{}",
        .{
            screen_width,
            screen_height,
        },
    );

    log.info("Done", .{});
}
