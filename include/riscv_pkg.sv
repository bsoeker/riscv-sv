package riscv_pkg;

  // ALU Opcodes
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLL  = 4'b0101,  // Shift Left Logical
    ALU_SRL  = 4'b0110,  // Shift Right Logical
    ALU_SRA  = 4'b0111,  // Shift Right Arithmetic
    ALU_SLT  = 4'b1000,  // Set Less Than (Signed)
    ALU_SLTU = 4'b1001   // Set Less Than (Unsigned)
  } alu_op_e;

  // Memory addr widths
  parameter int unsigned ROM_DEPTH = 1024;  // word size, byte size = 4KB
  parameter int unsigned RAM_DEPTH = 65536;  // word size, byte size = 256KB
  parameter int unsigned ROM_ADDR_WIDTH = $clog2(ROM_DEPTH);
  parameter int unsigned RAM_ADDR_WIDTH = $clog2(RAM_DEPTH);

  // Regfile
  parameter int unsigned NUM_REGS = 32;

  // Immediate Generator
  typedef enum logic [2:0] {
    IMM_I = 3'b000,
    IMM_S = 3'b001,
    IMM_B = 3'b010,
    IMM_U = 3'b011,
    IMM_J = 3'b100
  } imm_type_e;

  // Address Decoder 
  parameter logic [31:0] ROM_BASE = 32'h0000_0000;
  parameter logic [31:0] RAM_BASE = 32'h1000_0000;

endpackage
