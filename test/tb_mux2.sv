`timescale 1ns / 1ps
module tb_mux2;
  localparam integer WIDTH = 32;

  logic sel;
  logic [WIDTH-1:0] a = 32'h01010101;
  logic [WIDTH-1:0] b = 32'h11111111;
  logic [WIDTH-1:0] y;

  mux2 #(
      .WIDTH(WIDTH)
  ) dut (
      .a  (a),
      .b  (b),
      .sel(sel),
      .y  (y)
  );

  task automatic check_mux(input logic s, input logic [WIDTH-1:0] expected);
    sel = s;
    #1;  // combinational settle
    assert (y === expected)
    else $error("sel=%0b: expected 0x%0h got 0x%0h", s, expected, y);
  endtask

  initial begin
    check_mux(1'b0, 32'h01010101);
    check_mux(1'b1, 32'h11111111);
    $display("[SUCCESS] all checks passed");
    $finish;
  end

endmodule

