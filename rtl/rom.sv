import riscv_pkg::ROM_ADDR_WIDTH;

// Word sized, byte addressable memory
module rom #(
    parameter int ADDR_WIDTH = ROM_ADDR_WIDTH
) (
    input  logic [ADDR_WIDTH+1:0] instr_addr,  // Byte address (PC)
    output logic [          31:0] instr_data,  // Full 32-bit instruction
    input  logic [ADDR_WIDTH+1:0] data_addr,   // Byte address (ALU result)
    output logic [          31:0] data_data    // Full 32-bit data
);

  logic [31:0] rom_array[2**ADDR_WIDTH-1:0];

  initial begin
    rom_array = '{default: 32'h0000_0000};
    $readmemh("test.hex", rom_array);
  end

  assign instr_data = rom_array[instr_addr[ADDR_WIDTH+1:2]];
  assign data_data  = rom_array[data_addr[ADDR_WIDTH+1:2]];

endmodule
