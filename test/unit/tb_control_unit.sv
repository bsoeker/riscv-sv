`timescale 1ns / 1ps
import riscv_pkg::*;

// ============================================================
// Control Unit Checker
// ============================================================
class cu_checker;

  int unsigned tests_run    = 0;
  int unsigned tests_passed = 0;
  int unsigned tests_failed = 0;

  function void check_logic(input logic actual, input logic expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%0b expected=%0b", msg, actual, expected);
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_alu_op(input alu_op_e actual, input alu_op_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_srca(input alu_src_a_e actual, input alu_src_a_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_srcb(input alu_src_b_e actual, input alu_src_b_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_wb(input wb_sel_e actual, input wb_sel_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_imm(input imm_type_e actual, input imm_type_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void check_state(input state_e actual, input state_e expected, input string msg);
    tests_run++;
    if (actual !== expected) begin
      $error("[FAIL] %s | got=%s expected=%s", msg, actual.name(), expected.name());
      tests_failed++;
    end else begin
      tests_passed++;
    end
  endfunction

  function void report();
    $display(
        "─────────────────────────────────────────");
    $display("Control Unit Testbench Results");
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
module tb_control_unit;

  logic             clk;
  logic             rst_n;
  logic       [6:0] opcode;
  logic       [2:0] funct3;
  logic       [6:0] funct7;
  logic             mem_read_complete;

  logic             ir_write_en;
  logic             pc_write_en;
  logic             reg_write_en;
  logic             mem_read;
  logic             mem_write;
  alu_op_e          alu_control;
  alu_src_a_e       alu_src_a;
  alu_src_b_e       alu_src_b;
  wb_sel_e          wb_sel;
  imm_type_e        imm_type;
  logic             is_branch;
  logic             is_jal;
  logic             is_jalr;

  initial clk = 0;
  always #5 clk = ~clk;

  // Expose internal state for checking
  state_e state;
  assign state = dut.state;

  control_unit dut (
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
      .is_jalr          (is_jalr)
  );

  cu_checker chk;

  // ── Reset ─────────────────────────────────────────────
  task automatic do_reset();
    rst_n             = 1'b0;
    opcode            = 7'b0;
    funct3            = 3'b0;
    funct7            = 7'b0;
    mem_read_complete = 1'b0;
    repeat (3) @(posedge clk);
    #1;
    rst_n = 1'b1;
    @(posedge clk);
    #1;
  endtask

  // ── Wait for a specific state ──────────────────────────
  // NOTE: opcode/funct3/funct7 must remain stable throughout
  // an instruction's execution. The FSM decoder reads them
  // combinationally every cycle — changing them mid-instruction
  // would corrupt state transitions. We only change them when
  // the FSM is back in FETCH, before ir_write_en latches the
  // next instruction in the real CPU.
  task automatic wait_for_state(input state_e s);
    int timeout = 0;
    while (state !== s) begin
      @(posedge clk);
      #1;
      timeout++;
      if (timeout > 20) begin
        $error("[TIMEOUT] waiting for state %s, stuck in %s", s.name(), state.name());
        $finish;
      end
    end
  endtask

  // ── Check signals in current state ────────────────────
  task automatic check_state_signals(input logic exp_ir_write_en, input logic exp_pc_write_en,
                                     input logic exp_reg_write_en, input logic exp_mem_read,
                                     input logic exp_mem_write, input state_e exp_state,
                                     input string msg);
    chk.check_logic(ir_write_en, exp_ir_write_en, $sformatf("%s ir_write_en", msg));
    chk.check_logic(pc_write_en, exp_pc_write_en, $sformatf("%s pc_write_en", msg));
    chk.check_logic(reg_write_en, exp_reg_write_en, $sformatf("%s reg_write_en", msg));
    chk.check_logic(mem_read, exp_mem_read, $sformatf("%s mem_read", msg));
    chk.check_logic(mem_write, exp_mem_write, $sformatf("%s mem_write", msg));
    chk.check_state(state, exp_state, $sformatf("%s state", msg));
  endtask

  // ── Run one full R/I/LUI/AUIPC instruction cycle ───────
  // FETCH → DECODE → EXECUTE → WRITEBACK → FETCH
  // These instructions take exactly 4 cycles
  task automatic run_rtype_cycle(input string msg);
    // FETCH — ir_write_en asserts, nothing else
    wait_for_state(FETCH);
    check_state_signals(1, 0, 0, 0, 0, FETCH, $sformatf("%s FETCH", msg));

    // DECODE — all quiet
    wait_for_state(DECODE);
    check_state_signals(0, 0, 0, 0, 0, DECODE, $sformatf("%s DECODE", msg));

    // EXECUTE — nothing asserts for R/I type
    wait_for_state(EXECUTE);
    check_state_signals(0, 0, 0, 0, 0, EXECUTE, $sformatf("%s EXECUTE", msg));

    // WRITEBACK — reg_write_en and pc_write_en assert
    wait_for_state(WRITEBACK);
    check_state_signals(0, 1, 1, 0, 0, WRITEBACK, $sformatf("%s WRITEBACK", msg));
  endtask

  // ── Run one full branch cycle ──────────────────────────
  // FETCH → DECODE → EXECUTE → FETCH
  // pc_write_en asserts in EXECUTE
  task automatic run_branch_cycle(input string msg);
    wait_for_state(FETCH);
    check_state_signals(1, 0, 0, 0, 0, FETCH, $sformatf("%s FETCH", msg));

    wait_for_state(DECODE);
    check_state_signals(0, 0, 0, 0, 0, DECODE, $sformatf("%s DECODE", msg));

    // EXECUTE — pc_write_en asserts here for branches
    wait_for_state(EXECUTE);
    check_state_signals(0, 1, 0, 0, 0, EXECUTE, $sformatf("%s EXECUTE", msg));
  endtask

  // ── Run one full store cycle ───────────────────────────
  // FETCH → DECODE → EXECUTE → MEMORY → FETCH
  // pc_write_en asserts in MEMORY for stores
  task automatic run_store_cycle(input string msg);
    wait_for_state(FETCH);
    check_state_signals(1, 0, 0, 0, 0, FETCH, $sformatf("%s FETCH", msg));

    wait_for_state(DECODE);
    check_state_signals(0, 0, 0, 0, 0, DECODE, $sformatf("%s DECODE", msg));

    wait_for_state(EXECUTE);
    check_state_signals(0, 0, 0, 0, 0, EXECUTE, $sformatf("%s EXECUTE", msg));

    // MEMORY — mem_write and pc_write_en assert
    wait_for_state(MEMORY);
    check_state_signals(0, 1, 0, 0, 1, MEMORY, $sformatf("%s MEMORY", msg));
  endtask

  // ── Run one full load cycle ────────────────────────────
  // FETCH → DECODE → EXECUTE → MEMORY → MEMORY_WAIT → WRITEBACK → FETCH
  // mem_read asserts in MEMORY and MEMORY_WAIT
  // mem_read_complete must be driven high to exit MEMORY_WAIT
  task automatic run_load_cycle(input string msg);
    wait_for_state(FETCH);
    check_state_signals(1, 0, 0, 0, 0, FETCH, $sformatf("%s FETCH", msg));

    wait_for_state(DECODE);
    check_state_signals(0, 0, 0, 0, 0, DECODE, $sformatf("%s DECODE", msg));

    wait_for_state(EXECUTE);
    check_state_signals(0, 0, 0, 0, 0, EXECUTE, $sformatf("%s EXECUTE", msg));

    // MEMORY — mem_read asserts, no write
    wait_for_state(MEMORY);
    check_state_signals(0, 0, 0, 1, 0, MEMORY, $sformatf("%s MEMORY", msg));

    // MEMORY_WAIT — mem_read held, waiting for read_complete
    wait_for_state(MEMORY_WAIT);
    check_state_signals(0, 0, 0, 1, 0, MEMORY_WAIT, $sformatf("%s MEMORY_WAIT", msg));

    // Drive read_complete to release MEMORY_WAIT
    @(negedge clk);
    mem_read_complete = 1'b1;
    @(posedge clk);
    #1;
    mem_read_complete = 1'b0;

    // WRITEBACK — reg_write_en and pc_write_en assert
    wait_for_state(WRITEBACK);
    check_state_signals(0, 1, 1, 0, 0, WRITEBACK, $sformatf("%s WRITEBACK", msg));
  endtask

  initial begin
    chk = new();
    do_reset();

    // ════════════════════════════════════════════════════
    // DECODER TESTS
    // Check that the correct decoded signals are produced
    // for each opcode. We check in FETCH since the decoder
    // is purely combinational and always active.
    // opcode/funct3/funct7 are stable before FETCH so the
    // decoder output is valid as soon as the state enters FETCH.
    // ════════════════════════════════════════════════════

    // ── R-type ADD ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "R ADD alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "R ADD alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_RS2, "R ADD alu_src_b");
    chk.check_logic(reg_write_en, 1'b0, "R ADD reg_write_en in FETCH");  // not yet
    run_rtype_cycle("R ADD");

    // ── R-type SUB ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7 = 7'b0100000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SUB, "R SUB alu_control");
    run_rtype_cycle("R SUB");

    // ── R-type SLL ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b001;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLL, "R SLL alu_control");
    run_rtype_cycle("R SLL");

    // ── R-type SLT ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b010;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLT, "R SLT alu_control");
    run_rtype_cycle("R SLT");

    // ── R-type SLTU ──────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b011;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLTU, "R SLTU alu_control");
    run_rtype_cycle("R SLTU");

    // ── R-type XOR ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b100;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_XOR, "R XOR alu_control");
    run_rtype_cycle("R XOR");

    // ── R-type SRL ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b101;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SRL, "R SRL alu_control");
    run_rtype_cycle("R SRL");

    // ── R-type SRA ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b101;
    funct7 = 7'b0100000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SRA, "R SRA alu_control");
    run_rtype_cycle("R SRA");

    // ── R-type OR ────────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b110;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_OR, "R OR alu_control");
    run_rtype_cycle("R OR");

    // ── R-type AND ───────────────────────────────────────
    opcode = 7'b0110011;
    funct3 = 3'b111;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_AND, "R AND alu_control");
    run_rtype_cycle("R AND");

    // ── I-type ADDI ──────────────────────────────────────
    opcode = 7'b0010011;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "ADDI alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "ADDI alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "ADDI alu_src_b");
    chk.check_imm(imm_type, IMM_I, "ADDI imm_type");
    run_rtype_cycle("ADDI");

    // ── I-type SLLI ──────────────────────────────────────
    opcode = 7'b0010011;
    funct3 = 3'b001;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLL, "SLLI alu_control");
    run_rtype_cycle("SLLI");

    // ── I-type SRLI ──────────────────────────────────────
    opcode = 7'b0010011;
    funct3 = 3'b101;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SRL, "SRLI alu_control");
    run_rtype_cycle("SRLI");

    // ── I-type SRAI ──────────────────────────────────────
    opcode = 7'b0010011;
    funct3 = 3'b101;
    funct7 = 7'b0100000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SRA, "SRAI alu_control");
    run_rtype_cycle("SRAI");

    // ── Load ─────────────────────────────────────────────
    opcode = 7'b0000011;
    funct3 = 3'b010;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "LW alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "LW alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "LW alu_src_b");
    chk.check_imm(imm_type, IMM_I, "LW imm_type");
    chk.check_wb(wb_sel, WB_MEM, "LW wb_sel");
    run_load_cycle("LW");

    // ── Store ─────────────────────────────────────────────
    opcode = 7'b0100011;
    funct3 = 3'b010;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "SW alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "SW alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "SW alu_src_b");
    chk.check_imm(imm_type, IMM_S, "SW imm_type");
    run_store_cycle("SW");

    // ── Branch BEQ ───────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SUB, "BEQ alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "BEQ alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_RS2, "BEQ alu_src_b");
    chk.check_imm(imm_type, IMM_B, "BEQ imm_type");
    chk.check_logic(is_branch, 1'b1, "BEQ is_branch");
    run_branch_cycle("BEQ");

    // ── Branch BNE ───────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b001;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SUB, "BNE alu_control");
    run_branch_cycle("BNE");

    // ── Branch BLT ───────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b100;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLT, "BLT alu_control");
    run_branch_cycle("BLT");

    // ── Branch BGE ───────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b101;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLT, "BGE alu_control");
    run_branch_cycle("BGE");

    // ── Branch BLTU ──────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b110;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLTU, "BLTU alu_control");
    run_branch_cycle("BLTU");

    // ── Branch BGEU ──────────────────────────────────────
    opcode = 7'b1100011;
    funct3 = 3'b111;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_SLTU, "BGEU alu_control");
    run_branch_cycle("BGEU");

    // ── JAL ──────────────────────────────────────────────
    opcode = 7'b1101111;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "JAL alu_control");
    chk.check_srca(alu_src_a, SRCA_PC, "JAL alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "JAL alu_src_b");
    chk.check_imm(imm_type, IMM_J, "JAL imm_type");
    chk.check_wb(wb_sel, WB_PC4, "JAL wb_sel");
    chk.check_logic(is_jal, 1'b1, "JAL is_jal");
    run_rtype_cycle("JAL");  // same state sequence as R-type

    // ── JALR ─────────────────────────────────────────────
    opcode = 7'b1100111;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "JALR alu_control");
    chk.check_srca(alu_src_a, SRCA_RS1, "JALR alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "JALR alu_src_b");
    chk.check_imm(imm_type, IMM_I, "JALR imm_type");
    chk.check_wb(wb_sel, WB_PC4, "JALR wb_sel");
    chk.check_logic(is_jalr, 1'b1, "JALR is_jalr");
    run_rtype_cycle("JALR");

    // ── LUI ──────────────────────────────────────────────
    opcode = 7'b0110111;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "LUI alu_control");
    chk.check_srca(alu_src_a, SRCA_ZERO, "LUI alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "LUI alu_src_b");
    chk.check_imm(imm_type, IMM_U, "LUI imm_type");
    run_rtype_cycle("LUI");

    // ── AUIPC ────────────────────────────────────────────
    opcode = 7'b0010111;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    chk.check_alu_op(alu_control, ALU_ADD, "AUIPC alu_control");
    chk.check_srca(alu_src_a, SRCA_PC, "AUIPC alu_src_a");
    chk.check_srcb(alu_src_b, SRCB_IMM, "AUIPC alu_src_b");
    chk.check_imm(imm_type, IMM_U, "AUIPC imm_type");
    run_rtype_cycle("AUIPC");

    // ════════════════════════════════════════════════════
    // MEMORY_WAIT STALL TEST
    // Verify FSM stays in MEMORY_WAIT until
    // mem_read_complete is asserted — not just one cycle
    // ════════════════════════════════════════════════════
    opcode = 7'b0000011;
    funct3 = 3'b010;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    wait_for_state(MEMORY_WAIT);

    // Hold mem_read_complete low for 3 cycles — must stay in MEMORY_WAIT
    repeat (3) begin
      @(posedge clk);
      #1;
      chk.check_state(state, MEMORY_WAIT, "MEMORY_WAIT stall holds");
      chk.check_logic(mem_read, 1'b1, "mem_read held in MEMORY_WAIT stall");
    end

    // Now release — should move to WRITEBACK
    @(negedge clk);
    mem_read_complete = 1'b1;
    @(posedge clk);
    #1;
    mem_read_complete = 1'b0;
    wait_for_state(WRITEBACK);
    chk.check_state(state, WRITEBACK, "MEMORY_WAIT released to WRITEBACK");

    // ════════════════════════════════════════════════════
    // RESET MID-INSTRUCTION TEST
    // Assert reset while in EXECUTE — must snap to FETCH
    // ════════════════════════════════════════════════════
    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    wait_for_state(FETCH);
    wait_for_state(EXECUTE);

    // Assert reset mid-instruction
    @(negedge clk);
    rst_n = 1'b0;
    @(posedge clk);
    #1;
    chk.check_state(state, FETCH, "reset mid-EXECUTE snaps to FETCH");
    rst_n = 1'b1;

    chk.report();
    $finish;
  end

endmodule
