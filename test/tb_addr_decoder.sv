`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// Address Decoder Checker
// ============================================================
class addrdec_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check(input logic [31:0] addr, input logic actual_rom_en, input logic actual_ram_en,
                      input logic expected_rom_en, input logic expected_ram_en, input string msg);
    tests_run++;
    if (actual_rom_en !== expected_rom_en || actual_ram_en !== expected_ram_en) begin
      $error("[FAIL] %s | addr=0x%08h | rom_en got=%b exp=%b | ram_en got=%b exp=%b", msg, addr,
             actual_rom_en, expected_rom_en, actual_ram_en, expected_ram_en);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Address Decoder Testbench Results");
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
module tb_addr_decoder;

  logic [              31:0] addr;
  logic                      rom_en;
  logic [ROM_ADDR_WIDTH+1:0] rom_addr;
  logic                      ram_en;
  logic [RAM_ADDR_WIDTH+1:0] ram_addr;

  addr_decoder dut (
      .addr    (addr),
      .rom_en  (rom_en),
      .rom_addr(rom_addr),
      .ram_en  (ram_en),
      .ram_addr(ram_addr)
  );

  addrdec_checker chk;

  task automatic apply(input logic [31:0] a, input logic exp_rom_en, input logic exp_ram_en,
                       input string msg);
    addr = a;
    #1;
    chk.check(a, rom_en, ram_en, exp_rom_en, exp_ram_en, msg);
  endtask

  initial begin
    chk = new();

    // ── ROM region: 0x00000000 - 0x00000FFF ─────────────
    // Base address
    apply(ROM_BASE, 1, 0, "ROM base");
    // Last valid byte address in ROM
    apply(ROM_BASE + (ROM_DEPTH * 4) - 4, 1, 0, "ROM last word");
    // One byte past ROM region
    apply(ROM_BASE + (ROM_DEPTH * 4), 0, 0, "ROM one past end");
    // Middle of ROM region
    apply(ROM_BASE + 32'h100, 1, 0, "ROM mid region");

    // ── RAM region: 0x10000000 - 0x10000FFF ─────────────
    // Base address
    apply(RAM_BASE, 0, 1, "RAM base");
    // Last valid byte address in RAM
    apply(RAM_BASE + (RAM_DEPTH * 4) - 4, 0, 1, "RAM last word");
    // One byte past RAM region
    apply(RAM_BASE + (RAM_DEPTH * 4), 0, 0, "RAM one past end");
    // Middle of RAM region
    apply(RAM_BASE + 32'h100, 0, 1, "RAM mid region");

    // ── No region ────────────────────────────────────────
    // Completely unmapped address
    apply(32'hDEAD_BEEF, 0, 0, "unmapped address");
    // Max address
    apply(32'hFFFF_FFFF, 0, 0, "max address");
    // Just before ROM base — nothing should assert
    apply(ROM_BASE - 1, 0, 0, "just before ROM");
    // Between ROM and RAM
    apply(32'h0800_0000, 0, 0, "between ROM and RAM");
    // Just before RAM base
    apply(RAM_BASE - 1, 0, 0, "just before RAM");

    // ── Address output correctness ────────────────────────
    // Verify rom_addr and ram_addr pass through correctly
    addr = ROM_BASE + 32'h00C;
    #1;
    assert (rom_addr == 12'h00C)
    else $error("[FAIL] rom_addr passthrough | got=0x%03h expected=0x00C", rom_addr);

    addr = RAM_BASE + 32'h008;
    #1;
    assert (ram_addr == 12'h008)
    else $error("[FAIL] ram_addr passthrough | got=0x%03h expected=0x008", ram_addr);

    chk.report();
    $finish;
  end

endmodule
