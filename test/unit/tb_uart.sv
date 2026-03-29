`timescale 1ns / 1ps

module uart_tb;

  // ── Parameters ──────────────────────────────────────────
  localparam int CLOCK_FREQ = 50_000_000;
  localparam int BAUD_RATE = 115_200;
  localparam int BAUD_TICKS = CLOCK_FREQ / BAUD_RATE;
  localparam int CLK_PERIOD = 20;  // 50 MHz → 20 ns period

  // ── DUT signals ─────────────────────────────────────────
  logic        clk;
  logic        rst_n;
  logic [ 1:0] addr;
  logic        wr_en;
  logic [31:0] write_data;
  logic [31:0] read_data;
  logic        tx;
  logic        rx;

  // ── DUT instantiation ───────────────────────────────────
  uart #(
      .CLOCK_FREQ(CLOCK_FREQ),
      .BAUD_RATE (BAUD_RATE)
  ) dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .addr      (addr),
      .wr_en     (wr_en),
      .write_data(write_data),
      .read_data (read_data),
      .tx        (tx),
      .rx        (rx)
  );

  // ── Clock generation ────────────────────────────────────
  initial clk = 0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  // ── Helper tasks ─────────────────────────────────────────

  // Write a 32-bit value to a MMIO register
  task automatic mmio_write(input logic [1:0] a, input logic [31:0] data);
    @(posedge clk);
    addr       <= a;
    wr_en      <= 1'b1;
    write_data <= data;
    @(posedge clk);
    wr_en      <= 1'b0;
    addr       <= '0;
    write_data <= '0;
  endtask

  // Read a MMIO register and return value through an output arg
  task automatic mmio_read(input logic [1:0] a, output logic [31:0] data);
    @(posedge clk);
    addr  <= a;
    wr_en <= 1'b0;
    @(posedge clk);
    @(posedge clk);
    data = read_data;  // capture registered output
    addr <= '0;
  endtask

  // Wait for TX to return to IDLE (tx_ready == 1) by polling status register.
  // Gives up after a generous timeout.
  task automatic wait_tx_done;
    logic [31:0] status;
    int          timeout = BAUD_TICKS * 12;  // ~12 baud periods
    do begin
      mmio_read(2'b01, status);
      timeout--;
      if (timeout == 0) begin
        $fatal(1, "TIMEOUT: TX never completed");
      end
    end while (!status[0]);  // bit 0 = tx_ready
  endtask

  // Drive one UART byte onto the rx pin from the testbench side.
  // Uses the same baud rate as the DUT.
  task automatic rx_send_byte(input logic [7:0] data);
    // Start bit
    rx = 1'b0;
    repeat (BAUD_TICKS) @(posedge clk);
    // Data bits (LSB first)
    for (int i = 0; i < 8; i++) begin
      rx = data[i];
      repeat (BAUD_TICKS) @(posedge clk);
    end
    // Stop bit
    rx = 1'b1;
    repeat (BAUD_TICKS) @(posedge clk);
  endtask

  // ── Test sequences ──────────────────────────────────────
  logic [31:0] status;
  logic [31:0] rx_word;
  logic [ 7:0] tx_byte;
  logic [ 7:0] rx_byte;

  initial begin
    // -- Initialise signals
    rst_n      = 1'b0;
    addr       = '0;
    wr_en      = 1'b0;
    write_data = '0;
    rx         = 1'b1;  // idle high

    // -- Release reset after a few cycles
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // ── TEST 1: Status register after reset ─────────────
    $display("TEST 1: Status register after reset");
    mmio_read(2'b01, status);
    assert (status[0] == 1'b1)
    else $fatal(1, "FAIL: tx_ready should be 1 after reset");
    assert (status[1] == 1'b0)
    else $fatal(1, "FAIL: rx_ready should be 0 after reset");
    $display("  PASS");

    // ── TEST 2: TX write and transmission ────────────────
    $display("TEST 2: TX write");
    tx_byte = 8'hA5;
    mmio_write(2'b00, {24'h0, tx_byte});

    // Status should show tx_ready low immediately after write
    mmio_read(2'b01, status);
    assert (status[0] == 1'b0)
    else $fatal(1, "FAIL: tx_ready should be 0 during TX");
    $display("  tx_ready correctly deasserted during TX");

    // Wait for transmission to complete
    wait_tx_done();
    $display("  TX completed, tx_ready reasserted");

    // Verify tx line is idle-high after stop bit
    assert (tx == 1'b1)
    else $fatal(1, "FAIL: tx should be high (idle) after transmission");
    $display("  PASS");

    // ── TEST 3: RX receive ───────────────────────────────
    $display("TEST 3: RX receive");
    rx_byte = 8'h3C;
    rx_send_byte(rx_byte);

    // Check status: rx_ready should now be set
    mmio_read(2'b01, status);
    assert (status[1] == 1'b1)
    else $fatal(1, "FAIL: rx_ready not set after receive");
    $display("  rx_ready correctly asserted");

    // Read received byte
    mmio_read(2'b10, rx_word);
    assert (rx_word[7:0] == rx_byte)
    else $fatal(1, "FAIL: rx_data = 0x%02h, expected 0x%02h", rx_word[7:0], rx_byte);
    $display("  rx_data = 0x%02h (correct)", rx_word[7:0]);

    // After read, rx_ready should clear
    mmio_read(2'b01, status);
    assert (status[1] == 1'b0)
    else $fatal(1, "FAIL: rx_ready should clear after read");
    $display("  rx_ready correctly cleared after read");
    $display("  PASS");

    // ── All tests passed ────────────────────────────────
    $display("All tests PASSED");
    $finish;
  end

endmodule
