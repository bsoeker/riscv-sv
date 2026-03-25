// Import the package to use the alu_op_e type for internal wires
import riscv_pkg::*;

module top (
    // Top-level ports (usually connected to FPGA pins or a testbench)
    input  logic           clk,
    input  logic    [31:0] a,
    input  logic    [31:0] b,
    input  alu_op_e        ctrl,
    output logic    [31:0] out,
    output logic           is_zero
);

  // Syntax: <module_name> <instance_name> ( .<port>(<signal>) );
  alu u_alu (
      .op_a       (a),       // Connects top-level 'a' to ALU 'op_a'
      .op_b       (b),       // Connects top-level 'b' to ALU 'op_b'
      .alu_control(ctrl),    // Connects top-level 'ctrl' to ALU 'alu_control'
      .result     (out),     // Connects ALU 'result' to top-level 'out'
      .zero       (is_zero)  // Connects ALU 'zero' to top-level 'is_zero'
  );

endmodule
