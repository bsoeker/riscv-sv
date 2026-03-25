`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// ALU Transaction — one stimulus item
// ============================================================
class alu_transaction;

  rand logic    [31:0] op_a;
  rand logic    [31:0] op_b;
  rand alu_op_e        alu_control;

  // --- Operand value weights ---
  // Bias toward interesting boundary values while keeping
  // general random coverage as the bulk of the distribution.
  constraint c_op_a_corners {
    op_a dist {
      32'h00000000 :/ 5,  // zero
      32'h00000001 :/ 5,  // LSB only
      32'hFFFFFFFF :/ 5,  // all ones / -1 signed
      32'h80000000 :/ 5,  // min signed / sign bit only
      32'h7FFFFFFF :/ 5,  // max positive signed
      [32'h00000002 : 32'h7FFFFFFE] :/ 37,  // positive range
      [32'h80000001 : 32'hFFFFFFFE] :/ 38  // negative range
    };
  }

  constraint c_op_b_corners {
    op_b dist {
      32'h00000000 :/ 5,
      32'h00000001 :/ 5,
      32'hFFFFFFFF :/ 5,
      32'h80000000 :/ 5,
      32'h7FFFFFFF :/ 5,
      [32'h00000002 : 32'h7FFFFFFE] :/ 37,
      [32'h80000001 : 32'hFFFFFFFE] :/ 38
    };
  }

  // Only generate valid opcodes — no default-case hits
  constraint c_valid_opcode {
    alu_control inside {ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR, ALU_SLL, ALU_SRL, ALU_SRA,
                        ALU_SLT, ALU_SLTU};
  }

  // For shift operations, bias op_b to interesting shift amounts.
  // Only the lower 5 bits matter per RISC-V spec.
  constraint c_shift_amount {
    if (alu_control inside {ALU_SLL, ALU_SRL, ALU_SRA}) {
      op_b dist {
        32'h00000000 :/ 10,  // shift by 0 — result must equal op_a
        32'h00000001 :/ 10,  // shift by 1
        32'h0000001F :/ 10,  // shift by 31 — maximum
        32'h00000010 :/ 10,  // shift by 16
        // Values with non-zero upper bits — tests that DUT
        // correctly ignores bits [31:5] of op_b
        32'hFFFFFFFF :/ 10,  // upper bits set, lower = 5'b11111
        32'h80000000 :/ 10,  // only bit 31 set, lower = 5'b00000
        [32'h00000002 : 32'h0000001E] :/ 40
      };
    }
  }

  // For SLT/SLTU: bias toward cases where signed and unsigned
  // comparisons disagree — these are the interesting corner cases
  constraint c_slt_interesting {
    if (alu_control inside {ALU_SLT, ALU_SLTU}) {
      op_a dist {
        32'h80000000 :/ 20,  // most negative signed, large unsigned
        32'h7FFFFFFF :/ 20,  // most positive signed
        32'h00000000 :/ 10,
        [32'h00000001 : 32'hFFFFFFFF] :/ 50
      };
    }
  }

endclass


// ============================================================
// ALU Checker — computes expected result independently
// ============================================================
class alu_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check(input logic [31:0] op_a, input logic [31:0] op_b, input alu_op_e alu_control,
                      input logic [31:0] actual_result, input logic actual_zero);
    logic [31:0] expected_result;
    logic        expected_zero;

    // Reference model — behavioral, matches ISA spec directly
    case (alu_control)
      ALU_ADD:  expected_result = op_a + op_b;
      ALU_SUB:  expected_result = op_a - op_b;
      ALU_AND:  expected_result = op_a & op_b;
      ALU_OR:   expected_result = op_a | op_b;
      ALU_XOR:  expected_result = op_a ^ op_b;
      ALU_SLL:  expected_result = op_a << op_b[4:0];
      ALU_SRL:  expected_result = op_a >> op_b[4:0];
      ALU_SRA:  expected_result = $signed(op_a) >>> op_b[4:0];
      ALU_SLT:  expected_result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
      ALU_SLTU: expected_result = (op_a < op_b) ? 32'd1 : 32'd0;
      default:  expected_result = '0;
    endcase

    expected_zero = (expected_result == 32'h0);
    tests_run++;

    if (actual_result !== expected_result) begin
      $error("[FAIL] op=%s op_a=0x%08h op_b=0x%08h | got=0x%08h expected=0x%08h",
             alu_control.name(), op_a, op_b, actual_result, expected_result);
      tests_failed++;
    end else if (actual_zero !== expected_zero) begin
      $error("[FAIL] zero flag op=%s op_a=0x%08h op_b=0x%08h | got=%0b expected=%0b",
             alu_control.name(), op_a, op_b, actual_zero, expected_zero);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("ALU Testbench Results");
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
// Functional Coverage
// ============================================================
class alu_coverage;

  // Mirror signals for sampling
  logic    [31:0] op_a;
  logic    [31:0] op_b;
  alu_op_e        alu_control;
  logic    [31:0] result;
  logic           zero;

  covergroup alu_cg;

    // Every opcode must be exercised
    cp_opcode: coverpoint alu_control {
      bins add = {ALU_ADD};
      bins sub = {ALU_SUB};
      bins and_ = {ALU_AND};
      bins or_ = {ALU_OR};
      bins xor_ = {ALU_XOR};
      bins sll = {ALU_SLL};
      bins srl = {ALU_SRL};
      bins sra = {ALU_SRA};
      bins slt = {ALU_SLT};
      bins sltu = {ALU_SLTU};
    }

    // Interesting operand A values
    cp_op_a: coverpoint op_a {
      bins zero = {32'h00000000};
      bins one = {32'h00000001};
      bins all_ones = {32'hFFFFFFFF};
      bins min_neg = {32'h80000000};
      bins max_pos = {32'h7FFFFFFF};
      bins positive = {[32'h00000002 : 32'h7FFFFFFE]};
      bins negative = {[32'h80000001 : 32'hFFFFFFFE]};
    }

    // Zero flag coverage — must see both set and clear
    cp_zero: coverpoint zero {
      bins zero_set = {1'b1}; bins zero_clear = {1'b0};
    }

    // Zero flag must be set and cleared for each operation
    cx_opcode_zero: cross cp_opcode, cp_zero;

    // Shift amount corners — only meaningful for shift ops
    cp_shift_amount: coverpoint op_b[4:0] iff (alu_control inside {ALU_SLL, ALU_SRL, ALU_SRA}) {
      bins shift_0 = {5'd0};
      bins shift_1 = {5'd1};
      bins shift_31 = {5'd31};
      bins shift_16 = {5'd16};
      bins others = {[5'd2 : 5'd15], [5'd17 : 5'd30]};
    }

    // Upper bits of op_b ignored for shifts
    // If we see a shift with op_b[31:5] != 0 and result is still
    // correct, we've verified the DUT ignores upper bits
    cp_shift_upper_bits: coverpoint op_b[31:5] iff
            (alu_control inside {ALU_SLL, ALU_SRL, ALU_SRA}) {
      bins zero_upper = {27'd0}; bins nonzero_upper = {[27'd1 : 27'h7FFFFFF]};
    }

    // SLT vs SLTU disagreement — the most interesting comparison cases:
    // op_a negative (MSB=1), op_b positive (MSB=0)
    // SLT  → 1 (negative < positive in signed)
    // SLTU → 0 (large unsigned > small unsigned)
    cp_slt_sign_disagree: coverpoint {
      op_a[31], op_b[31]
    } iff (alu_control inside {ALU_SLT, ALU_SLTU}) {
      bins pp = {2'b00};  // both positive
      bins pn = {2'b01};  // a pos, b neg
      bins np = {2'b10};  // a neg, b pos — signed/unsigned disagree
      bins nn = {2'b11};  // both negative
    }

    // ADD/SUB with equal operands — result must be zero or double
    cp_equal_operands: coverpoint (op_a == op_b) iff
            (alu_control inside {ALU_ADD, ALU_SUB, ALU_XOR}) {
      bins equal = {1'b1}; bins not_equal = {1'b0};
    }

  endgroup

  function new();
    alu_cg = new();
  endfunction

  function void sample (input logic [31:0] a, b, res, input alu_op_e op, input logic z);
    op_a        = a;
    op_b        = b;
    result      = res;
    alu_control = op;
    zero        = z;
    alu_cg.sample();
  endfunction

  function void report();
    $display("Coverage: %.2f%%", alu_cg.get_coverage());
  endfunction

endclass


// ============================================================
// Top-level Testbench
// ============================================================
module alu_tb;

  // DUT signals
  logic    [31:0] op_a;
  logic    [31:0] op_b;
  alu_op_e        alu_control;
  logic    [31:0] result;
  logic           zero;

  // DUT instantiation
  alu dut (
      .op_a       (op_a),
      .op_b       (op_b),
      .alu_control(alu_control),
      .result     (result),
      .zero       (zero)
  );

  // Testbench objects
  alu_transaction txn;
  alu_checker     chk;
  alu_coverage    cov;

  // Number of random tests to run
  localparam int NUM_RANDOM_TESTS = 100_000;

  initial begin
    chk = new();
    cov = new();
    txn = new();

    // ── Directed tests ──────────────────────────────────────
    // These cover cases that pure random might take a long time
    // to hit, or that are architecturally critical.

    // ADD: basic
    apply(32'h00000005, 32'h00000003, ALU_ADD);  // 5+3=8
    apply(32'hFFFFFFFF, 32'h00000001, ALU_ADD);  // wraparound to 0 → zero flag
    apply(32'h7FFFFFFF, 32'h00000001, ALU_ADD);  // overflow into sign bit

    // SUB: result zero
    apply(32'hDEADBEEF, 32'hDEADBEEF, ALU_SUB);  // must produce zero flag

    // SLT vs SLTU disagreement
    apply(32'h80000000, 32'h00000001, ALU_SLT);  // -2147483648 < 1 signed  → 1
    apply(32'h80000000, 32'h00000001, ALU_SLTU);  // 2147483648  > 1 unsigned → 0

    // SRA: sign extension
    apply(32'h80000000, 32'h00000001, ALU_SRA);  // 0xC0000000 — MSB must stay 1
    apply(32'h80000000, 32'h0000001F, ALU_SRA);  // all ones — 0xFFFFFFFF

    // SRL: no sign extension
    apply(32'h80000000, 32'h00000001, ALU_SRL);  // 0x40000000 — MSB becomes 0

    // Shift by 0 — result must equal op_a
    apply(32'hDEADBEEF, 32'h00000000, ALU_SLL);
    apply(32'hDEADBEEF, 32'h00000000, ALU_SRL);
    apply(32'hDEADBEEF, 32'h00000000, ALU_SRA);

    // Shift: upper bits of op_b must be ignored
    apply(32'h00000001, 32'hFFFFFFFF, ALU_SLL);  // lower 5 = 31, shift left 31
    apply(32'h80000000, 32'hFFFFFFFF, ALU_SRA);  // lower 5 = 31, arithmetic right 31

    // XOR self → zero
    apply(32'hCAFEBABE, 32'hCAFEBABE, ALU_XOR);

    // AND/OR with all-ones and all-zeros
    apply(32'hDEADBEEF, 32'hFFFFFFFF, ALU_AND);  // result = op_a
    apply(32'hDEADBEEF, 32'h00000000, ALU_AND);  // result = 0
    apply(32'h00000000, 32'hDEADBEEF, ALU_OR);  // result = op_b
    apply(32'hFFFFFFFF, 32'h00000000, ALU_OR);  // result = all ones

    $display("[INFO] Directed tests complete. Running %0d random tests...", NUM_RANDOM_TESTS);

    // ── Random tests ────────────────────────────────────────
    repeat (NUM_RANDOM_TESTS) begin
      if (!txn.randomize()) $fatal(1, "Randomization failed");
      apply(txn.op_a, txn.op_b, txn.alu_control);
    end

    // ── Final reports ────────────────────────────────────────
    chk.report();
    cov.report();

    $finish;
  end

  // Drive DUT, wait for combinational settle, check, sample coverage
  task automatic apply(input logic [31:0] a, b, input alu_op_e op);
    op_a        = a;
    op_b        = b;
    alu_control = op;
    #1;  // let combinational logic settle
    chk.check(a, b, op, result, zero);
    cov.sample(a, b, result, op, zero);
  endtask

endmodule
