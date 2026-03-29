ASM     = riscv-none-elf-gcc
OBJCOPY = riscv-none-elf-objcopy
FLAGS   = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Ttext=0x00000000 

all: test.hex

test.elf: toolchain/test.s
	$(ASM) $(FLAGS) -o $@ $^

test.hex: test.elf
	$(OBJCOPY) -O verilog $< $@

clean:
	rm -f test.elf test.hex
