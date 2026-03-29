`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// Immediate Generator Checker
// ============================================================
class immgen_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check(input logic [31:0] instr, input imm_type_e imm_type,
                      input logic [31:0] actual, input logic [31:0] expected);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | instr=0x%08h | got=0x%08h expected=0x%08h", imm_type.name(), instr,
             actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Immediate Generator Testbench Results");
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
module tb_imm_gen;

  logic [31:0] instr;
  imm_type_e imm_type;
  logic [31:0] imm_out;

  imm_gen dut (
      .instr   (instr),
      .imm_type(imm_type),
      .imm_out (imm_out)
  );

  immgen_checker chk;

  task automatic apply(input logic [31:0] i, input imm_type_e t, input logic [31:0] expected);
    instr    = i;
    imm_type = t;
    #1;
    chk.check(i, t, imm_out, expected);
  endtask

  initial begin
    chk = new();

    // ── I-type ───────────────────────────────────────────
    // instr[31:20] = imm[11:0], sign extended to 32 bits
    //
    // ADDI x1, x0, 1  — imm = 0x001 → 0x00000001
    apply(32'b000000000001_00000_000_00001_0010011, IMM_I, 32'h0000_0001);
    // ADDI x1, x0, -1 — imm = 0xFFF → 0xFFFFFFFF
    apply(32'b111111111111_00000_000_00001_0010011, IMM_I, 32'hFFFF_FFFF);
    // imm = 0x7FF — max positive I-type immediate
    apply(32'b011111111111_00000_000_00001_0010011, IMM_I, 32'h0000_07FF);
    // imm = 0x800 — most negative I-type immediate (-2048)
    apply(32'b100000000000_00000_000_00001_0010011, IMM_I, 32'hFFFF_F800);

    // ── S-type ───────────────────────────────────────────
    // imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
    //
    // SW x1, 1(x0) — imm = 0x001 → 0x00000001
    // instr[31:25]=0000000, instr[11:7]=00001
    apply(32'b0000000_00001_00000_010_00001_0100011, IMM_S, 32'h0000_0001);
    // SW x1, -1(x0) — imm = 0xFFF → 0xFFFFFFFF
    // instr[31:25]=1111111, instr[11:7]=11111
    apply(32'b1111111_00001_00000_010_11111_0100011, IMM_S, 32'hFFFF_FFFF);
    // imm = 0x7FF — max positive S-type
    // instr[31:25]=0111111, instr[11:7]=11111
    apply(32'b0111111_00001_00000_010_11111_0100011, IMM_S, 32'h0000_07FF);
    // imm = 0x800 — most negative S-type (-2048)
    // instr[31:25]=1000000, instr[11:7]=00000
    apply(32'b1000000_00001_00000_010_00000_0100011, IMM_S, 32'hFFFF_F800);

    // ── B-type ───────────────────────────────────────────
    // imm[12]   = instr[31]
    // imm[11]   = instr[7]
    // imm[10:5] = instr[30:25]
    // imm[4:1]  = instr[11:8]
    // imm[0]    = 0 (always)
    //
    // BEQ — imm = +2 (smallest forward branch)
    // instr[31]=0, instr[7]=0, instr[30:25]=000000, instr[11:8]=0001
    apply(32'b0_000000_00000_00000_000_0001_0_1100011, IMM_B, 32'h0000_0002);
    // BEQ — imm = -2 (smallest backward branch)
    // instr[31]=1, instr[7]=1, instr[30:25]=111111, instr[11:8]=1111
    apply(32'b1_111111_00000_00000_000_1111_1_1100011, IMM_B, 32'hFFFF_FFFE);
    // BEQ — imm = 0x0FFE — all non-sign immediate bits set, sign=0
    // instr[31]=0, instr[7]=1, instr[30:25]=111111, instr[11:8]=1111
    apply(32'b0_111111_00000_00000_000_1111_1_1100011, IMM_B, 32'h0000_0FFE);
    // Verify bit[12] lands correctly — sign bit only
    // instr[31]=1, all others 0
    apply(32'b1_000000_00000_00000_000_0000_0_1100011, IMM_B, 32'hFFFF_F000);

    // ── U-type ───────────────────────────────────────────
    // imm[31:12] = instr[31:12], imm[11:0] = 0
    //
    // LUI x1, 1 — imm = 0x00001000
    apply(32'b00000000000000000001_00001_0110111, IMM_U, 32'h0000_1000);
    // LUI x1, 0xFFFFF — all upper bits set
    apply(32'b11111111111111111111_00001_0110111, IMM_U, 32'hFFFF_F000);
    // LUI x1, 0x80000 — sign bit set, lower 12 must be zero
    apply(32'b10000000000000000000_00001_0110111, IMM_U, 32'h8000_0000);
    // Lower 12 bits of instruction ignored — rd/opcode fields nonzero
    apply(32'b00000000000000000001_11111_0110111, IMM_U, 32'h0000_1000);

    // ── J-type ───────────────────────────────────────────
    // imm[20]    = instr[31]
    // imm[19:12] = instr[19:12]
    // imm[11]    = instr[20]
    // imm[10:1]  = instr[30:21]
    // imm[0]     = 0 (always)
    //
    // JAL — imm = +2 (smallest forward jump)
    // instr[31]=0, instr[19:12]=00000000, instr[20]=0, instr[30:21]=0000000001
    apply(32'b0_0000000001_0_00000000_00001_1101111, IMM_J, 32'h0000_0002);
    // JAL — imm = -2 (smallest backward jump)
    // instr[31]=1, instr[19:12]=11111111, instr[20]=1, instr[30:21]=1111111111
    apply(32'b1_1111111111_1_11111111_00001_1101111, IMM_J, 32'hFFFF_FFFE);
    // JAL — imm = 0x000FFFFE — all non-sign bits set, sign=0
    apply(32'b0_1111111111_1_11111111_00001_1101111, IMM_J, 32'h000F_FFFE);
    // Verify bit[20] lands correctly — sign bit only
    apply(32'b1_0000000000_0_00000000_00001_1101111, IMM_J, 32'hFFF0_0000);

    chk.report();
    $finish;
  end

endmodule
