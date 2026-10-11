#![no_std]

//! Hackxpansion console driver for the `linux_soc` module.
//!
//! The module carries an Allwinner F1C100s running Linux (see `../linux/`)
//! plus an ATmega328P. The console (RP2354) talks to the Linux side over the
//! module connector UART pins at 115200 8N1:
//!
//! | console pin | module net | F1C100s side              |
//! | ----------- | ---------- | ------------------------- |
//! | GPIO5       | UART_TX    | UART0 TX (PE0), 0x01C25000 |
//! | GPIO6       | UART_RX    | UART0 RX (PE1)            |
//!
//! Module detection uses the two ID resistors in `pcb/linux_soc.kicad_sch`
//! (R1/R2, both `1k`), so this driver matches
//! `ModuleID { md0: R1K, md1: R1K }`. If the platform assigns a different
//! pair when the project is registered, update [`LinuxSocDriver::ID`].
//!
//! I2C (GPIO0/1), SPI (GPIO2-4), ADC (GPIO7/8) and GPIO9 are left untouched
//! so other drivers/apps (e.g. ATmega flashing or sensor apps) can use them.

use xpanse_api::{
    bus::{allocator::BusAllocator, uart::UartError},
    driver::{Driver, DriverError, DriverMeta},
    gpio_bank::{BankPins, GpioBank},
    metadata::{ModuleDetectResistor, ModuleID, ModuleSlot},
    registry::Registry,
};

use embedded_io_async::{Read, Write};

/// UART settings shared with the F1C100s side (`../linux/`).
pub const LINUX_SOC_BAUD: u32 = 115_200;

/// Console-side handle to the Linux SoC terminal.
///
/// Registered in the [`Registry`] so apps can lease it as `LinuxSocHandle`,
/// write commands and read `'\n'`-terminated replies from Linux
/// (`console=ttyS0,115200` in `../linux/boot.cmd`).
pub struct LinuxSocHandle {
    uart: xpanse_api::bus::uart::UartBusHandle,
}

impl LinuxSocHandle {
    /// Write the whole buffer, coping with partial writes.
    pub async fn write_all(&mut self, mut buf: &[u8]) -> Result<(), UartError> {
        while !buf.is_empty() {
            let n = self.uart.write(buf).await?;
            buf = &buf[n..];
        }
        Ok(())
    }

    /// Flush pending TX bytes.
    pub async fn flush(&mut self) -> Result<(), UartError> {
        self.uart.flush().await
    }

    /// Read up to `buf.len()` bytes (at least one).
    pub async fn read(&mut self, buf: &mut [u8]) -> Result<usize, UartError> {
        self.uart.read(buf).await
    }

    /// Read one `'\n'`-terminated line, returning the length stored in `buf`.
    ///
    /// The trailing `'\n'` (and a preceding `'\r'` when present) is kept in
    /// `buf` so callers can distinguish empty lines. Returns `Ok(0)` only
    /// when `buf` is empty.
    pub async fn read_line(&mut self, buf: &mut [u8]) -> Result<usize, UartError> {
        let mut len = 0;
        while len < buf.len() {
            let mut byte = [0u8; 1];
            let n = self.uart.read(&mut byte).await?;
            if n == 0 {
                continue;
            }
            buf[len] = byte[0];
            len += 1;
            if byte[0] == b'\n' {
                break;
            }
        }
        Ok(len)
    }

    /// Write `cmd` plus `'\n'` and flush.
    pub async fn write_line(&mut self, cmd: &[u8]) -> Result<(), UartError> {
        self.write_all(cmd).await?;
        self.write_all(b"\n").await?;
        self.flush().await
    }

    /// Send `cmd` and read a single reply line into `reply`.
    ///
    /// Returns the reply length. Callers needing multi-line output should
    /// loop on [`read_line`](Self::read_line) until their prompt returns.
    pub async fn exec(&mut self, cmd: &[u8], reply: &mut [u8]) -> Result<usize, UartError> {
        self.write_line(cmd).await?;
        self.read_line(reply).await
    }
}

/// Zero-sized driver type matched to the module by its ID resistors.
pub struct LinuxSocDriver;

impl DriverMeta for LinuxSocDriver {
    const ID: ModuleID = ModuleID {
        md0: ModuleDetectResistor::R1K,
        md1: ModuleDetectResistor::R1K,
    };
}

impl<G: BankPins> Driver<G> for LinuxSocDriver {
    async fn create(
        gpio_bank: GpioBank<G>,
        slot: ModuleSlot,
        registry: &mut Registry,
        bus_allocator: &mut BusAllocator,
    ) -> Result<(), DriverError> {
        // GPIO5 = UART_TX, GPIO6 = UART_RX (see pinout.md). PIO first, then
        // bit-bang fallback; no scarce hardware UART/DMA is consumed.
        let uart = bus_allocator
            .create_uart_no_hardware(gpio_bank.gpio5, gpio_bank.gpio6, LINUX_SOC_BAUD)
            .map_err(|_| DriverError::InitFailed)?;

        registry.register(slot, LinuxSocDriver::ID, LinuxSocHandle { uart });

        Ok(())
    }
}
