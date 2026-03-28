import riscv_pkg::*;

module pc (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pc_write_en,
    input  logic [31:0] pc_in,
    output logic [31:0] pc_out
);

  always_ff @(posedge clk) begin
    if (!rst_n) pc_out <= RESET_PC;
    else if (pc_write_en) pc_out <= pc_in;
  end

endmodule
