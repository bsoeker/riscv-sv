# RV32I Multicycle CPU — SystemVerilog Implementation

A fully verified multicycle RISC-V RV32I processor implemented in SystemVerilog,
with a layered verification strategy comprising unit testbenches for every RTL
component and an integration testbench with a SystemVerilog reference model.

---

## Project Structure

```
include/
  riscv_pkg.sv          # Central package: parameters, enums, structs
rtl/
  top.sv                # Top-level integration
  control_unit.sv       # Two-layer FSM + combinational decoder
  alu.sv                # 10-operation arithmetic logic unit
  reg_file.sv           # 32x32 register file, x0 hardwired zero
  rom.sv                # Dual-port combinational instruction memory
  ram.sv                # Synchronous byte-granular data memory
  imm_gen.sv            # 5-format immediate decoder
  load_unit.sv          # Load sign/zero extension and byte selection
  store_unit.sv         # Store byte enable and data alignment
  addr_decoder.sv       # MMIO address space decoder
  pc.sv                 # Program counter with enable
  mux2.sv               # 2-input parameterized mux
  mux4.sv               # 4-input parameterized mux
  uart.sv               # UART TX/RX with CDC synchronizer (not integrated)
test/
  integration/
    tb_integration.sv   # Full CPU + SV reference model
  unit/
    tb_alu.sv           # Constrained random + functional coverage
    tb_control_unit.sv  # FSM state sequence + decoder verification
    tb_reg_file.sv      # Directed: x0, all 31 registers, write enable
    tb_imm_gen.sv       # Exhaustive directed: all 5 immediate formats
    tb_ram.sv           # Directed: byte lanes, read_complete timing
    tb_addr_decoder.sv  # Directed: boundary conditions per region
    tb_store_load.sv    # Combined round-trip: all variants and offsets
    tb_pc.sv            # Directed: reset, enable gating, mid-instr reset
    tb_uart.sv          # Directed: TX/RX, busy flag, noise rejection
    tb_mux2.sv          # Exhaustive: all select combinations
    tb_mux4.sv          # Exhaustive: all select combinations
    tb_top.sv           # Waveform-only smoke test
  toolchain/
    test.s              # RV32I comprehensive test program (assembly)
  Makefile              # Assemble, convert, deploy hex to xsim
```

---

## Dependencies

- **Vivado / xsim** — simulation and synthesis
- **riscv-none-elf-gcc** — RISC-V cross-compiler for assembling test programs
- **riscv-none-elf-objcopy** — ELF to Verilog hex conversion

---

## Vivado Project Setup

### 1. Add Design Sources

Add the following files as **Design Sources** in Vivado (in this order so the
package compiles first):

1. `include/riscv_pkg.sv`
2. All `.sv` files under `rtl/`

### 2. Add Simulation Sources

Add the testbench you want to run as a **Simulation Source**. Only one
testbench should be active as the simulation top module at a time.

To run a unit test:
- Add the relevant file from `test/unit/` (e.g. `tb_alu.sv`)
- Set it as the simulation top module in Vivado's simulation settings

To run the integration test:
- Add `test/integration/tb_integration.sv`
- Set it as the simulation top module

### 3. Build the Test Program (integration test only)

The integration testbench requires `rom.hex` to be present in the xsim working
directory. Build and deploy it by running `make` from the `test/` directory:

```bash
cd test/
make
```

**Before running make**, edit the `VIVADO_PROJECT` variable in `test/Makefile`
to point to your Vivado project directory:

```makefile
VIVADO_PROJECT = ../project_1   # change this to your project path
```

The Makefile will assemble `toolchain/test.s`, convert it to Verilog hex
format, and copy it to the xsim working directory automatically:

```
test/project_1/project_1.sim/sim_1/behav/xsim/rom.hex
```

### 4. Run Simulation

In the Vivado TCL console, run:

```tcl
run all
```

Do not set a fixed simulation time limit — the testbenches detect termination
conditions internally (`$finish` is called automatically).

**Note:** `$display` output appears in the TCL console, not the waveform
viewer. Check the console for pass/fail results.

---

## Memory Map

| Region | Base Address | Size | Description |
|--------|-------------|------|-------------|
| ROM    | `0x0000_0000` | 4KB | Instruction memory + `.rodata` |
| RAM    | `0x1000_0000` | 4KB | Data memory + stack |
| UART   | `0x2000_0000` | 12B | TX (`+0`), Status (`+4`), RX (`+8`) |

The UART peripheral is designed and unit tested but not connected in the
current top-level integration. To connect it, uncomment the UART signals in
`rtl/addr_decoder.sv` and instantiate the `uart` module in `rtl/top.sv`
following the same enable signal pattern used for RAM.

---

## Makefile Reference

Run from the `test/` directory:

```bash
make          # assemble test.s, convert to hex, deploy to xsim
make clean    # remove test.elf and test.hex
```

The hex conversion uses `--verilog-data-width 4` to produce 32-bit
word-addressed output compatible with `$readmemh`. Without this flag,
`objcopy` produces byte-addressed output that silently corrupts instruction
fetches — each word entry receives only the lowest byte of the instruction.

---

## Toolchain Flags

```makefile
FLAGS = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
        -ffreestanding -Ttext=0x00000000
```

| Flag | Purpose |
|------|---------|
| `-march=rv32i` | Target RV32I base ISA, no extensions |
| `-mabi=ilp32` | 32-bit integer ABI |
| `-nostdlib` | No standard library linkage |
| `-nostartfiles` | No CRT startup files |
| `-ffreestanding` | Freestanding environment, no OS assumptions |
| `-Ttext=0x00000000` | Place `.text` section at ROM base address |
