`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// RAM Checker
// ============================================================
class ram_checker;

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

  function void check_flag(input logic actual, input logic expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%0b expected=%0b", msg, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("RAM Testbench Results");
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
module tb_ram;

  logic                      clk;
  logic [RAM_ADDR_WIDTH+1:0] addr;
  logic                      write_en;
  logic                      read_en;
  logic [              31:0] write_data;
  logic [               3:0] write_mask;
  logic [              31:0] read_data;
  logic                      read_complete;

  initial clk = 0;
  always #5 clk = ~clk;

  ram dut (
      .clk          (clk),
      .addr         (addr),
      .write_en     (write_en),
      .read_en      (read_en),
      .write_data   (write_data),
      .write_mask   (write_mask),
      .read_data    (read_data),
      .read_complete(read_complete)
  );

  ram_checker chk;

  // Write a word with given mask, hold for one cycle
  task automatic write_word(input logic [RAM_ADDR_WIDTH+1:0] a, input logic [31:0] data,
                            input logic [3:0] mask);
    @(negedge clk);
    addr       = a;
    write_data = data;
    write_mask = mask;
    write_en   = 1'b1;
    read_en    = 1'b0;
    @(posedge clk);
    #1;
    write_en   = 1'b0;
    write_mask = 4'b0000;
    write_data = 32'h0;
  endtask

  // Issue a read, wait one cycle for data, check read_complete then read_data
  task automatic read_word(input logic [RAM_ADDR_WIDTH+1:0] a, input logic [31:0] expected,
                           input string msg);
    @(negedge clk);
    addr     = a;
    read_en  = 1'b1;
    write_en = 1'b0;
    @(posedge clk);
    #1;
    chk.check_flag(read_complete, 1'b1, $sformatf("%s read_complete", msg));
    chk.check(read_data, expected, msg);
    read_en = 1'b0;
    // Verify read_complete deasserts next cycle
    @(posedge clk);
    #1;
    chk.check_flag(read_complete, 1'b0, $sformatf("%s read_complete deasserts", msg));
  endtask

  initial begin
    chk        = new();

    // Idle inputs
    addr       = '0;
    write_en   = 1'b0;
    read_en    = 1'b0;
    write_data = 32'h0;
    write_mask = 4'b0000;

    @(posedge clk);
    #1;

    // ── Full word write and read back ─────────────────────
    write_word(12'h000, 32'hDEAD_BEEF, 4'b1111);
    read_word(12'h000, 32'hDEAD_BEEF, "SW/LW word 0");

    write_word(12'h004, 32'hCAFE_F00D, 4'b1111);
    read_word(12'h004, 32'hCAFE_F00D, "SW/LW word 1");

    // ── Byte lane 0 — write_mask=0001 ────────────────────
    // First clear the word
    write_word(12'h008, 32'h0000_0000, 4'b1111);
    write_word(12'h008, 32'hFFFF_FFAB, 4'b0001);  // only byte 0
    read_word(12'h008, 32'h0000_00AB, "SB byte lane 0");

    // ── Byte lane 1 — write_mask=0010 ────────────────────
    write_word(12'h00C, 32'h0000_0000, 4'b1111);
    write_word(12'h00C, 32'hFFFF_CDFF, 4'b0010);  // only byte 1
    read_word(12'h00C, 32'h0000_CD00, "SB byte lane 1");

    // ── Byte lane 2 — write_mask=0100 ────────────────────
    write_word(12'h010, 32'h0000_0000, 4'b1111);
    write_word(12'h010, 32'hFFEF_FFFF, 4'b0100);  // only byte 2
    read_word(12'h010, 32'h00EF_0000, "SB byte lane 2");

    // ── Byte lane 3 — write_mask=1000 ────────────────────
    write_word(12'h014, 32'h0000_0000, 4'b1111);
    write_word(12'h014, 32'hBEFF_FFFF, 4'b1000);  // only byte 3
    read_word(12'h014, 32'hBE00_0000, "SB byte lane 3");

    // ── Halfword low — write_mask=0011 ───────────────────
    write_word(12'h018, 32'h0000_0000, 4'b1111);
    write_word(12'h018, 32'hFFFF_CAFE, 4'b0011);
    read_word(12'h018, 32'h0000_CAFE, "SH low halfword");

    // ── Halfword high — write_mask=1100 ──────────────────
    write_word(12'h01C, 32'h0000_0000, 4'b1111);
    write_word(12'h01C, 32'hBEEF_FFFF, 4'b1100);
    read_word(12'h01C, 32'hBEEF_0000, "SH high halfword");

    // ── Byte lanes are independent ────────────────────────
    // Write each byte of a word separately, verify final word
    write_word(12'h020, 32'h0000_0000, 4'b1111);
    write_word(12'h020, 32'hFFFF_FF11, 4'b0001);  // byte 0 = 0x11
    write_word(12'h020, 32'hFFFF_22FF, 4'b0010);  // byte 1 = 0x22
    write_word(12'h020, 32'hFF33_FFFF, 4'b0100);  // byte 2 = 0x33
    write_word(12'h020, 32'h44FF_FFFF, 4'b1000);  // byte 3 = 0x44
    read_word(12'h020, 32'h4433_2211, "independent byte lanes");

    // ── write_en=0 does not write ─────────────────────────
    write_word(12'h024, 32'hAAAA_AAAA, 4'b1111);
    // Attempt write with enable low
    @(negedge clk);
    addr       = 12'h024;
    write_data = 32'hDEAD_BEEF;
    write_mask = 4'b1111;
    write_en   = 1'b0;
    @(posedge clk);
    #1;
    write_en = 1'b0;
    read_word(12'h024, 32'hAAAA_AAAA, "write_en=0 no write");

    // ── read_en=0 does not pulse read_complete ────────────
    @(negedge clk);
    addr    = 12'h000;
    read_en = 1'b0;
    @(posedge clk);
    #1;
    chk.check_flag(read_complete, 1'b0, "read_en=0 no read_complete");

    // ── Different addresses don't alias ───────────────────
    write_word(12'h028, 32'h1111_1111, 4'b1111);
    write_word(12'h02C, 32'h2222_2222, 4'b1111);
    write_word(12'h030, 32'h3333_3333, 4'b1111);
    read_word(12'h028, 32'h1111_1111, "no alias addr 0x028");
    read_word(12'h02C, 32'h2222_2222, "no alias addr 0x02C");
    read_word(12'h030, 32'h3333_3333, "no alias addr 0x030");

    chk.report();
    $finish;
  end

endmodule
