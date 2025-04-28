/* We want to be placed in the topmost 2GiB of the address space, for optimisations
   and because that is what the Limine spec mandates. Any address in this region will 
   do, but often 0xFFFFFFFF80000000 is chosen as that is the beginning of the region. */
KERNEL_START = 0xFFFFFFFF80000000;
/* How big the the stack should be 4KiB.  */
KERNEL_STACK_SIZE = 0x4000;

/* Tell the linker that we want an x86_64 ELF64 output file */
OUTPUT_FORMAT(elf64-x86-64)

/* The function that we want to enter the kernel at uses the POSIX default of "_start". */
ENTRY(_start)

/* Define the program headers we want so the bootloader gives us the right MMU permissions; this 
   also allows us to exert more control over the linking process. */
PHDRS {
    limine_requests PT_LOAD;
    text PT_LOAD;
    rodata PT_LOAD;
    data PT_LOAD;
}

/* All executables have so-called sections which are collections of types of data */
SECTIONS {
    /* Specify where to start the kernel from in memory */
    . = KERNEL_START;
    __kernel_start = .;

    /* Define a section to contain the Limine requests and assign it to its own PHDR */
    .limine_requests : {
        KEEP(*(.limine_requests_start))
        KEEP(*(.limine_requests))
        KEEP(*(.limine_requests_end))
    } :limine_requests

    /* Move to the next memory page for .text */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* The text section. which holds the code we will execute. */
    .text : {
        *(.text*)
    } :text

    /* Move to the next memory page for .rodata */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* Data that already has some value (often non-zero), but is read-only. */
    .rodata : {
        *(.rodata*)
    } :rodata

    /* Move to the next memory page for .data */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    /* Data that already has some value (often non-zero) and is readable and writable. */
    .data : {
        *(.data*)
    } :data

    /* Data that does not have any value (often zero) and is readable and writable.
       NOTE: .bss needs to be the last thing mapped to :data, otherwise lots of
       unnecessary zeros will be written to the binary. If you need, for example, 
       .init_array and .fini_array, those should be placed above this. */
    .bss : {
        *(.bss*)
        *(COMMON*)
    } :data

    /* Discard .note.* and .eh_frame* since they may cause issues on some hosts. */
    /DISCARD/ : {
        *(.eh_frame*)
        *(.note .note.*)
    }

    __kernel_end = .;
}
