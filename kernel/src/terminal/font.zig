//! Import and handle the Tamsyn PSF font for the terminal to use to render text.

const std = @import("std");
const Endian = std.builtin.Endian;
const log = std.log.scoped(.font);

/// Options for the common PSF struct generator
const PsfHeaderMetrics = struct {
    file: []const u8,
    has_unicode_table: bool,
    header_size: u32,
    glyph_count: u32,
    glyph_size: u32,
    glyph_width: u32,
    glyph_height: u32,
};

const PSF1_MAGIC: [2]u8 = .{ 0x36, 0x04 };
const PSF2_MAGIC: [4]u8 = .{ 0x72, 0xb5, 0x4a, 0x86 };

const PSF1_MODE_HAS512 = 0x01;
const PSF1_MODE_HASTAB = 0x02;
const PSF1_MODE_HASSEQ = 0x04;

// Given font metrics, generate a struct type which can read font glyphs at compile time
fn BuildPsfCommon(comptime options: PsfHeaderMetrics) type {
    return struct {
        const Self = @This();
        const PixelIterator = PsfPixelIterator(Self);

        // Explicitly sized per the header file
        pub const Glyph = [options.glyph_size]u8;
        pub const GlyphSet = [options.glyph_count]Glyph;

        glyphs: GlyphSet,
        glyph_count: u32,
        glyph_height: u32,
        glyph_size: u32,
        glyph_width: u32,

        pub fn init() Self {
            // Get a stream over the embedded file and skip the header
            var glyphStream = std.io.fixedBufferStream(options.file);
            glyphStream.seekTo(options.header_size) catch unreachable;

            comptime var index = 0;
            var data: GlyphSet = undefined;

            // Then read every glyph out of the file into the struct
            // without the eval branch quota, compiler freaks out in read for backtracking
            @setEvalBranchQuota(100000);
            inline while (index < options.glyph_count) : (index += 1) {
                _ = glyphStream.read(data[index][0..]) catch unreachable;
            }

            return Self{
                .glyphs = data,
                .glyph_count = options.glyph_count,
                .glyph_width = options.glyph_width,
                .glyph_height = options.glyph_height,
                .glyph_size = options.glyph_size,
            };
        }

        pub fn pixelIterator(self: *const Self, glyph: u32) PixelIterator {
            var iter = PixelIterator{
                .font = self,
                .glyph = glyph,
            };
            iter.reset();
            return iter;
        }
    };
}

/// Return a PSF1 font struct,
fn BuildPsf1Font(comptime file: []const u8) type {
    var stream = std.io.fixedBufferStream(file);
    var reader = stream.reader();

    // magic (already validated)
    _ = try reader.readIntLittle(u16);
    // version
    const font_mode = try reader.readIntLittle(u8);
    const glyph_height = try reader.readIntLittle(u8);
    const glyph_count = if (font_mode & PSF1_MODE_HAS512 == 1) 512 else 256;

    return BuildPsfCommon(.{
        .file = file,
        .has_unicode_table = false,
        // bytes
        .header_size = 4,
        // always 256, unless 512 mode
        .glyph_count = glyph_count,
        // because each row is always 1 byte, so it takes height bytes for a glyph
        .glyph_size = glyph_height,
        .glyph_width = 8,
        .glyph_height = glyph_height,
    });
}

/// return a PSF2 font struct,
fn BuildPsf2Font(comptime file: []const u8) type {
    var stream = std.io.fixedBufferStream(file);
    var reader = stream.reader();

    // Magic (already validated)
    _ = try reader.readInt(u32, Endian.little);
    // Version
    _ = try reader.readInt(u32, Endian.little);
    const header_size = try reader.readInt(u32, Endian.little);

    // Flags (1 if unicode table)
    const flags = try reader.readInt(u32, Endian.little);

    const glyph_count = try reader.readInt(u32, Endian.little);
    const glyph_size = try reader.readInt(u32, Endian.little);
    const glyph_height = try reader.readInt(u32, Endian.little);
    const glyph_width = try reader.readInt(u32, Endian.little);

    return BuildPsfCommon(.{
        .file = file,
        .has_unicode_table = flags == 1,
        .header_size = header_size,
        .glyph_count = glyph_count,
        .glyph_height = glyph_height,
        .glyph_size = glyph_size,
        .glyph_width = glyph_width,
    });
}

/// Build an iterator that can walk over the pixel data in a given PSF font
/// iterates over single bits, aligning forward a bite when hitting the glyph
/// width.
///
/// user assumes responsibility for coordinating iteration in x/y coordinates,
/// at the row pitch level, no signal for "end of row" is provided.
fn PsfPixelIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        font: *const T,
        glyph: u32,

        // The current index into the glyph byte array
        index: usize = 0,
        // The number of bits we've read out of the working glyph
        bitcount: u8 = 0,
        // The byte we're currently destructing to get bits
        workglyph: u8 = undefined,

        /// Aligns to the next byte
        pub fn alignForward(self: *Self) void {
            if (self.bitcount > 0) {
                self.resetIndex(self.index + 1);
            }
        }

        /// Returns whether the next pixel is set or not,
        /// or null if we've read all pixels for the glyph
        pub fn next(self: *Self) ?bool {
            if (self.index >= self.font.glyph_size) {
                return null;
            }

            defer {
                self.bitcount += 1;
                if (self.bitcount >= self.font.glyph_width) {
                    const byte_width = (self.font.glyph_width + 7) / 8;
                    self.resetIndex(self.index + byte_width);
                }
            }

            const shift_with_overflow = @shlWithOverflow(self.workglyph, 1);
            self.workglyph = shift_with_overflow[0];
            return @bitCast(shift_with_overflow[1]);
        }

        /// Resets the iterator to the initial state.
        pub fn reset(self: *Self) void {
            self.resetIndex(0);
        }

        // Reset to the given index
        // used for full resets and byte-to-byte transitions
        fn resetIndex(self: *Self, index: usize) void {
            self.index = index;
            self.bitcount = 0;

            // If we're about to roll out of the glyph, don't
            // otherwise, the last iteration (which would return null) panics for out-of-bounds
            if (index < self.font.glyph_size) {
                self.workglyph = self.font.glyphs[self.glyph][index];
            }
        }
    };
}

/// Build a font struct from the given file, this will cause a compile error if the file is not
/// parsable as PSF v1 or v2
pub fn BuildFont(comptime path: []const u8) type {
    const file = @embedFile(path);

    if (std.mem.eql(u8, file[0..2], PSF1_MAGIC[0..2])) {
        return BuildPsf1Font(file);
    }

    if (std.mem.eql(u8, file[0..4], PSF2_MAGIC[0..4])) {
        return BuildPsf2Font(file);
    }

    @compileError("file isn't PSF (no matching magic)");
}
