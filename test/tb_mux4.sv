`timescale 1ns / 1ps
module tb_mux4;
  localparam integer WIDTH = 8;

  logic [      1:0] sel;
  logic [WIDTH-1:0] a = 8'b01010101;
  logic [WIDTH-1:0] b = 8'b11111111;
  logic [WIDTH-1:0] c = 8'b00001111;
  logic [WIDTH-1:0] d = 8'b11110000;
  logic [WIDTH-1:0] y;

  mux4 #(
      .WIDTH(WIDTH)
  ) dut (
      .a  (a),
      .b  (b),
      .c  (c),
      .d  (d),
      .sel(sel),
      .y  (y)
  );

  task automatic check_mux(input logic [1:0] s, input logic [WIDTH-1:0] expected);
    sel = s;
    #1;  // combinational settle
    assert (y === expected)
    else $error("sel=%0b: expected 0x%0h got 0x%0h", s, expected, y);
  endtask

  initial begin
    check_mux(2'b00, 8'b01010101);
    check_mux(2'b01, 8'b11111111);
    check_mux(2'b10, 8'b00001111);
    check_mux(2'b11, 8'b11110000);
    $display("[SUCCESS] all checks passed");
    $finish;
  end

endmodule
