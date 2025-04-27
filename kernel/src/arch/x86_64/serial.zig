//! Serial I/O for kernel mainly using UART (Universal Asynchronous Receiver-Transmitter) devices,
//! more info can be found here: https://wiki.osdev.org/Serial_Ports

const port = @import("port.zig");

/// The addresses for COM ports, Note: For the most part, the first two COM ports will be at the
/// addresses specified, the addresses for further COM ports are less reliable.
const ComPort = enum(u16) {
    COM1 = 0x3F8,
    COM2 = 0x2F8,
    COM3 = 0x3E8,
    COM4 = 0x2E8,
    COM5 = 0x5F8,
    COM6 = 0x4F8,
    COM7 = 0x5E8,
    COM8 = 0x4E8,
};

/// The First In / First Out Control Register (FCR) is for controlling the FIFO buffers
const FirstInFirstOutControlRegister = packed struct {
    /// Enable FIFO's
    enable: u1 = 0,
    /// Clear Receive FIFO buffer
    clear_receive_buffer: u1 = 0,
    /// Clear Transmit FIFO buffer
    clear_transmit_buffer: u1 = 0,
    /// DMA mode select
    dma_mode_select: u1 = 0,
    /// Reserved
    reserved: u2 = 0,
    /// Interrupt trigger level
    interrupt_trigger_level: u2 = 0,

    pub fn toByte(self: FirstInFirstOutControlRegister) u8 {
        return @bitCast(self);
    }
};

/// Allows for communicate with a serial port in interrupt mode
const InterruptEnableRegister = packed struct {
    /// Received data available
    received_data_avaiable: u1 = 0,
    /// Transmitter holding register empty
    transmitter_holding_register_empty: u1 = 0,
    /// Receiver line status
    receiver_line_status: u1 = 0,
    /// Modem status
    modem_status: u1 = 0,
    /// Reserved
    reserved: u4 = 0,

    pub fn toByte(self: InterruptEnableRegister) u8 {
        return @bitCast(self);
    }
};

/// Identifies the highest priority pending interrupt.
const InterruptIdentificationRegister = packed struct {
    interrupt_pending: u1,
    interrupt_identification: u3,
    fifo_enabled: u1,
    reserved: u3, // Reserved bits
};

/// The Line Control register sets the general connection parameters.
const LineControlRegister = packed struct {
    /// Data bits
    data: u2 = 0,
    /// Stop bit
    stop: u1 = 0,
    // Parity Enable
    parity_enable: u1 = 0,
    // Even Parity Select
    even_parity: u1 = 0,
    // Stick Parity
    stick_parity: u1 = 0,
    /// Break enable bit
    break_enable: u1 = 0,
    /// Divisor latch access bit (setting this allows for adjusting the baud rate)
    divisor_latch_access: u1 = 0,

    pub fn toByte(self: LineControlRegister) u8 {
        return @bitCast(self);
    }
};

/// The line status register is useful to check for errors and enable polling.
const LineStatusRegister = packed struct {
    /// Data ready (DR) - Set if there is data that can be read
    data_ready: bool = false,
    /// Overrun error (OE) - Set if there has been data lost
    overrun_error: bool = false,
    // Parity error (PE) - Set if there was an error in the transmission as detected by parity
    parity_error: bool = false,
    /// Framing error (FE) - Set if a stop bit was missing
    framing_error: bool = false,
    /// Break indicator (BI) - Set if there is a break in data input
    break_indicator: bool = false,
    /// Transmitter holding register empty (THRE) - Set if the transmission buffer is empty (i.e. data can be sent)
    transmitter_holding_register_empty: bool = false,
    /// Transmitter empty (TEMT) - Set if the transmitter is not doing anything
    transmitter_empty: bool = false,
    /// Set if there is an error with a word in the input buffer
    impending_error: bool = false,

    pub fn fromByte(byte: u8) LineStatusRegister {
        return @bitCast(byte);
    }

    pub fn hasError(self: LineStatusRegister) bool {
        return self.overrun_error == 1 or
            self.parity_error == 1 or
            self.framing_error == 1 or
            self.fifo_error == 1;
    }
};

/// The Modem Control Register is one half of the hardware handshaking registers.
/// While most serial devices no longer use hardware handshaking, the lines are still included in all 16550
/// compatible UARTS. These can be used as general purpose output ports, or to actually perform handshaking
const ModemControlRegister = packed struct {
    /// Controls the Data Terminal Ready Pin
    data_terminal_ready: u1 = 0,
    /// Controls the Request to Send Pin
    request_to_send: u1 = 0,
    /// Out 1 - Controls a hardware pin (OUT1) which is unused in PC implementations
    out1: u1 = 0,
    /// Out 2 - Controls a hardware pin (OUT2) which is used to enable the IRQ in PC implementations
    out2: u1 = 0,
    /// Loop - Provides a local loopback feature for diagnostic testing of the UART
    loop: u1 = 0,
    /// unused
    unused: u3 = 0,

    pub fn toByte(self: ModemControlRegister) u8 {
        return @bitCast(self);
    }
};

