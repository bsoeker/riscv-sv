module uart #(
    parameter int CLOCK_FREQ = 50_000_000,  // arbitrary value for now
    parameter int BAUD_RATE  = 115_200
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [ 1:0] addr,
    input  logic        wr_en,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic        tx,
    input  logic        rx
);

  localparam int BAUD_TICKS = CLOCK_FREQ / BAUD_RATE;
  localparam int HALF_BAUD_TICKS = BAUD_TICKS / 2;

  // ── TX FSM ────────────────────────────────────────────
  typedef enum logic [1:0] {
    TX_IDLE  = 2'b00,
    TX_START = 2'b01,
    TX_DATA  = 2'b10,
    TX_STOP  = 2'b11
  } tx_state_e;

  // ── RX FSM ────────────────────────────────────────────
  typedef enum logic [1:0] {
    RX_IDLE  = 2'b00,
    RX_START = 2'b01,
    RX_DATA  = 2'b10,
    RX_STOP  = 2'b11
  } rx_state_e;

  tx_state_e                          tx_state;
  rx_state_e                          rx_state;

  // ── TX signals ────────────────────────────────────────
  logic      [                   7:0] tx_shift;
  logic      [                   2:0] tx_bit_index;
  logic      [$clog2(BAUD_TICKS)-1:0] tx_baud_counter;
  logic                               tx_ready;
  logic                               uart_wr_en;

  // ── RX signals ────────────────────────────────────────
  logic      [                   7:0] rx_shift;
  logic      [                   2:0] rx_bit_index;
  logic      [$clog2(BAUD_TICKS)-1:0] rx_baud_counter;
  logic                               rx_data_valid;
  logic      [                   7:0] rx_data;
  logic                               rx_ready;
  logic      [                   7:0] rx_buffer;

  // ── RX two-ff synchronizer ──────────────────────────
  logic rx_sync0, rx_sync1;
  always_ff @(posedge clk) begin
    rx_sync0 <= rx;
    rx_sync1 <= rx_sync0;
  end

  // ── TX combinational signals ──────────────────────────
  assign tx_ready = (tx_state == TX_IDLE);
  assign uart_wr_en = wr_en && (addr == 2'b00) && tx_ready;

  assign tx = (tx_state == TX_IDLE)  ? 1'b1 :
              (tx_state == TX_START) ? 1'b0 :
              (tx_state == TX_STOP)  ? 1'b1 :
              tx_shift[0];

  // ── TX FSM ────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      tx_state        <= TX_IDLE;
      tx_baud_counter <= '0;
      tx_bit_index    <= '0;
      tx_shift        <= '0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          if (uart_wr_en) begin
            tx_shift        <= write_data[7:0];
            tx_baud_counter <= '0;
            tx_state        <= TX_START;
          end
        end

        TX_START: begin
          if (tx_baud_counter == BAUD_TICKS - 1) begin
            tx_baud_counter <= '0;
            tx_state        <= TX_DATA;
          end else begin
            tx_baud_counter <= tx_baud_counter + 1;
          end
        end

        TX_DATA: begin
          if (tx_baud_counter == BAUD_TICKS - 1) begin
            tx_baud_counter <= '0;
            tx_shift        <= {1'b0, tx_shift[7:1]};
            if (tx_bit_index == 3'h7) begin
              tx_bit_index <= '0;
              tx_state     <= TX_STOP;
            end else begin
              tx_bit_index <= tx_bit_index + 1;
            end
          end else begin
            tx_baud_counter <= tx_baud_counter + 1;
          end
        end

        TX_STOP: begin
          if (tx_baud_counter == BAUD_TICKS - 1) begin
            tx_baud_counter <= '0;
            tx_state        <= TX_IDLE;
          end else begin
            tx_baud_counter <= tx_baud_counter + 1;
          end
        end

        default: tx_state <= TX_IDLE;
      endcase
    end
  end

  // ── RX FSM ────────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_state        <= RX_IDLE;
      rx_baud_counter <= '0;
      rx_bit_index    <= '0;
      rx_shift        <= '0;
      rx_data_valid   <= 1'b0;
      rx_data         <= '0;
    end else begin
      rx_data_valid <= 1'b0;

      case (rx_state)
        RX_IDLE: begin
          if (!rx_sync1) begin
            rx_baud_counter <= '0;
            rx_state        <= RX_START;
          end
        end

        RX_START: begin
          if (rx_baud_counter == HALF_BAUD_TICKS - 1) begin
            rx_baud_counter <= HALF_BAUD_TICKS;  // pre-load to center bit 0
            if (!rx_sync1) begin
              rx_state <= RX_DATA;
            end else begin
              rx_state <= RX_IDLE;
            end
          end else begin
            rx_baud_counter <= rx_baud_counter + 1;
          end
        end

        RX_DATA: begin
          if (rx_baud_counter == BAUD_TICKS - 1) begin
            rx_baud_counter        <= '0;
            rx_shift[rx_bit_index] <= rx_sync1;
            if (rx_bit_index == 3'h7) begin
              rx_bit_index <= '0;
              rx_state     <= RX_STOP;
            end else begin
              rx_bit_index <= rx_bit_index + 1;
            end
          end else begin
            rx_baud_counter <= rx_baud_counter + 1;
          end
        end

        RX_STOP: begin
          if (rx_baud_counter == BAUD_TICKS - 1) begin
            rx_baud_counter <= '0;
            if (rx_sync1) begin
              rx_data       <= rx_shift;
              rx_data_valid <= 1'b1;
            end
            rx_state <= RX_IDLE;
          end else begin
            rx_baud_counter <= rx_baud_counter + 1;
          end
        end

        default: rx_state <= RX_IDLE;
      endcase
    end
  end

  // ── RX buffer ─────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_buffer <= '0;
      rx_ready  <= 1'b0;
    end else begin
      if (rx_data_valid) begin
        rx_buffer <= rx_data;
        rx_ready  <= 1'b1;
      end

      // Software reads RX data register — clear rx_ready
      if (!wr_en && addr == 2'b10) begin
        rx_ready <= 1'b0;
      end
    end
  end

  // ── MMIO read ─────────────────────────────────────────
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      read_data <= 32'h0;
    end else begin
      case (addr)
        2'b00:   read_data <= 32'h0;  // Not meant for reading so we return 0s (meant for Tx)
        2'b01:   read_data <= {30'h0, rx_ready, tx_ready};
        2'b10:   read_data <= {24'h0, rx_buffer};
        default: read_data <= 32'h0;
      endcase
    end
  end

endmodule
