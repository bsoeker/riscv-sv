`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// PC Checker
// ============================================================
class pc_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check(input logic [31:0] actual, input logic [31:0] expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=0x%08h expected=0x%08h", msg, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("PC Testbench Results");
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
module tb_pc;

  logic        clk;
  logic        rst_n;
  logic        pc_write_en;
  logic [31:0] pc_in;
  logic [31:0] pc_out;

  initial clk = 0;
  always #5 clk = ~clk;

  pc dut (
      .clk        (clk),
      .rst_n      (rst_n),
      .pc_write_en(pc_write_en),
      .pc_in      (pc_in),
      .pc_out     (pc_out)
  );

  pc_checker chk;

  // Drive inputs and check output one cycle later
  task automatic apply(input logic en, input logic [31:0] in, input logic [31:0] expected,
                       input string msg);
    @(negedge clk);
    pc_write_en = en;
    pc_in       = in;
    @(posedge clk);
    #1;
    chk.check(pc_out, expected, msg);
  endtask

  initial begin
    chk         = new();

    // Initialise inputs
    pc_write_en = 1'b0;
    pc_in       = 32'h0;

    // ── Reset behaviour ───────────────────────────────────
    rst_n       = 1'b0;
    repeat (3) @(posedge clk);
    #1;
    chk.check(pc_out, RESET_PC, "reset holds RESET_PC");

    // ── PC frozen while reset asserted ────────────────────
    // Even with pc_write_en high, reset wins
    @(negedge clk);
    pc_write_en = 1'b1;
    pc_in       = 32'hDEAD_BEEF;
    @(posedge clk);
    #1;
    chk.check(pc_out, RESET_PC, "reset overrides pc_write_en");

    // ── Release reset ─────────────────────────────────────
    @(negedge clk);
    rst_n       = 1'b1;
    pc_write_en = 1'b0;
    pc_in       = 32'h0;
    @(posedge clk);
    #1;
    chk.check(pc_out, RESET_PC, "after reset release, pc_write_en=0 holds value");

    // ── pc_write_en=0 freezes PC ──────────────────────────
    // Drive a new value but keep enable low — PC must not change
    apply(1'b0, 32'hCAFE_F00D, RESET_PC, "pc_write_en=0 no update 1");
    apply(1'b0, 32'hFFFF_FFFF, RESET_PC, "pc_write_en=0 no update 2");

    // ── pc_write_en=1 updates PC ──────────────────────────
    apply(1'b1, 32'h0000_0004, 32'h0000_0004, "pc advances to 0x4");
    apply(1'b1, 32'h0000_0008, 32'h0000_0008, "pc advances to 0x8");
    apply(1'b1, 32'h0000_000C, 32'h0000_000C, "pc advances to 0xC");

    // ── pc_write_en=0 after advance — holds last value ────
    apply(1'b0, 32'hDEAD_BEEF, 32'h0000_000C, "frozen after advance");
    apply(1'b0, 32'hDEAD_BEEF, 32'h0000_000C, "frozen after advance 2");

    // ── Jump target ───────────────────────────────────────
    apply(1'b1, 32'h1000_0000, 32'h1000_0000, "jump to RAM base");
    apply(1'b0, 32'h0, 32'h1000_0000, "frozen at jump target");

    // ── JALR LSB masking — not PC's responsibility ────────
    // PC just stores whatever it's given — LSB masking
    // is done in the top module before pc_in is driven
    apply(1'b1, 32'hFFFF_FFFE, 32'hFFFF_FFFE, "arbitrary target even address");
    apply(1'b1, 32'h0000_0000, 32'h0000_0000, "back to zero");

    // ── Reset mid-execution ───────────────────────────────
    // Advance PC then assert reset — must snap back to RESET_PC
    apply(1'b1, 32'h0000_0010, 32'h0000_0010, "advance before mid-reset");
    @(negedge clk);
    rst_n       = 1'b0;
    pc_write_en = 1'b0;
    @(posedge clk);
    #1;
    chk.check(pc_out, RESET_PC, "mid-execution reset snaps to RESET_PC");
    @(negedge clk);
    rst_n = 1'b1;

    chk.report();
    $finish;
  end

endmodule
