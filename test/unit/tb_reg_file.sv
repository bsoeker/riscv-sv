`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// Register File Checker
// ============================================================
class regfile_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check(input logic [4:0] rs_addr, input logic [31:0] actual,
                      input logic [31:0] expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | addr=x%0d | got=0x%08h expected=0x%08h", msg, rs_addr, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Register File Testbench Results");
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
module tb_reg_file;

  logic        clk = 0;
  logic [ 4:0] rs1_addr;
  logic [ 4:0] rs2_addr;
  logic [ 4:0] rd_addr;
  logic [31:0] rd_data;
  logic        reg_write;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  always #5 clk = ~clk;

  reg_file dut (
      .clk      (clk),
      .rs1_addr (rs1_addr),
      .rs2_addr (rs2_addr),
      .rd_addr  (rd_addr),
      .rd_data  (rd_data),
      .reg_write(reg_write),
      .rs1_data (rs1_data),
      .rs2_data (rs2_data)
  );

  regfile_checker chk;

  // Write rd_data into rd_addr, then idle signals
  task automatic write_reg(input logic [4:0] addr, input logic [31:0] data);
    @(negedge clk);
    rd_addr   = addr;
    rd_data   = data;
    reg_write = 1'b1;
    @(posedge clk);
    #1;  // let write settle past clock edge
    reg_write = 1'b0;
    rd_addr   = 5'b0;
    rd_data   = 32'h0;
  endtask

  // Drive read addresses and check outputs combinationally
  task automatic read_check(input logic [4:0] addr1, input logic [4:0] addr2,
                            input logic [31:0] exp1, input logic [31:0] exp2, input string msg);
    rs1_addr = addr1;
    rs2_addr = addr2;
    #1;  // combinational settle
    chk.check(addr1, rs1_data, exp1, $sformatf("%s rs1", msg));
    chk.check(addr2, rs2_data, exp2, $sformatf("%s rs2", msg));
  endtask

  initial begin
    chk = new();

    // Idle all inputs
    rs1_addr = 5'b0;
    rs2_addr = 5'b0;
    rd_addr = 5'b0;
    rd_data = 32'h0;
    reg_write = 1'b0;

    // Wait for simulation to settle
    @(posedge clk);
    #1;

    // ── x0 always reads zero ─────────────────────────────
    // Attempt to write a non-zero value to x0
    write_reg(5'd0, 32'hDEADBEEF);
    read_check(5'd0, 5'd0, 32'h0, 32'h0, "x0 write ignored");

    // ── Basic write and read back ────────────────────────
    write_reg(5'd1, 32'hAAAA_AAAA);
    write_reg(5'd2, 32'h5555_5555);
    write_reg(5'd15, 32'hDEAD_BEEF);
    write_reg(5'd31, 32'hCAFE_F00D);

    read_check(5'd1, 5'd2, 32'hAAAA_AAAA, 32'h5555_5555, "basic write/read");
    read_check(5'd15, 5'd31, 32'hDEAD_BEEF, 32'hCAFE_F00D, "basic write/read");

    // ── reg_write low — no write occurs ─────────────────
    rs1_addr  = 5'd1;
    rd_addr   = 5'd1;
    rd_data   = 32'hFFFF_FFFF;
    reg_write = 1'b0;
    @(posedge clk);
    #1;
    chk.check(5'd1, rs1_data, 32'hAAAA_AAAA, "reg_write=0 no write");

    // ── Same address on rs1 and rs2 ──────────────────────
    write_reg(5'd5, 32'h1234_5678);
    read_check(5'd5, 5'd5, 32'h1234_5678, 32'h1234_5678, "rs1==rs2 same addr");

    // ── All 31 writeable registers ───────────────────────
    // Write unique value to every register x1-x31
    for (int unsigned i = 1; i < NUM_REGS; i++) begin
      write_reg(5'(i), i * 32'hDEAD_0001);
    end
    // Read back and verify all
    for (int unsigned i = 1; i < NUM_REGS; i++) begin
      rs1_addr = 5'(i);
      #1;
      chk.check(5'(i), rs1_data, i * 32'hDEAD_0001, $sformatf("all regs sweep x%0d", i));
    end

    // ── x0 still zero after full sweep ───────────────────
    read_check(5'd0, 5'd0, 32'h0, 32'h0, "x0 zero after sweep");

    chk.report();
    $finish;
  end

endmodule
