`ifndef CIRCULAR_FIFO_V
`define CIRCULAR_FIFO_V

module CircularFIFO
(
  (* keep=1 *) input  logic        wr_clk,  // write clock, main FPGA clock
  (* keep=1 *) input  logic        rd_clk,  // read clock, SPI clock from Rubik Pi
  (* keep=1 *) input  logic        rst,
  (* keep=1 *) input  logic [15:0] din,     // 16 bit data in
  (* keep=1 *) input  logic        wr_en,
  (* keep=1 *) input  logic        rd_en,
  (* keep=1 *) output logic [15:0] dout,    // 16 bit data out
  (* keep=1 *) output logic        full,
  (* keep=1 *) output logic        empty
);

  fifo_generator_0 fifo_inst
  (
    .wr_clk (wr_clk),
    .rd_clk (rd_clk),
    .srst   (rst),
    .din    (din),
    .wr_en  (wr_en),
    .rd_en  (rd_en),
    .dout   (dout),
    .full   (full),
    .empty  (empty)
  );

endmodule
`endif