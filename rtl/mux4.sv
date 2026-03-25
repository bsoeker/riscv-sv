module mux4 #(
    parameter WIDTH = 8
) (
    input logic [WIDTH-1 : 0] a,
    input logic [WIDTH-1 : 0] b,
    input logic [WIDTH-1 : 0] c,
    input logic [WIDTH-1 : 0] d,
    input logic [1:0] sel,
    output logic [WIDTH-1 : 0] y
    
);

  always_comb
    unique case (sel)
      2'b00: y = a;
      2'b01: y = b;
      2'b10: y = c;
      2'b11: y = d;
    endcase

endmodule

