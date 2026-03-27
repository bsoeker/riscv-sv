module mux2 #(
    parameter WIDTH = 32
) (
    input logic [WIDTH-1 : 0] a,
    input logic [WIDTH-1 : 0] b,
    input logic sel,
    output logic [WIDTH-1 : 0] y

);

  always_comb
    unique case (sel)
      2'b00: y = a;
      2'b01: y = b;
    endcase

endmodule


