`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// Reference Model
// ============================================================
class riscv_ref_model;

  logic [31:0] regs[0:31];
  logic [31:0] pc;

  function new();
    foreach (regs[i]) regs[i] = 32'h0;
    pc = RESET_PC;
  endfunction

  function void execute(input logic [31:0] instr, input logic [31:0] current_pc);
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic [31:0] rs1_val, rs2_val;
    logic [31:0] result;
    logic [31:0] next_pc;
    logic        taken;

    opcode  = instr[6:0];
    rd      = instr[11:7];
    funct3  = instr[14:12];
    rs1     = instr[19:15];
    rs2     = instr[24:20];
    funct7  = instr[31:25];

    imm_i   = {{20{instr[31]}}, instr[31:20]};
    imm_s   = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    imm_b   = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    imm_u   = {instr[31:12], 12'h000};
    imm_j   = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    rs1_val = (rs1 == 5'b0) ? 32'h0 : regs[rs1];
    rs2_val = (rs2 == 5'b0) ? 32'h0 : regs[rs2];

    result  = 32'h0;
    next_pc = current_pc + 32'd4;
    taken   = 1'b0;

    case (opcode)
      7'b0110011: begin  // R-type
        case (funct3)
          3'b000: result = funct7[5] ? rs1_val - rs2_val : rs1_val + rs2_val;
          3'b001: result = rs1_val << rs2_val[4:0];
          3'b010: result = ($signed(rs1_val) < $signed(rs2_val)) ? 32'd1 : 32'd0;
          3'b011: result = (rs1_val < rs2_val) ? 32'd1 : 32'd0;
          3'b100: result = rs1_val ^ rs2_val;
          3'b101:
          result = funct7[5] ? 32'($signed(rs1_val) >>> rs2_val[4:0]) : rs1_val >> rs2_val[4:0];
          3'b110: result = rs1_val | rs2_val;
          3'b111: result = rs1_val & rs2_val;
          default: result = 32'h0;
        endcase
        if (rd != 5'b0) regs[rd] = result;
      end

      7'b0010011: begin  // I-type ALU
        case (funct3)
          3'b000: result = rs1_val + imm_i;
          3'b001: result = rs1_val << imm_i[4:0];
          3'b010: result = ($signed(rs1_val) < $signed(imm_i)) ? 32'd1 : 32'd0;
          3'b011: result = (rs1_val < imm_i) ? 32'd1 : 32'd0;
          3'b100: result = rs1_val ^ imm_i;
          3'b101: result = funct7[5] ? 32'($signed(rs1_val) >>> imm_i[4:0]) : rs1_val >> imm_i[4:0];
          3'b110: result = rs1_val | imm_i;
          3'b111: result = rs1_val & imm_i;
          default: result = 32'h0;
        endcase
        if (rd != 5'b0) regs[rd] = result;
      end

      7'b0000011: begin  // Load
        // PC advances sequentially — register write
        // is handled via sync_load after retirement
        next_pc = current_pc + 32'd4;
      end

      7'b0100011: begin  // Store
        next_pc = current_pc + 32'd4;
      end

      7'b1100011: begin  // Branch
        case (funct3)
          3'b000:  taken = (rs1_val == rs2_val);
          3'b001:  taken = (rs1_val != rs2_val);
          3'b100:  taken = ($signed(rs1_val) < $signed(rs2_val));
          3'b101:  taken = ($signed(rs1_val) >= $signed(rs2_val));
          3'b110:  taken = (rs1_val < rs2_val);
          3'b111:  taken = (rs1_val >= rs2_val);
          default: taken = 1'b0;
        endcase
        next_pc = taken ? (current_pc + imm_b) : (current_pc + 32'd4);
      end

      7'b1101111: begin  // JAL
        if (rd != 5'b0) regs[rd] = current_pc + 32'd4;
        next_pc = current_pc + imm_j;
      end

      7'b1100111: begin  // JALR
        if (rd != 5'b0) regs[rd] = current_pc + 32'd4;
        next_pc = (rs1_val + imm_i) & 32'hFFFF_FFFE;
      end

      7'b0110111: begin  // LUI
        result = imm_u;
        if (rd != 5'b0) regs[rd] = result;
      end

      7'b0010111: begin  // AUIPC
        result = current_pc + imm_u;
        if (rd != 5'b0) regs[rd] = result;
      end

      7'b1110011: begin  // SYSTEM 
        next_pc = TRAP_VECTOR;
      end

      default: ;
    endcase

    pc = next_pc;
  endfunction

  // Mirror DUT loaded value into reference model so
  // subsequent instructions that use the loaded register
  // compute correctly. PC update for loads is done here
  // since execute() is not called for load instructions.
  function void sync_load(input logic [4:0] rd, input logic [31:0] val,
                          input logic [31:0] current_pc);
    if (rd != 5'b0) regs[rd] = val;
    pc = current_pc + 32'd4;
  endfunction

endclass

// ============================================================
// Checker
// ============================================================
class integration_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check_reg(input logic [4:0] addr, input logic [31:0] actual,
                          input logic [31:0] expected, input logic [31:0] instr,
                          input logic [31:0] retired_pc);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] reg x%0d | instr=0x%08h pc=0x%08h | got=0x%08h expected=0x%08h", addr, instr,
             retired_pc, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_pc(input logic [31:0] actual, input logic [31:0] expected,
                         input logic [31:0] instr, input logic [31:0] retired_pc);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] PC | instr=0x%08h retired_pc=0x%08h | got=0x%08h expected=0x%08h", instr,
             retired_pc, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Integration Testbench Results");
    $display("  Tests run    : %0d", tests_run);
    $display("  Passed       : %0d", tests_passed);
    $display("  Failed       : %0d", tests_failed);
    if (tests_failed == 0) $display("  Status       : ALL TESTS PASSED");
    else $display("  Status       : FAILURES DETECTED");
    $display(
        "─────────────────────────────────────────");
  endfunction

endclass

// ============================================================
// Top-level Testbench
// ============================================================
module tb_top_refmodel;

  logic clk;
  logic rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  top dut (
      .clk  (clk),
      .rst_n(rst_n)
  );

  riscv_ref_model            ref_model;
  integration_checker        chk;

  // ── Retirement capture registers ──────────────────────
  // Latched at pc_write_en time — stable values for the
  // instruction that just retired
  logic               [31:0] retired_instr;
  logic               [31:0] retired_pc;
  logic               [ 4:0] retired_rd;
  logic                      retired_is_load;
  logic                      retired;

  always_ff @(posedge clk) begin
    retired <= 1'b0;
    if (!rst_n) begin
      retired         <= 1'b0;
      retired_instr   <= 32'h0;
      retired_pc      <= 32'h0;
      retired_rd      <= 5'h0;
      retired_is_load <= 1'b0;
    end else if (dut.pc_write_en) begin
      // Latch everything we need from the current cycle.
      // ir and pc are still stable here — they update
      // on the next clock edge when FSM moves to FETCH.
      retired_instr   <= dut.ir;
      retired_pc      <= dut.pc;
      retired_rd      <= dut.rd_addr;
      retired_is_load <= (dut.ir[6:0] == 7'b0000011);
      retired         <= 1'b1;
    end
  end

  // ── Retirement monitor ────────────────────────────────
  // Fires one cycle after pc_write_en. By now:
  //   - reg file write has committed (for reg-writing instrs)
  //   - dut.pc holds the next PC (post-retirement value)
  // We compare both against the reference model.
  always_ff @(posedge clk) begin
    if (retired) begin
      if (retired_is_load) begin
        // Reference model doesn't model memory.
        // Mirror DUT's committed load value and
        // advance PC sequentially.
        ref_model.sync_load(retired_rd, dut.reg_file.regs[retired_rd], retired_pc);
      end else begin
        ref_model.execute(retired_instr, retired_pc);
      end

      // ── Compare all 32 registers ──────────────────
      for (int unsigned i = 0; i < NUM_REGS; i++) begin
        chk.check_reg(5'(i), dut.reg_file.regs[i], ref_model.regs[i], retired_instr, retired_pc);
      end

      // ── Compare PC ────────────────────────────────
      // dut.pc is now the committed post-retirement PC
      chk.check_pc(dut.pc, ref_model.pc, retired_instr, retired_pc);
    end
  end

  // ── Reset and run ─────────────────────────────────────
  initial begin
    ref_model = new();
    chk       = new();

    rst_n     = 1'b0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    fork
      forever begin
        @(posedge clk);
        if (dut.is_trap && dut.control_unit.state == EXECUTE)
          $display("[TRAP] ecall detected at PC=0x%08h", dut.pc);
      end
      forever begin
        @(posedge clk);
        if (dut.pc_write_en) $display("[RETIRE] PC=0x%08h IR=0x%08h", dut.pc, dut.ir);
      end
    join_none

    // Run until infinite loop detected —
    // JAL x0, 0 causes PC to stop advancing
    begin
      logic [31:0] last_pc;
      int          stall_count;
      last_pc     = 32'hFFFF_FFFF;
      stall_count = 0;

      forever begin
        @(posedge clk);
        if (dut.pc === last_pc) begin
          stall_count++;
          if (stall_count > 10) begin
            $display("[INFO] Infinite loop at PC=0x%08h — done", dut.pc);
            chk.report();
            $finish;
          end
        end else begin
          stall_count = 0;
          last_pc     = dut.pc;
        end
      end
    end

    chk.report();
    $finish;
  end

endmodule
