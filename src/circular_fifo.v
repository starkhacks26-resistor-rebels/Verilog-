`ifndef CIRCULAR_FIFO_V
`define CIRCULAR_FIFO_V

module CircularFIFO
(
  (* keep=1 *) input  logic        clk,
  (* keep=1 *) input  logic        rst,
  (* keep=1 *) input  logic [11:0] din,
  (* keep=1 *) input  logic        wr_en,
  (* keep=1 *) input  logic        rd_en,
  (* keep=1 *) output logic [11:0] dout,
  (* keep=1 *) output logic        full,
  (* keep=1 *) output logic        empty
);

  fifo_generator_0 fifo_inst
  (
    .clk   (clk),
    .srst  (rst),
    .din   (din),
    .wr_en (wr_en),
    .rd_en (rd_en),
    .dout  (dout),
    .full  (full),
    .empty (empty)
  );

endmodule
`endif