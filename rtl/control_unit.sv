import riscv_pkg::*;

module control_unit (
    input  logic             clk,
    input  logic             rst_n,
    input  logic       [6:0] opcode,
    input  logic       [2:0] funct3,
    input  logic       [6:0] funct7,
    input  logic             mem_read_complete,
    output logic             ir_write_en,
    output logic             pc_write_en,
    output logic             reg_write_en,
    output logic             mem_read,
    output logic             mem_write,
    output alu_op_e          alu_control,
    output alu_src_a_e       alu_src_a,
    output alu_src_b_e       alu_src_b,
    output wb_sel_e          wb_sel,
    output imm_type_e        imm_type,
    output logic             is_branch,
    output logic             is_jal,
    output logic             is_jalr
);

  state_e state, next_state;
  decoded_t d;

  // ── Layer 1: combinational decoder ─────────────────────
  always_comb begin
    // Default values
    d = '{
        alu_control: ALU_ADD,
        alu_src_a: SRCA_RS1,
        alu_src_b: SRCB_RS2,
        reg_write_en: 1'b0,
        is_load: 1'b0,
        is_store: 1'b0,
        is_branch: 1'b0,
        is_jal: 1'b0,
        is_jalr: 1'b0,
        wb_sel: WB_ALU,
        imm_type: IMM_I
    };

    case (opcode)
      7'b0110011: begin  // R-type
        d.alu_src_a = SRCA_RS1;
        d.alu_src_b = SRCB_RS2;
        d.reg_write_en = 1'b1;
        case (funct3)
          3'b000:  d.alu_control = funct7[5] ? ALU_SUB : ALU_ADD;
          3'b001:  d.alu_control = ALU_SLL;
          3'b010:  d.alu_control = ALU_SLT;
          3'b011:  d.alu_control = ALU_SLTU;
          3'b100:  d.alu_control = ALU_XOR;
          3'b101:  d.alu_control = funct7[5] ? ALU_SRA : ALU_SRL;
          3'b110:  d.alu_control = ALU_OR;
          3'b111:  d.alu_control = ALU_AND;
          default: d.alu_control = ALU_ADD;
        endcase
      end

      7'b0010011: begin  // I-type ALU
        d.alu_src_a = SRCA_RS1;
        d.alu_src_b = SRCB_IMM;
        d.reg_write_en = 1'b1;
        d.imm_type = IMM_I;
        case (funct3)
          3'b000:  d.alu_control = ALU_ADD;
          3'b001:  d.alu_control = ALU_SLL;
          3'b010:  d.alu_control = ALU_SLT;
          3'b011:  d.alu_control = ALU_SLTU;
          3'b100:  d.alu_control = ALU_XOR;
          3'b101:  d.alu_control = funct7[5] ? ALU_SRA : ALU_SRL;
          3'b110:  d.alu_control = ALU_OR;
          3'b111:  d.alu_control = ALU_AND;
          default: d.alu_control = ALU_ADD;
        endcase
      end

      7'b0000011: begin  // Load -- variants are handled by load unit
        d.is_load      = 1'b1;
        d.reg_write_en = 1'b1;
        d.alu_src_a    = SRCA_RS1;
        d.alu_src_b    = SRCB_IMM;
        d.alu_control  = ALU_ADD;
        d.imm_type     = IMM_I;
        d.wb_sel       = WB_MEM;
      end

      7'b0100011: begin  // Store -- variants are handled by store unit
        d.is_store = 1'b1;
        d.alu_src_a = SRCA_RS1;
        d.alu_src_b = SRCB_IMM;
        d.alu_control = ALU_ADD;
        d.imm_type = IMM_S;
      end

      7'b1100011: begin  // Branch
        d.is_branch = 1'b1;
        d.alu_src_a = SRCA_RS1;
        d.alu_src_b = SRCB_RS2;
        d.imm_type  = IMM_B;
        case (funct3)
          3'b000, 3'b001: d.alu_control = ALU_SUB;
          3'b100, 3'b101: d.alu_control = ALU_SLT;
          3'b110, 3'b111: d.alu_control = ALU_SLTU;
          default:        d.alu_control = ALU_SUB;
        endcase
      end

      7'b1101111: begin  // JAL
        d.is_jal       = 1'b1;
        d.reg_write_en = 1'b1;
        d.alu_src_a    = SRCA_PC;
        d.alu_src_b    = SRCB_IMM;
        d.alu_control  = ALU_ADD;
        d.imm_type     = IMM_J;
        d.wb_sel       = WB_PC4;
      end

      7'b1100111: begin  // JALR
        d.is_jalr      = 1'b1;
        d.reg_write_en = 1'b1;
        d.alu_src_a    = SRCA_RS1;
        d.alu_src_b    = SRCB_IMM;
        d.alu_control  = ALU_ADD;
        d.imm_type     = IMM_I;
        d.wb_sel       = WB_PC4;
      end

      7'b0110111: begin  // LUI
        d.reg_write_en = 1'b1;
        d.alu_src_a = SRCA_ZERO;
        d.alu_src_b = SRCB_IMM;
        d.alu_control = ALU_ADD;
        d.imm_type = IMM_U;
      end

      7'b0010111: begin  // AUIPC
        d.reg_write_en = 1'b1;
        d.alu_src_a = SRCA_PC;
        d.alu_src_b = SRCB_IMM;
        d.alu_control = ALU_ADD;
        d.imm_type = IMM_U;
      end

      default: ;
    endcase
  end

  // ── State register ─────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) state <= FETCH;
    else state <= next_state;
  end

  // ── Layer 2: FSM ───────────────────────────────────────
  always_comb begin
    // Safe defaults
    ir_write_en  = 1'b0;
    pc_write_en  = 1'b0;
    reg_write_en = 1'b0;
    mem_read     = 1'b0;
    mem_write    = 1'b0;

    // Pass decoded signals through by default
    alu_control  = d.alu_control;
    alu_src_a    = d.alu_src_a;
    alu_src_b    = d.alu_src_b;
    wb_sel       = d.wb_sel;
    imm_type     = d.imm_type;
    is_branch    = d.is_branch;
    is_jal       = d.is_jal;
    is_jalr      = d.is_jalr;

    next_state   = state;

    case (state)
      FETCH: begin
        ir_write_en = 1'b1;
        next_state  = DECODE;
      end

      DECODE: begin
        next_state = EXECUTE;
      end

      EXECUTE: begin
        if (d.is_branch) begin
          pc_write_en = 1'b1;
          next_state  = FETCH;
        end else if (d.is_jal || d.is_jalr) begin
          next_state = WRITEBACK;
        end else if (d.is_load || d.is_store) begin
          next_state = MEMORY;
        end else begin
          next_state = WRITEBACK;
        end
      end

      MEMORY: begin
        if (d.is_load) begin
          mem_read   = 1'b1;
          next_state = MEMORY_WAIT;
        end else begin
          mem_write   = 1'b1;
          pc_write_en = 1'b1;
          next_state  = FETCH;
        end
      end

      MEMORY_WAIT: begin
        mem_read = 1'b1;
        if (mem_read_complete) next_state = WRITEBACK;
      end

      WRITEBACK: begin
        reg_write_en = d.reg_write_en;
        pc_write_en  = 1'b1;
        next_state   = FETCH;
      end

      default: next_state = FETCH;
    endcase
  end

endmodule
