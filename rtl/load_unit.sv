module load_unit (
    input  logic [ 2:0] funct3,
    input  logic [ 1:0] byte_offset,
    input  logic [31:0] mem_data,
    output logic [31:0] loaded_value
);

  always_comb begin
    loaded_value = 32'h0;
    case (funct3)
      3'b000:  // LB — signed byte
      case (byte_offset)
        2'b00:   loaded_value = {{24{mem_data[7]}}, mem_data[7:0]};
        2'b01:   loaded_value = {{24{mem_data[15]}}, mem_data[15:8]};
        2'b10:   loaded_value = {{24{mem_data[23]}}, mem_data[23:16]};
        2'b11:   loaded_value = {{24{mem_data[31]}}, mem_data[31:24]};
        default: loaded_value = 32'h0;
      endcase
      3'b001:  // LH — signed halfword
      case (byte_offset[1])
        1'b0: loaded_value = {{16{mem_data[15]}}, mem_data[15:0]};
        1'b1: loaded_value = {{16{mem_data[31]}}, mem_data[31:16]};
        default: loaded_value = 32'h0;
      endcase
      3'b010:  // LW — full word
      loaded_value = mem_data;
      3'b100:  // LBU — unsigned byte
      case (byte_offset)
        2'b00:   loaded_value = {24'h0, mem_data[7:0]};
        2'b01:   loaded_value = {24'h0, mem_data[15:8]};
        2'b10:   loaded_value = {24'h0, mem_data[23:16]};
        2'b11:   loaded_value = {24'h0, mem_data[31:24]};
        default: loaded_value = 32'h0;
      endcase
      3'b101:  // LHU — unsigned halfword
      case (byte_offset[1])
        1'b0: loaded_value = {16'h0, mem_data[15:0]};
        1'b1: loaded_value = {16'h0, mem_data[31:16]};
        default: loaded_value = 32'h0;
      endcase
      default: loaded_value = 32'h0;
    endcase
  end

endmodule
