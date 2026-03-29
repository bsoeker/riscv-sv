ASM     = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy
FLAGS   = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Ttext=0x00000000

VIVADO_PROJECT = ../project_1
XSIM_DIR       = $(VIVADO_PROJECT)/$(notdir $(VIVADO_PROJECT)).sim/sim_1/behav/xsim

all: test.hex
	cp test.hex $(XSIM_DIR)/rom.hex

test.elf: toolchain/test.s
	$(ASM) $(FLAGS) -o $@ $^

test.hex: test.elf
	$(OBJCOPY) -O verilog --verilog-data-width 4 $< $@

clean:
	rm -f test.elf test.hex
