package riscv_pkg;

  // ── Memory layout ──────────────────────────────────────────
  parameter int ROM_DEPTH = 1024;
  parameter int RAM_DEPTH = 1024;
  parameter int ROM_ADDR_WIDTH = $clog2(ROM_DEPTH);
  parameter int RAM_ADDR_WIDTH = $clog2(RAM_DEPTH);
  parameter logic [31:0] ROM_BASE = 32'h0000_0000;
  parameter logic [31:0] RAM_BASE = 32'h1000_0000;
  parameter logic [31:0] UART_BASE = 32'h2000_0000;

  // ── CPU constants ──────────────────────────────────────────
  parameter int XLEN = 32;
  parameter int NUM_REGS = 32;
  parameter logic [31:0] RESET_PC = 32'h0000_0000;
  parameter logic [31:0] TRAP_VECTOR = 32'h0000_01b0;  // trap_handler address

  // ── ALU opcodes ────────────────────────────────────────────
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLL  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_SLT  = 4'b1000,
    ALU_SLTU = 4'b1001
  } alu_op_e;

  // ── Immediate types ────────────────────────────────────────
  typedef enum logic [2:0] {
    IMM_I = 3'b000,
    IMM_S = 3'b001,
    IMM_B = 3'b010,
    IMM_U = 3'b011,
    IMM_J = 3'b100
  } imm_type_e;

  // ── Writeback select ───────────────────────────────────────
  typedef enum logic [1:0] {
    WB_ALU = 2'b00,  // ALU result
    WB_MEM = 2'b01,  // memory load
    WB_PC4 = 2'b10   // PC+4 for JAL/JALR
  } wb_sel_e;

  // ── ALU source A select ────────────────────────────────────
  typedef enum logic [1:0] {
    SRCA_RS1  = 2'b00,  // register rs1
    SRCA_PC   = 2'b01,  // program counter
    SRCA_ZERO = 2'b10   // zero (for LUI)
  } alu_src_a_e;

  // ── ALU source B select ────────────────────────────────────
  typedef enum logic {
    SRCB_RS2 = 1'b0,  // register rs2,
    SRCB_IMM = 1'b1   // imm_out
  } alu_src_b_e;

  // ── Control Unit FSM states ─────────────────────────────────────────────
  typedef enum logic [2:0] {
    FETCH       = 3'b000,
    DECODE      = 3'b001,
    EXECUTE     = 3'b010,
    MEMORY      = 3'b011,
    MEMORY_WAIT = 3'b100,
    WRITEBACK   = 3'b101,
    TRAP        = 3'b110
  } state_e;

  // ── Control Unit decoded signals ─────────────────────────────────────────────
  typedef struct packed {
    alu_op_e    alu_control;
    alu_src_a_e alu_src_a;
    alu_src_b_e alu_src_b;
    logic       reg_write_en;
    logic       is_load;
    logic       is_store;
    logic       is_branch;
    logic       is_jal;
    logic       is_jalr;
    logic       is_trap;
    wb_sel_e    wb_sel;
    imm_type_e  imm_type;
  } decoded_t;

endpackage
