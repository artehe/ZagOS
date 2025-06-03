//! GDT: Global Descriptor Table

const std = @import("std");
const log = std.log.scoped(.gdt);

const cpu = @import("cpu.zig");
const interrupts = @import("interrupts.zig");
const platform = @import("platform.zig");

/// The CPU Privilege Level for the GDT segment's access, where 0 = highest privilege, and
/// 3 = lowest privilege.
const DescriptorPrivilegeLevel = enum(u2) {
    kernel = 0b00,
    user = 0b11,
};

/// The type for a GDT segment access.
const DescriptorType = enum(u1) {
    /// A system segment (e.g. a Task State Segment)
    system = 0,
    /// A code or data segment.
    data_code = 1,
};

/// Selectors for the GDT to grab different parts.
const SegmentSelector = enum(u16) {
    /// Null Segment Selector
    null_segment = 0x00,
    /// Kernel Code Selector
    kernel_code = 0x08,
    /// Kernel Data Selector
    kernel_data = 0x10,
    /// User Code Selector
    user_code = 0x18,
    /// User Data Selector
    user_data = 0x20,
    /// TSS Selector - lower half
    tss_lower = 0x28,
    /// TSS Selector - upper half
    tss_upper = 0x30,
};

/// The access byte for a GDT entry
const Access = packed struct {
    /// Accessed bit. The CPU will set this bit when the segment is accessed unless set to 1 in
    /// advance.
    accessed: u1,
    /// Readable/Writeable bit. For code segments: Readable bit. If clear, read access for this
    /// segment is not allowed. If set, read access is allowed. Write access is never allowed for
    /// code segments. For data segments: Writeable bit. If clear, write access for this segment is
    /// not allowed. If set, write access is allowed. Read access is always allowed for data
    /// segments.
    read_write: u1,
    /// Direction/Conformable bit. For data selectors: Direction bit. If clear, the segment grows
    /// up. If set, the segment grows down, i.e. the Offset has to be greater than the Limit. For
    /// code selectors: Conforming bit. If clear, code in this segment can only be executed from
    /// the ring set in DPL. If set, code in this segment can be executed from an equal or lower
    /// privilege level.
    direction_conforming: u1,
    /// Executable bit - If clear, the descriptor defines a data segment. If set, it defines a code
    /// segment which can be executed from.
    executable: u1,
    /// Descriptor bit type - 0 = System Segment, 1 = code or data segment
    type: DescriptorType,
    /// Descriptor privilege level.
    dpl: DescriptorPrivilegeLevel,
    /// Present bit. Allows an entry to refer to a valid segment. Must be set for any valid segment
    present: u1,

    /// Kernel code access: 0x9A -> 1001_1010
    const kernel_code = Access{
        .accessed = 0,
        .read_write = 1,
        .direction_conforming = 0,
        .executable = 1,
        .type = .data_code,
        .dpl = .kernel,
        .present = 1,
    };
    /// Kernel data access byte: 0x92 -> 1001_0010
    const kernel_data = Access{
        .accessed = 0,
        .read_write = 1,
        .direction_conforming = 0,
        .executable = 0,
        .type = .data_code,
        .dpl = .kernel,
        .present = 1,
    };
    /// Null Access where everything is set to zero.
    const zero: Access = Access{
        .accessed = 0,
        .read_write = 0,
        .direction_conforming = 0,
        .executable = 0,
        .type = .system,
        .dpl = .kernel,
        .present = 0,
    };
    /// Task State access byte: 0x89 -> 1000_1001
    const tss = Access{
        .accessed = 1,
        .read_write = 0,
        .direction_conforming = 0,
        .executable = 1,
        .type = .system,
        .dpl = .kernel,
        .present = 1,
    };
    /// User code access byte: 0xFA -> 1111_1010
    const user_code = Access{
        .accessed = 0,
        .read_write = 1,
        .direction_conforming = 0,
        .executable = 1,
        .type = .data_code,
        .dpl = .user,
        .present = 1,
    };
    // User data access byte: 0xF2 -> 1111_0010
    const user_data = Access{
        .accessed = 0,
        .read_write = 1,
        .direction_conforming = 0,
        .executable = 0,
        .type = .data_code,
        .dpl = .user,
        .present = 1,
    };
};

/// Flags for a GDT Entry
const Flags = packed struct {
    /// Reserved
    reserved: u1,
    /// Long-mode code flag. If set, the descriptor defines a 64-bit code segment. When set,
    /// DB should always be clear. For any other type of segment (other code types or any data
    /// segment), it should be clear.
    long: u1,
    /// DB: Size flag. If clear, the descriptor defines a 16-bit protected mode segment. If
    /// set it defines a 32-bit protected mode segment.
    db: u1,
    /// Granularity flag, indicates the size the limit value is scaled by. If clear, the Limit
    /// is in 1 Byte blocks (byte granularity). If set (1), the Limit is in 4 KiB blocks (page
    /// granularity).
    granularity: u1,

    /// The same flags are used for all code entries except for in the TSS : 0xA -> 1010
    const code = Flags{
        .reserved = 0,
        .long = 1,
        .db = 0,
        .granularity = 1,
    };
    /// The same flags are used for all data entries except for in the TSS : 0xC -> 1100
    const data = Flags{
        .reserved = 0,
        .long = 0,
        .db = 1,
        .granularity = 1,
    };
    /// Null flags with all bits set to zero.
    const zero: Flags = Flags{
        .reserved = 0,
        .long = 0,
        .db = 0,
        .granularity = 0,
    };
};

