module ram (
    input logic clk,
    input logic w_en,
    input logic [31:0] w_data,
    input logic [7:0] addr,
    output logic [31:0] r_data
);

  logic [31:0] mem[256];

  always_ff @(posedge clk) begin
    if (w_en) mem[addr] <= w_data;
  end

  assign r_data = mem[addr];

endmodule
