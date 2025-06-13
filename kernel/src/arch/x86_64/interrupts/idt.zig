//! IDT: Interrupt Descriptor Table

const std = @import("std");
const log = std.log.scoped(.idt);

const cpu = @import("../cpu.zig");
const gdt = @import("../gdt.zig");

/// The type of gate that a gate descriptor represents. Note: In long mode there are two valid
/// type values
const GateType = enum(u4) {
    /// Null gate
    null = 0x0,
    /// 64-bit Interrupt Gate
    interrupt = 0xE,
    /// 64-bit Trap Gate
    trap = 0xF,
};

/// IDT Gate Descriptor, defineing an entry in the IDT
const GateDescriptor = packed struct {
    /// Offset (bits 0 to 15).
    offset_low: u16,
    /// GDT code segment selector.
    segment_selector: gdt.SegmentSelector,
    /// Interrupt Stack Table offset.
    ist: u3,
    /// Always zero.
    reserved0: u5,
    /// Gate type.
    gate_type: GateType,
    /// Always zero.
    reserved1: u1,
    /// Privilege level.
    dpl: gdt.DescriptorPrivilegeLevel,
    /// Is the gate is active.
    present: u1,
    /// Offset (bits 16 to 63).
    offset_high: u48,
    /// Always zero.
    reserved2: u32,

    pub fn zero() GateDescriptor {
        return .{
            .offset_low = 0,
            .offset_high = 0,
            .segment_selector = gdt.SegmentSelector.null_segment,
            .ist = 0,
            .reserved0 = 0,
            .reserved1 = 0,
            .reserved2 = 0,
            .gate_type = GateType.null,
            .dpl = gdt.DescriptorPrivilegeLevel.kernel,
            .present = 0,
        };
    }
};

/// The error set for the IDT
pub const IdtError = error{
    /// A IDT entry already exists for the provided index.
    IdtEntryExists,
};

/// Interrupt Function Type
pub const InterruptHandler = fn () callconv(.Naked) void;

/// The size of the IDT in bytes (minus 1).
const IDT_SIZE: u16 = @sizeOf(GateDescriptor) * NUMBER_OF_ENTRIES - 1;
/// The number of entries in the IDT.
const NUMBER_OF_ENTRIES = 256;

/// The IDT
var idt: [NUMBER_OF_ENTRIES]GateDescriptor = undefined;
/// The special IDT pointer
var idt_register: cpu.SystemTableRegister = undefined;

/// Create an entry for the Interrupt Descriptor Table
fn createGateDescriptor(offset: u64, dpl: gdt.DescriptorPrivilegeLevel) GateDescriptor {
    return GateDescriptor{
        .offset_low = @truncate(offset),
        .offset_high = @truncate(offset >> 16),

        .dpl = dpl,
        .gate_type = GateType.interrupt,
        .ist = 0,
        .present = 1,
        .segment_selector = gdt.SegmentSelector.kernel_code,

        .reserved0 = 0,
        .reserved1 = 0,
        .reserved2 = 0,
    };
}

/// Check whether a IDT gate has an entry
pub fn isGateOpen(gate: GateDescriptor) bool {
    return gate.present == 1;
}

/// Loads a new Interrupt Descriptor Table into the cpu.
fn loadIdt() void {
    // Create and load the IDT pointer into the CPU
    idt_register = .{
        .base = @intFromPtr(&idt),
        .limit = IDT_SIZE,
    };
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&idt_register),
    );
}

/// Initializes the Interrupt Descriptor Table.
pub fn init() void {
    log.info("Loading IDT", .{});

    // Ensure the entire IDT is set to zero
    @memset(&idt, GateDescriptor.zero());

    // Load the IDT into the cpu
    loadIdt();

    log.info("Done", .{});
}

/// Sets an entry in the IDT
pub fn setGate(
    index: u8,
    dpl: gdt.DescriptorPrivilegeLevel,
    handler: InterruptHandler,
) IdtError!void {
    if (isGateOpen(idt[index])) {
        return IdtError.IdtEntryExists;
    }

    const descriptor = createGateDescriptor(
        @intFromPtr(&handler),
        dpl,
    );
    idt[index] = descriptor;
}
