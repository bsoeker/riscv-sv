import riscv_pkg::*;

module alu (
    input  logic    [31:0] op_a,
    input  logic    [31:0] op_b,
    input  alu_op_e        alu_control,
    output logic    [31:0] result,
    output logic           zero
);


  always_comb begin
    case (alu_control)
      ALU_ADD: result = op_a + op_b;
      ALU_SUB: result = op_a - op_b;
      ALU_AND: result = op_a & op_b;
      ALU_OR:  result = op_a | op_b;
      ALU_XOR: result = op_a ^ op_b;

      // Shifting: op_b[4:0] specifies the shift amount (0-31)
      ALU_SLL: result = op_a << op_b[4:0];  // Logical Left
      ALU_SRL: result = op_a >> op_b[4:0];  // Logical Right

      // Arithmetic Right Shift (>>>) preserves the sign bit
      // We cast op_a to $signed so the operator knows to sign-extend
      ALU_SRA: result = $signed(op_a) >>> op_b[4:0];

      // SLT: Signed comparison
      ALU_SLT: result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;

      // SLTU: Unsigned comparison (default for logic type)
      ALU_SLTU: result = (op_a < op_b) ? 32'd1 : 32'd0;

      default: result = '0;
    endcase
  end

  assign zero = (result == '0);

endmodule
