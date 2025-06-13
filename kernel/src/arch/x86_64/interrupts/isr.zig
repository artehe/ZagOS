//! Interrupt Service Routines (ISRs) save the current processor state and set up the appropriate
//! segment registers. Also loads in the relevent exception handler(s) into the IDT.

const std = @import("std");
const log = std.log.scoped(.isr);

const gdt = @import("../gdt.zig");
const idt = @import("idt.zig");
const interrupts = @import("module.zig");
const platform = @import("../platform.zig");

/// Interrupt Stack Frame which gets passed to the interrupt handler.
const InterruptStack = packed struct {
    // General purpose registers.
    r15: u64,
    r14: u64,
    r13: u64,
    r12: u64,
    r11: u64,
    r10: u64,
    r9: u64,
    r8: u64,
    rbp: u64,
    rdi: u64,
    rsi: u64,
    rdx: u64,
    rcx: u64,
    rbx: u64,
    rax: u64,

    // Interrupt vector number.
    interrupt_number: u64,
    // Associated error code, or 0.
    error_code: u64,

    // Registers pushed by the CPU automatically when an interrupt is fired.
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

/// The total number of CPU exceptions.
const NUMBER_OF_EXCEPTIONS = 32;
// The name for the CPU exceptions that can occurr
const EXCEPTION_MESSAGES = [NUMBER_OF_EXCEPTIONS][]const u8{
    "Divide By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Overflow",
    "Out of Bounds",
    "Invalid Opcode",
    "No Coprocessor",
    "Double Fault", // Has error code
    "Coprocessor Segment Overrun",
    "Bad TSS", // Has error code
    "Segment Not Present", // Has error code
    "Stack Fault", // Has error code
    "General Protection Fault", // Has error code
    "Page Fault", // Has error code
    "Unknown Interrupt",
    "Coprocessor Fault",
    "Alignment Check",
    "Machine Check",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
};

/// The common ISR stub that saves the processor state, sets up for kernel mode segments, calls
/// the assigned handler that all exceptions and interrupts use.
export fn commonStub() callconv(.Naked) void {
    asm volatile (
        \\push %%rax
        \\push %%rbx
        \\push %%rcx
        \\push %%rdx
        \\push %%rsi
        \\push %%rdi
        \\push %%rbp
        \\push %%r8
        \\push %%r9
        \\push %%r10
        \\push %%r11
        \\push %%r12
        \\push %%r13
        \\push %%r14
        \\push %%r15
        \\
        \\mov %%rax, %%rsp
        \\push %%rax
        \\
        \\mov %%ax, 0x10
        \\mov %%ds, %%ax
        \\mov %%es, %%ax
        \\mov %%fs, %%ax
        \\mov %%gs, %%ax
        \\
        \\mov %%rax, interruptsHandler
        \\call interruptsHandler
        \\
        \\pop %%rax
        \\pop %%r15
        \\pop %%r14
        \\pop %%r13
        \\pop %%r12
        \\pop %%r11
        \\pop %%r10
        \\pop %%r9
        \\pop %%r8
        \\pop %%rbp
        \\pop %%rdi
        \\pop %%rsi
        \\pop %%rdx
        \\pop %%rcx
        \\pop %%rbx
        \\pop %%rax
        \\
        \\add %%rsp, 8    
        \\iretq 
    );
}

fn getInterruptStub(comptime interrupt_number: u8) idt.InterruptHandler {
    return struct {
        fn func() callconv(.naked) void {
            interrupts.disable();

            switch (interrupt_number) {
                8, 10, 11, 12, 13, 14, 17, 30 => {
                    // Do nothing as these interrupts automatically put an error code on the stack
                },

                // These interrupts don't push an error code onto the stack, so we push a zero.
                else => {
                    asm volatile (
                        \\ pushq $0
                    );
                },
            }

            asm volatile (
                \\ pushq %[interrupt_number]
                \\ jmp commonStub
                :
                : [interrupt_number] "n" (interrupt_number),
            );
        }
    }.func;
}

/// The main handler for all exceptions and interrupts.
/// This will tell what exception has happened! Right now, simply halt the system
export fn interruptsHandler(context: *InterruptStack) usize {
    if (context.interrupt_number < 32) {
        log.info("Interrupt {s} {} fired", .{
            EXCEPTION_MESSAGES[context.interrupt_number],
            context.interrupt_number,
        });
    } else {
        log.info("Interrupt {} fired", .{
            context.interrupt_number,
        });
    }

    log.info("System Halted!", .{});
    platform.hang();
}

/// Sets and entry in the IDT for a given ISR.
fn setupIsr(index: u8, handler: idt.InterruptHandler) void {
    idt.setGate(
        index,
        gdt.DescriptorPrivilegeLevel.kernel,
        handler,
    ) catch |err| switch (err) {
        error.IdtEntryExists => {
            @panic("Error setting up ISR an IDT entry already exists");
        },
    };
}

/// Installs the Interrupt Service Routines into the IDT.
pub fn init() void {
    log.info("Loading ISRs", .{});

    // Load all the exceptions into the IDT.
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        setupIsr(i, getInterruptStub(i));
    }

    log.info("Done", .{});
}
