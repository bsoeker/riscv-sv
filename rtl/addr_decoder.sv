import riscv_pkg::*;

module addr_decoder #(
    parameter int ROM_AW = ROM_ADDR_WIDTH,
    parameter int RAM_AW = RAM_ADDR_WIDTH
) (
    input  logic [      31:0] addr,
    output logic              rom_en,
    output logic [ROM_AW+1:0] rom_addr,
    output logic              ram_en,
    output logic [RAM_AW+1:0] ram_addr
    // output logic              uart_en,
    // output logic [       1:0] uart_addr
);

  // ROM: 0x00000000 - 0x00000FFF for address width of 10
  assign rom_en = (addr >= ROM_BASE) && (addr < ROM_BASE + (ROM_DEPTH * 4)); // * 4 because byte addressable
  assign rom_addr = addr[ROM_AW+1:0];

  // RAM: 0x10000000 - 0x10000FFF for address width of 10
  assign ram_en   = (addr >= RAM_BASE) && (addr < RAM_BASE + (RAM_DEPTH * 4)); // * 4 because byte addressable
  assign ram_addr = addr[RAM_AW+1:0];

  // UART: 0x2000_0000 = UART_TX, 0x2000_0004 = UART Status Bits, 0x2000_0008 = UART_RX
  // assign uart_en = (addr >= UART_BASE) && (addr < UART_BASE + 12);
  // assign uart_addr = addr[3:2];



endmodule
