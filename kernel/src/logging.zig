//! Internal Kernel Logging System(s)

const std = @import("std");
const builtin = @import("builtin");
const fmt = std.fmt;
const Writer = std.io.Writer;
const log = std.log.scoped(.logging);

const arch = @import("arch/module.zig");
const terminal = @import("terminal/module.zig");

const writer = Writer(void, error{}, writerCallback){
    .context = {},
};

var terminal_enabled: bool = false;

fn writerCallback(_: void, data: []const u8) error{}!usize {
    switch (builtin.cpu.arch) {
        .x86_64 => arch.platform.serial.com1.writeString(data),
        else => @compileError("Architecture not currently supported!"),
    }

    if (terminal_enabled) {
        terminal.printString(data);
    }

    return data.len;
}

pub fn enableTerminal() void {
    terminal_enabled = true;
}

/// Global logging Function
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;
    writeFormattedString(prefix ++ format ++ "\r\n", args);
}

/// Global logging function for the test runner to use which won't get in the way
pub fn testLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
}

/// Prints out a formatted string, just like std.debug.print
pub fn writeFormattedString(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
