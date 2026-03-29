`timescale 1ns / 1ps
import riscv_pkg::*;

module tb_top;

  logic clk;
  logic rst_n;

  // ── Clock generation ──────────────────────────────────
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz, 10ns period

  // ── DUT ───────────────────────────────────────────────
  top dut (
      .clk  (clk),
      .rst_n(rst_n)
  );

  // ── Reset then run ────────────────────────────────────
  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);  // hold reset for 5 cycles
    @(negedge clk);  // release on negedge for clean setup
    rst_n = 1'b1;

    repeat (200) @(posedge clk);  // run for 200 cycles
    $finish;
  end

endmodule
