module store_unit (
    input  logic [ 2:0] funct3,
    input  logic [ 1:0] addr_offset,
    input  logic [31:0] store_data,
    output logic [ 3:0] write_mask,
    output logic [31:0] write_data
);

  always_comb begin
    write_data = 32'h0;
    write_mask = 4'b0000;
    case (funct3)
      3'b000:  // SB
      case (addr_offset)
        2'b00: begin
          write_data = {24'h0, store_data[7:0]};
          write_mask = 4'b0001;
        end
        2'b01: begin
          write_data = {16'h0, store_data[7:0], 8'h0};
          write_mask = 4'b0010;
        end
        2'b10: begin
          write_data = {8'h0, store_data[7:0], 16'h0};
          write_mask = 4'b0100;
        end
        2'b11: begin
          write_data = {store_data[7:0], 24'h0};
          write_mask = 4'b1000;
        end
        default: begin
          write_data = 32'h0;
          write_mask = 4'b0000;
        end
      endcase
      3'b001:  // SH
      case (addr_offset[1])
        1'b0: begin
          write_data = {16'h0, store_data[15:0]};
          write_mask = 4'b0011;
        end
        1'b1: begin
          write_data = {store_data[15:0], 16'h0};
          write_mask = 4'b1100;
        end
        default: begin
          write_data = 32'h0;
          write_mask = 4'b0000;
        end
      endcase
      3'b010: begin  // SW
        write_data = store_data;
        write_mask = 4'b1111;
      end
      default: begin
        write_data = 32'h0;
        write_mask = 4'b0000;
      end
    endcase
  end

endmodule
