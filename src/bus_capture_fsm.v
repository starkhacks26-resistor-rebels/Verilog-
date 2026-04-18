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

  // Rubik pi interface
  (* keep=1 *) input  logic        spi_sclk,
  (* keep=1 *) input  logic        spi_cs,
  (* keep=1 *) input  logic        trigger_in,
  (* keep=1 *) output logic        spi_miso,

  // Haptics output
  (* keep=1 *) output logic        haptic_out,

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
  logic [11:0] fifo_dout;

  // Post-trigger sample counter
  // at 1 MSPS, 2 seconds = 2,000,000 samples
  // we adjust POST_TRIG_MAX to match the actual sample rate
  localparam POST_TRIG_MAX = 32'd2_000_000;
  logic [31:0] post_trig_count;
  logic        post_trig_done;

  // SPI shift register padded to 16 bits for 8 bit chunking
  logic [15:0] spi_shift_reg;
  logic [3:0]  spi_bit_count;

  // ADC two flop synchronizer
  logic [11:0] adc_data_d1;
  logic [11:0] adc_data_sync;

  // FIFO dout synchronizer for spi_sclk domain
  logic [15:0] fifo_dout_sync;

  assign state          = state_reg;
  assign post_trig_done = (post_trig_count >= POST_TRIG_MAX);
  assign spi_miso       = spi_shift_reg[15]; // MSB first, 16 bits now

  assign state          = state_reg;
  assign post_trig_done = (post_trig_count >= POST_TRIG_MAX);
  assign spi_miso       = spi_shift_reg[11]; // MSB first

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
    .dout  (fifo_dout),
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
  // ADC two flop synchronizer (adc_dco -> clk domain)
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    adc_data_d1   <= adc_data;
    adc_data_sync <= adc_data_d1;
  end

  //----------------------------------------------------------------------
  // FIFO dout synchronizer (clk -> spi_sclk domain)
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk) begin
    fifo_dout_sync <= {4'b0, fifo_dout};
  end

  //----------------------------------------------------------------------
  // SPI shift register
  // 16 bits wide, sends 12 bit sample padded to 16
  // shifts out one bit per spi_sclk rising edge
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk) begin
    if (!spi_cs) begin
      if (spi_bit_count == 4'd0) begin
        spi_shift_reg <= fifo_dout_sync;
        spi_bit_count <= 4'd1;
      end else if (spi_bit_count == 4'd15) begin
        spi_bit_count <= 4'd0;
      end else begin
        spi_shift_reg <= {spi_shift_reg[14:0], 1'b0};
        spi_bit_count <= spi_bit_count + 1;
      end
    end
  end

  //----------------------------------------------------------------------
  // Next state logic
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE:    next_state = (!trigger_in)     ? STATE_IDLE    : STATE_CAPTURE;
      STATE_CAPTURE: next_state = (!post_trig_done) ? STATE_CAPTURE : STATE_SEND;
      STATE_SEND:    next_state = (!fifo_empty)     ? STATE_SEND    : STATE_DONE;
      STATE_DONE:    next_state = STATE_IDLE; 
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
        haptic_out   = 1'b0;
      end
      STATE_CAPTURE: begin
        fifo_wr_en   = 1'b1;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b0;
        haptic_out   = 1'b1;
      end
      STATE_SEND: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b1;
        capture_done = 1'b0;
        haptic_out   = 1'b0;
      end
      STATE_DONE: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b1;
        haptic_out   = 1'b0;
      end
      default: begin
        fifo_wr_en   = 1'b0;
        fifo_rd_en   = 1'b0;
        capture_done = 1'b0;
        haptic_out   = 1'b0;
      end
    endcase
  end

endmodule
`endif /* BUS_CAPTURE_FSM_V */