/// Provides modem signal status.
const ModemStatusRegister = packed struct {
    dcts: u1, // Delta Clear To Send
    ddcd: u1, // Delta Data Carrier Detect
    teri: u1, // Trailing Edge Ring Indicator
    ddsr: u1, // Delta Data Set Ready
    cts: u1, // Clear To Send
    dsr: u1, // Data Set Ready
    ri: u1, // Ring Indicator
    dcd: u1, // Data Carrier Detect
};

/// Provides a scratch space for storing user data.
const ScratchRegister = struct {
    data: u8,
};

/// A UART device that we can iteract with and send messages to and from.
const Uart = struct {
    /// The base port address of the UART device we want to use.
    base: u16,
    /// Has the interface been initialised already
    isInit: bool = false,

    /// Offsets for registers (based on standard 16550 layout).
    const RegisterOffset = enum(u8) {
        /// Data register
        DATA = 0,
        /// Interrupt control register
        ICR = 1,
        /// FIFO command register
        FCR = 2,
        /// Line control register
        LCR = 3,
        /// Modem control register
        MCR = 4,
        /// Line status register
        LSR = 5,
        /// Modem status register
        MSR = 6,
        /// Scratch register
        SR = 7,
    };

    /// Initializes our UART device.
    fn init(self: *Uart) void {
        // Disable all interrupts.
        const ier: InterruptEnableRegister = .{};
        self.writeRegister(.ICR, ier.toByte());

        // Set the DLAB bit in the Line Control Register so we can set the baud rate divisor.
        var lcr: LineControlRegister = .{
            .divisor_latch_access = 1,
            .stop = 1,
            .data = 0b11,
        };
        self.writeRegister(.LCR, lcr.toByte());
        // Send data to the dataPort to set the BAUD rate (the frequency that we want to communicate at).
        // This is calcualted by taking 115200 divided by the value we send to the data port in this case 8.
        self.writeByte(0x08);
        self.writeRegister(.ICR, 0x00);
        // Now the baud rate is set configure the Line Control Register (8 bits, no parity, one stop bit)
        lcr.divisor_latch_access = 0;
        self.writeRegister(.LCR, lcr.toByte());

        // Enable FIFO, clear them, wth 14-byte threshold before triggering a received data available interrupt
        const fcr: FirstInFirstOutControlRegister = .{
            .interrupt_trigger_level = 0b11,
            .reserved = 0,
            .dma_mode_select = 0,
            .clear_receive_buffer = 1,
            .clear_transmit_buffer = 1,
            .enable = 1,
        };
        self.writeRegister(.FCR, fcr.toByte());

        // Check if serial is faulty (i.e: not same byte as sent), first we set into loopback mode and send a single byte 0xAE
        var mcr: ModemControlRegister = .{
            .loop = 1,
            .out2 = 1,
            .out1 = 1,
            .request_to_send = 1,
            .data_terminal_ready = 1,
        };
        self.writeRegister(.MCR, mcr.toByte());
        self.writeByte(0xAE);
        if (self.readByte() != 0xAE) {
            // If we don't get the same byte back we know that there is a problem
            @panic("UART serial driver failed to initialise");
        }
        // The serial is not faulty so set it in normal operation mode
        // (not-loopback with IRQs enabled and OUT#1 and OUT#2 bits enabled)
        mcr.loop = 0;
        self.writeRegister(.MCR, mcr.toByte());

        // We made it here so the UART device should now be initialised.
        self.isInit = true;
    }

    /// Check if there's data available to read
    inline fn isReceiveBufferEmpty(self: Uart) bool {
        const lsr = LineStatusRegister.fromByte(self.readRegister(.LSR));
        return !lsr.data_ready;
    }

    /// Check whether the transmit buffer is empty or not.
    inline fn isTransmitBufferEmpty(self: Uart) bool {
        const lsr = LineStatusRegister.fromByte(self.readRegister(.LSR));
        return lsr.transmitter_holding_register_empty;
    }

    /// Read a register at an offset
    inline fn readRegister(self: Uart, offset: RegisterOffset) u8 {
        return port.inb(self.base + @intFromEnum(offset));
    }

    /// Write a value to the given register
    inline fn writeRegister(self: Uart, offset: RegisterOffset, value: u8) void {
        port.outb(self.base + @intFromEnum(offset), value);
    }

    // Receive one byte from the UART device (blocking)
    pub fn readByte(self: Uart) u8 {
        // Check the interface has been initialised
        if (!self.isInit) {
            init(@constCast(&self));
        }

        while (self.isReceiveBufferEmpty()) {}
        return self.readRegister(.DATA);
    }

    /// Output a single char to the UART device (blocking)
    pub fn writeByte(self: Uart, b: u8) void {
        // Check the interface has been initialised
        if (!self.isInit) {
            init(@constCast(&self));
        }

        // Wait until the transmit buffer is empty
        while (!self.isTransmitBufferEmpty()) {}
        // Then we just send the character to the data port.
        self.writeRegister(.DATA, b);
    }

    /// Output a string to the UART device
    pub fn writeString(self: Uart, str: []const u8) void {
        // We just iterate over the array
        for (str) |byte| {
            self.writeByte(byte);
        }
    }
};

pub const com1: Uart = .{ .base = @intFromEnum(ComPort.COM1) };
