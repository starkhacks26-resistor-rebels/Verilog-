//========================================================================
// BusCapture_FSM
//========================================================================
`ifndef BUS_CAPTURE_FSM_V
`define BUS_CAPTURE_FSM_V
`include "CircularFIFO.v"

module BusCapture_FSM
(
  // Clock and Reset
  (* keep=1 *) input  logic        clk,
  (* keep=1 *) input  logic        rst,

  // ADC eval board
  (* keep=1 *) input  logic [11:0] adc_data,
  (* keep=1 *) input  logic        adc_dco,

  // ESP32 interface
  (* keep=1 *) input  logic        trigger_in,
  (* keep=1 *) input  logic        esp32_ready,
  (* keep=1 *) output logic        capture_done,
  (* keep=1 *) output logic [11:0] data_out,

  // Testing
  (* keep=1 *) output logic [1:0]  state
);

  //----------------------------------------------------------------------
  // State encodings
  //----------------------------------------------------------------------
  localparam STATE_IDLE    = 2'b00;
  localparam STATE_CAPTURE = 2'b01;
  localparam STATE_SEND    = 2'b10;
  localparam STATE_DONE    = 2'b11;

  //----------------------------------------------------------------------
  // Internal signals
  //----------------------------------------------------------------------
  logic [1:0]  next_state;
  logic [1:0]  state_reg;

  // FIFO control
  logic        fifo_wr_en;
  logic        fifo_rd_en;
  logic        fifo_full;
  logic        fifo_empty;

  // Post-trigger sample counter
  // at 1 MSPS, 2 seconds = 2,000,000 samples
  // we adjust POST_TRIG_MAX to match the actual sample rate
  localparam POST_TRIG_MAX = 32'd2_000_000;
  logic [31:0] post_trig_count;
  logic        post_trig_done;

  assign state         = state_reg;
  assign post_trig_done = (post_trig_count >= POST_TRIG_MAX);

  //----------------------------------------------------------------------
  // CircularFIFO instantiation
  //----------------------------------------------------------------------
  CircularFIFO fifo0
  (
    .clk   (clk),
    .rst   (rst),
    .din   (adc_data),
    .wr_en (fifo_wr_en),
    .rd_en (fifo_rd_en),
    .dout  (data_out),
    .full  (fifo_full),
    .empty (fifo_empty)
  );

  //----------------------------------------------------------------------
  // State register
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst)
      state_reg <= STATE_IDLE;
    else
      state_reg <= next_state;
  end

  //----------------------------------------------------------------------
  // Post-trigger counter
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst)
      post_trig_count <= 32'b0;
    else if (state_reg == STATE_CAPTURE)
      post_trig_count <= post_trig_count + 1;
    else
      post_trig_count <= 32'b0;
  end

  //----------------------------------------------------------------------
  // Next state logic
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE:    next_state = (!trigger_in)     ? STATE_IDLE    : STATE_CAPTURE;
      STATE_CAPTURE: next_state = (!post_trig_done) ? STATE_CAPTURE : STATE_SEND;
      STATE_SEND:    next_state = (!fifo_empty)     ? STATE_SEND    : STATE_DONE;
      STATE_DONE:    next_state = (!esp32_ready)    ? STATE_DONE    : STATE_IDLE;
      default:       next_state = STATE_IDLE;
    endcase
  end

  //----------------------------------------------------------------------
  // Output logic
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE: begin
        fifo_wr_en   = 1'b1;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b0;
      end
      STATE_CAPTURE: begin
        fifo_wr_en   = 1'b1;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b0;
      end
      STATE_SEND: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b1;
        capture_done = 1'b0;
      end
      STATE_DONE: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b1;
      end
      default: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b0;
      end
    endcase
  end

endmodule
`endif /* BUS_CAPTURE_FSM_V */