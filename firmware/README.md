# linux_soc console driver (`firmware/`)

Rust driver for the `linux_soc` Hackxpansion module, following the
[official driver guide](https://github.com/hackclub/hackxpansion) and the
[`xpanse-api` docs](https://docs.rs/xpanse-api/latest/xpanse_api/)
(`Driver` / `DriverMeta` / `GpioBank` / `Registry` / `BusAllocator`).

It is **console-side** code: it runs on the Hackxpansion console's RP2354
(`thumbv8m.main-none-eabihf`, Embassy), not on the F1C100s. The F1C100s side
(Linux with the terminal on UART0) lives in `../linux/`.

## What it does

- Matches the module by its ID resistors (`pcb/linux_soc.kicad_sch` R1/R2,
  both `1k`): `ModuleID { md0: R1K, md1: R1K }`.
- Opens the Linux terminal UART (console GPIO5 TX / GPIO6 RX, 115200 8N1)
  with `BusAllocator::create_uart_no_hardware` (PIO, bit-bang fallback —
  no hardware UART/DMA consumed).
- Registers one `LinuxSocHandle` (wrapping `UartBusHandle`) in the registry
  so apps can `take_resource::<LinuxSocHandle>()` and talk to Linux
  (`console=ttyS0,115200`, see `../linux/boot.cmd`).
- Leaves I2C (GPIO0/1), SPI (GPIO2-4), ADC (GPIO7/8) and GPIO9 free.

`LinuxSocHandle` helpers: `write_all`, `flush`, `read`, `read_line`
(`'\n'`-terminated), `write_line`, `exec` (command + single reply line).

## Prerequisites

- Rust via [rustup](https://rust-lang.org/learn/get-started/)
- RP2354 target: `rustup target add thumbv8m.main-none-eabihf`

## Checks

From this folder (the target is the default, configured in
`.cargo/config.toml`, with the toolchain in `rust-toolchain.toml`):

```bash
cargo build
```

Explicit form, identical result:

```bash
cargo check --target thumbv8m.main-none-eabihf
cargo build --target thumbv8m.main-none-eabihf
```

## Wiring reference

From the [connector pinout](https://github.com/hackclub/hackxpansion)
(`GpioBank`: GPIO0/I2C_SCL, GPIO1/I2C_SDA, GPIO2/SPI_SCK, GPIO3/SPI_MISO,
GPIO4/SPI_MOSI, GPIO5/UART_TX, GPIO6/UART_RX, GPIO7-8/ADC, GPIO9) and
`pcb/linux_soc.kicad_sch` (`UART_TX`/`UART_RX` nets from J1 P10/P11 to the
F1C100s UART0 on PE0/PE1):

| console | module | F1C100s                    |
| ------- | ------ | -------------------------- |
| GPIO5   | UART_TX| UART0 TX (PE0, 0x01C25000) |
| GPIO6   | UART_RX| UART0 RX (PE1)             |

## Adding it to the console firmware

1. Fork/clone [hackxpansion](https://github.com/hackclub/hackxpansion).
2. In `firmware/Cargo.toml` under `# Drivers`, add a local path while testing:
   `linux-soc-driver = { path = "../../linux_soc/firmware" }`.
3. In `firmware/xpanse/Cargo.toml`, add `linux-soc-driver = { workspace = true }`.
4. In `firmware/xpanse/src/load_driver.rs`, add a match arm:
   ```rust
   Some(id) if id == linux_soc_driver::LinuxSocDriver::ID => {
       match linux_soc_driver::LinuxSocDriver::create(bank, slot, registry, bus).await {
           Ok(()) => defmt::info!("linux_soc driver initialized in {:?}", slot),
           Err(error) => defmt::error!("linux_soc driver init failed in {:?}: {:?}", slot, error),
       }
   }
   ```
   (crate `linux-soc-driver` is imported as `linux_soc_driver`.)
5. `cargo build` from the `firmware/` folder there, fix errors, then publish
   to [crates.io](https://crates.io) and switch the dependency to the version
   number before opening a PR (see the First Driver guide's steps 7-13).

## Resistor note

R1/R2 are both `1k` in the current schematic, hence `R1K`/`R1K`. No in-tree
or published driver found uses that pair, but the platform assigns pairs when
a project is created — if it assigns a different pair, update `ID` (and the
two resistors) to match.
