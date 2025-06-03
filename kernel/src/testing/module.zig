const builtin = @import("builtin");

const arch = @import("../arch/module.zig");

pub const QemuExitCode = enum(u8) {
    success = 0x10,
    failed = 0x11,
    _,
};

pub fn exitQemu(exit_code: QemuExitCode) void {
    switch (builtin.cpu.arch) {
        .x86_64 => {
            const port = arch.platform.port;
            const exit_port = 0xF4;
            port.outb(exit_port, @intFromEnum(exit_code));
        },
        else => @compileError("Architecture not currently supported!"),
    }
}
