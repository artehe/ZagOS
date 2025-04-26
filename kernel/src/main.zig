//! The entry point to the kernel and where the magic begins

const limine = @import("limine");
const std = @import("std");

/// Sets the base revision of the limine protocol which is supported by the kernel
pub export var base_revision: limine.BaseRevision linksection(".limine_requests") = .{
    .revision = 3,
};

fn hang() noreturn {
    asm volatile ("cli");
    while (true) {
        asm volatile ("hlt");
    }
}

/// Kernel's entry point.
export fn _start() callconv(.C) noreturn {
    // Do not proceed if the kernel's base revision is not supported by the bootloader.
    if (!base_revision.isSupported()) {
        hang();
    }

    // Loop forever.
    hang();
}
