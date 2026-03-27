import riscv_pkg::NUM_REGS;

module reg_file (
    input  logic        clk,
    input  logic [ 4:0] rs1_addr,
    input  logic [ 4:0] rs2_addr,
    input  logic [ 4:0] rd_addr,
    input  logic [31:0] rd_data,
    input  logic        reg_write,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

  logic [31:0] regs[NUM_REGS-1:0] = '{default: 32'h0000_0000};

  // Asynchronous read — x0 always reads as zero
  assign rs1_data = (rs1_addr == 5'b0) ? 32'h0 : regs[rs1_addr];
  assign rs2_data = (rs2_addr == 5'b0) ? 32'h0 : regs[rs2_addr];

  // Synchronous write — x0 write ignored
  always_ff @(posedge clk) begin
    if (reg_write && rd_addr != 5'b0) regs[rd_addr] <= rd_data;
  end

endmodule
