import riscv_pkg::*;

module top (
    input logic clk,
    input logic rst_n
);

  // ── PC signals ───────────────────────────────────────────
  logic [31:0] pc;
  logic [31:0] next_pc;
  logic [31:0] pc_plus_four;
  logic [31:0] branch_target;
  logic [31:0] jalr_target;
  logic pc_write_en;
  logic branch_taken;

  // ── Instruction Register & Instruction fields ─────────────
  logic [31:0] ir;
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;

  // ── Register File ─────────────────────────────────────────
  logic [31:0] rs1_data, rs2_data, reg_write_data;

  // ── Immediate ─────────────────────────────────────────────
  logic [31:0] imm;

  // ── ALU ───────────────────────────────────────────────────
  logic [31:0] alu_input_a, alu_input_b, alu_result;
  logic zero_flag;

  // ── Memory & MMIO ────────────────────────────────────────────────
  logic [31:0] ram_read_data, rom_read_data, rom_instr_data, mem_read_data, mem_read_data_latched;
  logic [31:0] loaded_value, store_write_data;
  logic [ROM_ADDR_WIDTH+1:0] rom_addr;
  logic [RAM_ADDR_WIDTH+1:0] ram_addr;
  logic [3:0] store_write_mask;
  logic [1:0] byte_offset;
  logic ram_write_en, ram_read_en, ram_en, rom_en;
  logic ram_read_complete;

  // ── Control Signals ───────────────────────────────────────
  alu_op_e alu_control;
  alu_src_a_e alu_src_a;
  alu_src_b_e alu_src_b;
  imm_type_e imm_type;
  wb_sel_e wb_sel;
  logic reg_write_en, mem_read, mem_read_complete, mem_write;
  logic is_branch, is_jal, is_jalr, is_trap;
  logic ir_write_en;



  // ── PC computation  ────────────────────────────────────
  assign pc_plus_four = pc + 32'd4;
  assign branch_target = pc + imm;
  assign jalr_target = alu_result & 32'hFFFF_FFFE;
  assign branch_taken = is_branch && ((funct3 == 3'b000 && zero_flag) ||  // BEQ
      (funct3 == 3'b001 && !zero_flag) ||  // BNE
      (funct3 == 3'b100 && alu_result[0]) ||  // BLT
      (funct3 == 3'b101 && !alu_result[0]) ||  // BGE
      (funct3 == 3'b110 && alu_result[0]) ||  // BLTU
      (funct3 == 3'b111 && !alu_result[0])  // BGEU
      );
  assign next_pc = is_jalr ? jalr_target : 
                   is_jal ? alu_result :
                   is_trap ? TRAP_VECTOR :
                   branch_taken ? branch_target : 
                   pc_plus_four;

  // ── Program counter ────────────────────────────────────
  pc pc_inst (
      .clk   (clk),
      .rst_n (rst_n),
      .pc_write_en (pc_write_en),
      .pc_in (next_pc),
      .pc_out(pc)
  );

  // ── Instruction ROM ────────────────────────────────────
  rom rom (
      .instr_addr(pc[ROM_ADDR_WIDTH+1:0]),
      .instr_data(rom_instr_data),
      .data_addr (rom_addr),
      .data_data (rom_read_data)
  );

  // ── Instruction Register ────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) ir <= '0;
    else if (ir_write_en) ir <= rom_instr_data;
  end

  // ── Instruction field decode ───────────────────────────
  assign opcode = ir[6:0];
  assign rd_addr = ir[11:7];
  assign funct3 = ir[14:12];
  assign rs1_addr = ir[19:15];
  assign rs2_addr = ir[24:20];
  assign funct7 = ir[31:25];

  assign mem_read_complete = ram_read_complete;  // ram read is not combinational
  // ── Countrol Unit ────────────────────────────────────
  control_unit control_unit (
      .clk              (clk),
      .rst_n            (rst_n),
      .opcode           (opcode),
      .funct3           (funct3),
      .funct7           (funct7),
      .mem_read_complete(mem_read_complete),
      .ir_write_en      (ir_write_en),
      .pc_write_en      (pc_write_en),
      .reg_write_en     (reg_write_en),
      .mem_read         (mem_read),
      .mem_write        (mem_write),
      .alu_control      (alu_control),
      .alu_src_a        (alu_src_a),
      .alu_src_b        (alu_src_b),
      .wb_sel           (wb_sel),
      .imm_type         (imm_type),
      .is_branch        (is_branch),
      .is_jal           (is_jal),
      .is_trap          (is_trap),
      .is_jalr          (is_jalr)
  );

  // ── Register File ────────────────────────────────────
  reg_file reg_file (
      .clk         (clk),
      .rs1_addr    (rs1_addr),
      .rs2_addr    (rs2_addr),
      .rd_addr     (rd_addr),
      .rd_data     (reg_write_data),
      .reg_write_en(reg_write_en),
      .rs1_data    (rs1_data),
      .rs2_data    (rs2_data)
  );

  // ── Immediate Generator ────────────────────────────────────
  imm_gen imm_gen (
      .instr   (ir),
      .imm_type(imm_type),
      .imm_out (imm)
  );

  // ── ALU Input Muxes ────────────────────────────────────
  mux4 mux_alu_src_a (
      .a  (rs1_data),    // SRCA_RS1 = 2'b00
      .b  (pc),          // SRCA_PC  = 2'b01
      .c  (32'h0),       // SRCA_ZERO = 2'b10
      .d  (32'h0),       // unused 4th input
      .sel(alu_src_a),   // the enum drives the select
      .y  (alu_input_a)
  );

  mux2 mux_alu_src_b (
      .a  (rs2_data),    // SRCB_RS2 = 1'b0
      .b  (imm),         // SRCB_IMM = 1'b1
      .sel(alu_src_b),
      .y  (alu_input_b)
  );

  // ── ALU  ────────────────────────────────────
  alu alu (
      .op_a       (alu_input_a),
      .op_b       (alu_input_b),
      .alu_control(alu_control),
      .result     (alu_result),
      .zero_flag  (zero_flag)
  );

  // ── Address Decoder ────────────────────────────────────
  addr_decoder addr_decoder (
      .addr    (alu_result),
      .rom_en  (rom_en),
      .rom_addr(rom_addr),
      .ram_en  (ram_en),
      .ram_addr(ram_addr)
  );

  assign byte_offset = alu_result[1:0];
  // ── Store Unit ────────────────────────────────────
  store_unit store_unit (
      .funct3     (funct3),
      .addr_offset(byte_offset),
      .store_data (rs2_data),
      .write_mask (store_write_mask),
      .write_data (store_write_data)
  );

  assign ram_write_en = mem_write && ram_en;
  assign ram_read_en  = mem_read && ram_en;
  // ── RAM ────────────────────────────────────
  ram ram (
      .clk          (clk),
      .addr         (ram_addr),
      .write_en     (ram_write_en),
      .read_en      (ram_read_en),
      .write_data   (store_write_data),
      .write_mask   (store_write_mask),
      .read_data    (ram_read_data),
      .read_complete(ram_read_complete)
  );

  // ── Memory Read Register ────────────────────────────────────
  // in order to preserve the read value from the memory we need to latch it
  always_ff @(posedge clk) begin
    if (!rst_n) mem_read_data_latched <= '0;
    else if (mem_read_complete) mem_read_data_latched <= mem_read_data;
  end


  assign mem_read_data = mem_read && ram_en ? ram_read_data : 
                         mem_read && rom_en ? rom_read_data : 
                         '0;
  // ── Load Unit ────────────────────────────────────
  load_unit load_unit (
      .funct3      (funct3),
      .byte_offset (byte_offset),
      .mem_data    (mem_read_data_latched),
      .loaded_value(loaded_value)
  );


  // ── Writeback Mux ────────────────────────────────────
  mux4 writeback_mux (
      .a  (alu_result),
      .b  (loaded_value),
      .c  (pc_plus_four),
      .d  (32'h0000_0000),  // Unused
      .sel(wb_sel),
      .y  (reg_write_data)
  );

endmodule
