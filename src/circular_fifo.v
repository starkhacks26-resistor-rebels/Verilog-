//========================================================================
// CircularFIFO (Dual-Clock Version)
//========================================================================
`ifndef CIRCULAR_FIFO_V
`define CIRCULAR_FIFO_V

module CircularFIFO
(
  input  logic        wr_clk,   // Connect to clk (250MHz)
  input  logic        rd_clk,   // Connect to spi_sclk (50MHz)
  input  logic        rst,
  input  logic [17:0] din,
  input  logic        wr_en,
  input  logic        rd_en,
  output logic [17:0] dout,
  output logic        full,
  output logic        empty
);

  // Re-generate this IP in Vivado with "Independent Clocks"
  fifo_generator_0 fifo_inst (
    .wr_clk (wr_clk),
    .rd_clk (rd_clk),
    .rst    (rst),
    .din    (din),
    .wr_en  (wr_en),
    .rd_en  (rd_en),
    .dout   (dout),
    .full   (full),
    .empty  (empty)
  );

endmodule
`endif