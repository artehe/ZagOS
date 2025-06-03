/// Structure for the IDT and GDT registers.
pub const SystemTableRegister = packed struct {
    limit: u16,
    base: u64,
};
