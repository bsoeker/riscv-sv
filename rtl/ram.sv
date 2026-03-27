import riscv_pkg::RAM_ADDR_WIDTH;

// Word sized, byte addressable memory
module ram #(
    parameter int ADDR_WIDTH = RAM_ADDR_WIDTH
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH+1:0] addr,        // byte address
    input  logic                  write_en,
    input  logic [          31:0] write_data,
    input  logic [           3:0] write_mask,
    output logic [          31:0] read_data
);

  logic [31:0] mem[2**ADDR_WIDTH-1:0] = '{default: 32'h0000_0000};

  logic [ADDR_WIDTH-1:0] word_addr;
  assign word_addr = addr[ADDR_WIDTH+1:2];

  always_ff @(posedge clk) begin
    if (write_en) begin
      if (write_mask[0]) mem[word_addr][7:0] <= write_data[7:0];
      if (write_mask[1]) mem[word_addr][15:8] <= write_data[15:8];
      if (write_mask[2]) mem[word_addr][23:16] <= write_data[23:16];
      if (write_mask[3]) mem[word_addr][31:24] <= write_data[31:24];
    end
    read_data <= mem[word_addr];
  end

endmodule