/// Defines an entry in the GDT table.
const SegmentDescriptor = packed struct {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,
};

/// The structure for a TSS entry
const Tss = packed struct {
    reserved0: u32,
    /// Stack pointer for ring 0.
    rsp0: u64,
    /// Stack pointer for ring 1.
    rsp1: u64,
    /// Stack pointer for ring 2.
    rsp2: u64,
    reserved1: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist1: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist2: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist3: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist4: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist5: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist6: u64,
    /// IST#: Interrupt Stack Table. Stack Pointers used to handle interrupts.
    ist7: u64,
    reserved2: u64,
    reserved3: u16,
    /// IOPB: I/O Map Base Address Field. Contains a 16-bit offset from the base of the TSS to the I/O Permission Bit Map.
    iopb: u16,
};

/// The size of the GTD in bytes (minus 1).
const GDT_SIZE: u16 = @sizeOf(SegmentDescriptor) * NUMBER_OF_ENTRIES - 1;
/// The total number of entries in the GDT
const NUMBER_OF_ENTRIES: u16 = 0x07;

/// The GDT, with it's required entries
var gdt: [NUMBER_OF_ENTRIES]SegmentDescriptor align(4096) = .{
    // The mandatory NULL descriptor
    createEntry(0x0, 0x0, Access.zero, Flags.zero),

    // The kernel mode code and data segments
    createEntry(0x0, 0xFFFFF, Access.kernel_code, Flags.code),
    createEntry(0x0, 0xFFFFF, Access.kernel_data, Flags.data),

    // The user mode code and data segments
    createEntry(0x0, 0xFFFFF, Access.user_code, Flags.code),
    createEntry(0x0, 0xFFFFF, Access.user_data, Flags.data),

    // The TSS split into lower and upper respectively, will be initialised during runtime
    createEntry(0x0, 0x0, Access.zero, Flags.zero),
    createEntry(0x0, 0x0, Access.zero, Flags.zero),
};
/// The special GDT pointer
var gdt_register: cpu.SystemTableRegister = undefined;
/// The 64 bit Task State Segment entry.
var tss: Tss = .{
    .iopb = 0,
    .ist1 = 0,
    .ist2 = 0,
    .ist3 = 0,
    .ist4 = 0,
    .ist5 = 0,
    .ist6 = 0,
    .ist7 = 0,
    .reserved0 = 0,
    .reserved1 = 0,
    .reserved2 = 0,
    .reserved3 = 0,
    .rsp0 = 0,
    .rsp1 = 0,
    .rsp2 = 0,
};

/// Create an entry for the Global Descriptor Table
fn createEntry(base: u32, limit: u32, access: Access, flags: Flags) SegmentDescriptor {
    return SegmentDescriptor{
        // Setup the descriptor base address
        .base_low = @truncate(base),
        .base_high = @truncate(base >> 24),

        // Setup the descriptor limits
        .limit_low = @truncate(limit),
        .limit_high = @truncate(limit >> 16),

        // Set up the access and flags
        .access = access,
        .flags = flags,
    };
}

/// Load the GDT into the CPU and refresh the code and data segments
fn loadGdt() void {
    // Create and load the GDT pointer into the CPU
    gdt_register = .{
        .base = @intFromPtr(&gdt),
        .limit = GDT_SIZE,
    };
    asm volatile ("lgdt (%[gdtr])"
        :
        : [gdtr] "r" (&gdt_register),
    );

    // Load the kernel code segment into the CS register
    asm volatile (
        \\push %[offset]
        \\push $reloadCs
        \\lretq
        \\reloadCs:
        :
        : [offset] "i" (SegmentSelector.kernel_code),
    );

    // Load the kernel data segment into the GDT to complete initialisation
    asm volatile (
        \\mov %[offset], %%ds
        \\mov %[offset], %%es
        \\mov %[offset], %%fs
        \\mov %[offset], %%gs
        \\mov %[offset], %%ss
        :
        : [offset] "rm" (SegmentSelector.kernel_data),
    );
}

/// Tell the CPU where the TSS is located in the GDT.
fn loadTss() void {
    asm volatile ("ltr %%ax"
        :
        : [offset] "{ax}" (SegmentSelector.tss_lower),
    );
}

/// Load the configured GDT along with the TSS and then flush the segment registers
pub fn init() void {
    log.info("Loading GDT", .{});

    // We want to ensure interrupts are disabled while we configure this.
    interrupts.disable();

    // Set kernel stack in the TSS which will be used when interrupting user mode
    // (Ring 3 -> 0)
    tss.rsp0 = @intFromPtr(&platform.__stack_top);

    // Initialise the TSS
    gdt[@intFromEnum(SegmentSelector.tss_lower) / 8] = createEntry(
        @truncate(@intFromPtr(&tss)),
        @sizeOf(Tss) - 1,
        Access.tss,
        Flags.zero,
    );
    gdt[@intFromEnum(SegmentSelector.tss_upper) / 8] = createEntry(
        @truncate(@intFromPtr(&tss) >> 32),
        @truncate(@intFromPtr(&tss) >> 32),
        Access.zero,
        Flags.zero,
    );

    // Load the GDT and TSS into the CPU
    loadGdt();
    loadTss();

    log.info("Done", .{});
}
