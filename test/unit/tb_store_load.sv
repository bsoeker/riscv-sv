`timescale 1ns / 1ps

// ============================================================
// Load/Store Checker
// ============================================================
class loadstore_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check_load(input logic [2:0] funct3, input logic [1:0] byte_offset,
                           input logic [31:0] actual, input logic [31:0] expected,
                           input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] LOAD %s | offset=%0d | got=0x%08h expected=0x%08h", msg, byte_offset, actual,
             expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_store(input logic [2:0] funct3, input logic [1:0] addr_offset,
                            input logic [3:0] actual_mask, input logic [31:0] actual_data,
                            input logic [3:0] expected_mask, input logic [31:0] expected_data,
                            input string msg);
    tests_run++;
    if (actual_mask !== expected_mask || actual_data !== expected_data) begin
      $error("[FAIL] STORE %s | offset=%0d | mask got=%04b exp=%04b | data got=0x%08h exp=0x%08h",
             msg, addr_offset, actual_mask, expected_mask, actual_data, expected_data);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Load/Store Unit Testbench Results");
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
module tb_load_store;

  // Load unit signals
  logic [ 2:0] ld_funct3;
  logic [ 1:0] ld_byte_offset;
  logic [31:0] ld_mem_data;
  logic [31:0] ld_loaded_value;

  // Store unit signals
  logic [ 2:0] st_funct3;
  logic [ 1:0] st_addr_offset;
  logic [31:0] st_store_data;
  logic [ 3:0] st_write_mask;
  logic [31:0] st_write_data;

  load_unit load_dut (
      .funct3      (ld_funct3),
      .byte_offset (ld_byte_offset),
      .mem_data    (ld_mem_data),
      .loaded_value(ld_loaded_value)
  );

  store_unit store_dut (
      .funct3     (st_funct3),
      .addr_offset(st_addr_offset),
      .store_data (st_store_data),
      .write_mask (st_write_mask),
      .write_data (st_write_data)
  );

  loadstore_checker chk;

  // ── Load task ─────────────────────────────────────────────
  task automatic apply_load(input logic [2:0] funct3, input logic [1:0] offset,
                            input logic [31:0] mem_data, input logic [31:0] expected,
                            input string msg);
    ld_funct3      = funct3;
    ld_byte_offset = offset;
    ld_mem_data    = mem_data;
    #1;
    chk.check_load(funct3, offset, ld_loaded_value, expected, msg);
  endtask

  // ── Store task ────────────────────────────────────────────
  task automatic apply_store(input logic [2:0] funct3, input logic [1:0] offset,
                             input logic [31:0] store_data, input logic [3:0] expected_mask,
                             input logic [31:0] expected_data, input string msg);
    st_funct3      = funct3;
    st_addr_offset = offset;
    st_store_data  = store_data;
    #1;
    chk.check_store(funct3, offset, st_write_mask, st_write_data, expected_mask, expected_data,
                    msg);
  endtask

  initial begin
    chk = new();

    // ════════════════════════════════════════════════════
    // STORE UNIT
    // ════════════════════════════════════════════════════

    // ── SB — all four byte offsets ────────────────────────
    // store_data[7:0] should land at the correct byte lane
    apply_store(3'b000, 2'b00, 32'hDEAD_BEEF, 4'b0001, 32'h0000_00EF, "SB offset=0");
    apply_store(3'b000, 2'b01, 32'hDEAD_BEEF, 4'b0010, 32'h0000_EF00, "SB offset=1");
    apply_store(3'b000, 2'b10, 32'hDEAD_BEEF, 4'b0100, 32'h00EF_0000, "SB offset=2");
    apply_store(3'b000, 2'b11, 32'hDEAD_BEEF, 4'b1000, 32'hEF00_0000, "SB offset=3");

    // ── SB — sign bit set in byte, verify only byte copied ─
    apply_store(3'b000, 2'b00, 32'hFFFF_FF80, 4'b0001, 32'h0000_0080, "SB sign byte offset=0");
    apply_store(3'b000, 2'b11, 32'hFFFF_FF80, 4'b1000, 32'h8000_0000, "SB sign byte offset=3");

    // ── SH — two halfword offsets ─────────────────────────
    // store_data[15:0] lands at low or high halfword
    apply_store(3'b001, 2'b00, 32'hDEAD_BEEF, 4'b0011, 32'h0000_BEEF, "SH offset=0");
    apply_store(3'b001, 2'b10, 32'hDEAD_BEEF, 4'b1100, 32'hBEEF_0000, "SH offset=2");

    // ── SH — only addr_offset[1] matters ─────────────────
    // offset=01 should behave same as offset=00
    apply_store(3'b001, 2'b01, 32'hDEAD_BEEF, 4'b0011, 32'h0000_BEEF, "SH offset=1 treated as low");
    apply_store(3'b001, 2'b11, 32'hDEAD_BEEF, 4'b1100, 32'hBEEF_0000,
                "SH offset=3 treated as high");

    // ── SW — full word, mask all ones ────────────────────
    apply_store(3'b010, 2'b00, 32'hDEAD_BEEF, 4'b1111, 32'hDEAD_BEEF, "SW");
    apply_store(3'b010, 2'b00, 32'h0000_0000, 4'b1111, 32'h0000_0000, "SW zero");
    apply_store(3'b010, 2'b00, 32'hFFFF_FFFF, 4'b1111, 32'hFFFF_FFFF, "SW all ones");

    // ════════════════════════════════════════════════════
    // LOAD UNIT
    // ════════════════════════════════════════════════════

    // mem_data word used throughout: 0xAABBCCDD
    // byte0=0xDD, byte1=0xCC, byte2=0xBB, byte3=0xAA

    // ── LB — signed byte, all four offsets ───────────────
    apply_load(3'b000, 2'b00, 32'hAABBCCDD, 32'hFFFF_FFDD, "LB offset=0 signed");
    apply_load(3'b000, 2'b01, 32'hAABBCCDD, 32'hFFFF_FFCC, "LB offset=1 signed");
    apply_load(3'b000, 2'b10, 32'hAABBCCDD, 32'hFFFF_FFBB, "LB offset=2 signed");
    apply_load(3'b000, 2'b11, 32'hAABBCCDD, 32'hFFFF_FFAA, "LB offset=3 signed");

    // ── LB — positive byte (MSB=0), no sign extension ────
    apply_load(3'b000, 2'b00, 32'hAABBCC7F, 32'h0000_007F, "LB positive byte");

    // ── LBU — unsigned byte, all four offsets ────────────
    apply_load(3'b100, 2'b00, 32'hAABBCCDD, 32'h0000_00DD, "LBU offset=0");
    apply_load(3'b100, 2'b01, 32'hAABBCCDD, 32'h0000_00CC, "LBU offset=1");
    apply_load(3'b100, 2'b10, 32'hAABBCCDD, 32'h0000_00BB, "LBU offset=2");
    apply_load(3'b100, 2'b11, 32'hAABBCCDD, 32'h0000_00AA, "LBU offset=3");

    // ── LBU vs LB — same byte, different sign treatment ──
    // byte=0xFF: LB→0xFFFFFFFF, LBU→0x000000FF
    apply_load(3'b000, 2'b00, 32'hAABBCCFF, 32'hFFFF_FFFF, "LB  0xFF signed");
    apply_load(3'b100, 2'b00, 32'hAABBCCFF, 32'h0000_00FF, "LBU 0xFF unsigned");

    // ── LH — signed halfword, two offsets ────────────────
    apply_load(3'b001, 2'b00, 32'hAABBCCDD, 32'hFFFF_CCDD, "LH offset=0 signed");
    apply_load(3'b001, 2'b10, 32'hAABBCCDD, 32'hFFFF_AABB, "LH offset=2 signed");

    // ── LH — positive halfword (MSB=0) ───────────────────
    apply_load(3'b001, 2'b00, 32'hAABB7FFF, 32'h0000_7FFF, "LH positive halfword");

    // ── LHU — unsigned halfword, two offsets ─────────────
    apply_load(3'b101, 2'b00, 32'hAABBCCDD, 32'h0000_CCDD, "LHU offset=0");
    apply_load(3'b101, 2'b10, 32'hAABBCCDD, 32'h0000_AABB, "LHU offset=2");

    // ── LHU vs LH — same halfword, different sign treatment
    // halfword=0xFFFF: LH→0xFFFFFFFF, LHU→0x0000FFFF
    apply_load(3'b001, 2'b00, 32'hAABBFFFF, 32'hFFFF_FFFF, "LH  0xFFFF signed");
    apply_load(3'b101, 2'b00, 32'hAABBFFFF, 32'h0000_FFFF, "LHU 0xFFFF unsigned");

    // ── LW — full word ────────────────────────────────────
    apply_load(3'b010, 2'b00, 32'hDEAD_BEEF, 32'hDEAD_BEEF, "LW passthrough");
    apply_load(3'b010, 2'b00, 32'h0000_0000, 32'h0000_0000, "LW zero");
    apply_load(3'b010, 2'b00, 32'hFFFF_FFFF, 32'hFFFF_FFFF, "LW all ones");

    // ════════════════════════════════════════════════════
    // ROUND-TRIP: store then load same value
    // ════════════════════════════════════════════════════
    // Simulate what the RAM would return after a store
    // by feeding store_unit output into load_unit input

    begin
      logic [31:0] rt_mem;
      logic [31:0] rt_loaded;

      // SB then LB — byte=0xBE at offset 2
      apply_store(3'b000, 2'b10, 32'h0000_00BE, 4'b0100, 32'h00BE_0000, "RT SB setup");
      // Simulate RAM: merge written byte into a word
      rt_mem = 32'h00BE_0000;
      apply_load(3'b000, 2'b10, rt_mem, 32'hFFFF_FFBE, "RT LB signed");
      apply_load(3'b100, 2'b10, rt_mem, 32'h0000_00BE, "RT LBU unsigned");

      // SH then LH — halfword=0xCAFE at offset 2
      apply_store(3'b001, 2'b10, 32'h0000_CAFE, 4'b1100, 32'hCAFE_0000, "RT SH setup");
      rt_mem = 32'hCAFE_0000;
      apply_load(3'b001, 2'b10, rt_mem, 32'hFFFF_CAFE, "RT LH signed");
      apply_load(3'b101, 2'b10, rt_mem, 32'h0000_CAFE, "RT LHU unsigned");

      // SW then LW
      apply_store(3'b010, 2'b00, 32'hDEAD_BEEF, 4'b1111, 32'hDEAD_BEEF, "RT SW setup");
      rt_mem = 32'hDEAD_BEEF;
      apply_load(3'b010, 2'b00, rt_mem, 32'hDEAD_BEEF, "RT LW");
    end

    chk.report();
    $finish;
  end

endmodule
