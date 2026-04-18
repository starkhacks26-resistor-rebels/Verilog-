//========================================================================
// BusCapture_FSM
//========================================================================
`ifndef BUS_CAPTURE_FSM_V
`define BUS_CAPTURE_FSM_V
`include "CircularFIFO.v"

module BusCapture_FSM
(
  // Clock and Reset
  (* keep=1 *) input  logic        clk,        // main FPGA clock
  (* keep=1 *) input  logic        rst,        // active high reset

  // ADC eval board
  (* keep=1 *) input  logic [15:0] adc_data,   // 16 bit sample from AD7606C-18
  (* keep=1 *) input  logic        adc_dco,    // data clock from ADC, pulses when sample is ready

  // Rubik Pi SPI interface
  (* keep=1 *) input  logic        spi_sclk,   // SPI clock driven by Rubik Pi (master)
  (* keep=1 *) input  logic        spi_cs,     // chip select, active low means Rubik Pi is talking
  (* keep=1 *) input  logic        spi_mosi,   // receives threshold from Rubik Pi at startup
  (* keep=1 *) output logic        spi_miso,   // FPGA sends captured data back to Rubik Pi

  // Haptics output
  (* keep=1 *) output logic        haptic_out, // goes high during CAPTURE state to drive haptic motor

  // Testing
  (* keep=1 *) output logic [1:0]  state       // exposes current FSM state for debugging
);

  //----------------------------------------------------------------------
  // State encodings
  //----------------------------------------------------------------------
  localparam STATE_IDLE    = 2'b00;  // waiting for threshold crossing, FIFO constantly filling
  localparam STATE_CAPTURE = 2'b01;  // threshold crossed, counting post-trigger samples
  localparam STATE_SEND    = 2'b10;  // draining FIFO out to Rubik Pi over SPI
  localparam STATE_DONE    = 2'b11;  // transfer complete, single cycle then back to IDLE

  //----------------------------------------------------------------------
  // Internal signals
  //----------------------------------------------------------------------
  logic [1:0]  next_state;   // combinational next state, fed into state register
  logic [1:0]  state_reg;    // registered current state, output drives state port

  // FIFO control
  logic        fifo_wr_en;   // write enable, high in IDLE and CAPTURE to keep filling
  logic        fifo_rd_en;   // read enable, driven by SPI block when shifting out a word
  logic        fifo_full;    // FIFO full flag from IP, not used in FSM but available
  logic        fifo_empty;   // FIFO empty flag, used to detect end of SEND state
  logic [15:0] fifo_dout;    // 16 bit word coming out of FIFO, loaded into SPI shift reg

  // Post-trigger sample counter
  localparam POST_TRIG_MAX = 32'd2_000_000; // 2 sec at 1 MSPS = 2 million samples
  logic [31:0] post_trig_count; // counts up each clk cycle while in CAPTURE state
  logic        post_trig_done;  // goes high when count hits POST_TRIG_MAX

  // SPI TX shift register (sending captured data out)
  logic [31:0] spi_shift_reg;   // holds one 16 bit sample padded to 32, shifts out MSB first
  logic [4:0]  spi_bit_count;   // counts 0-31, tracks which bit we are sending right now

  // SPI RX shift register (receiving threshold from Rubik Pi)
  logic [15:0] spi_rx_shift;    // shifts in incoming threshold bits MSB first
  logic [4:0]  spi_rx_count;    // counts incoming bits, latches at 15
  logic        threshold_locked; // goes high after threshold received, ignores further MOSI

  // Threshold register and internal trigger
  logic [15:0] threshold_reg;    // stores 16 bit threshold value sent by Rubik Pi at startup
  logic        trigger_internal; // fires when ADC sample crosses threshold

  // Synchronizers
  logic [15:0] adc_data_d1, adc_data_sync; // 16 bit two flop sync adc_data -> clk domain
  logic        empty_d1, empty_sync;        // two flop sync: fifo_empty -> clk domain

  assign state            = state_reg;
  assign post_trig_done   = (post_trig_count >= POST_TRIG_MAX); // high when 2 sec post-trigger collected
  assign spi_miso         = spi_shift_reg[31];                   // always output MSB to Rubik Pi
  assign trigger_internal = (adc_data_sync >= threshold_reg);    // fires when sample crosses threshold

  //----------------------------------------------------------------------
  // CircularFIFO instantiation (Dual Clock)
  //----------------------------------------------------------------------
  CircularFIFO fifo0 (
    .wr_clk (clk),           // write side runs on main FPGA clock
    .rd_clk (spi_sclk),      // read side runs on SPI clock from Rubik Pi
    .rst    (rst),           // shared reset
    .din    (adc_data_sync), // synchronized 16 bit ADC data goes in
    .wr_en  (fifo_wr_en),    // FSM controls when to write
    .rd_en  (fifo_rd_en),    // SPI block controls when to read
    .dout   (fifo_dout),     // 16 bit word comes out when rd_en is high
    .full   (fifo_full),     // high when FIFO is full
    .empty  (fifo_empty)     // high when FIFO is empty, used to end SEND state
  );

  //----------------------------------------------------------------------
  // ADC and empty flag synchronizers
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    adc_data_d1   <= adc_data;    // first flop: capture raw ADC data
    adc_data_sync <= adc_data_d1; // second flop: now stable in clk domain
    empty_d1      <= fifo_empty;  // first flop: capture raw empty flag
    empty_sync    <= empty_d1;    // second flop: now stable in clk domain
  end

  //----------------------------------------------------------------------
  // State register
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) state_reg <= STATE_IDLE; // reset always goes to IDLE
    else     state_reg <= next_state; // otherwise advance to next state each cycle
  end

  //----------------------------------------------------------------------
  // Post-trigger counter
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst)                             post_trig_count <= 32'b0;               // reset clears counter
    else if (state_reg == STATE_CAPTURE) post_trig_count <= post_trig_count + 1; // count up each cycle in CAPTURE
    else                                 post_trig_count <= 32'b0;               // any other state resets counter
  end

  //----------------------------------------------------------------------
  // SPI RX block - receives 16 bit threshold from Rubik Pi once at startup
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk or posedge rst) begin
    if (rst) begin
      spi_rx_shift     <= 16'b0;  // clear RX shift register on reset
      spi_rx_count     <= 5'd0;   // clear RX bit counter on reset
      threshold_reg    <= 16'b0;  // clear threshold on reset
      threshold_locked <= 1'b0;   // unlock so next startup can receive threshold
    end else if (!spi_cs && !threshold_locked) begin   // only accept if not yet locked
      spi_rx_shift <= {spi_rx_shift[14:0], spi_mosi};  // shift in one bit MSB first
      spi_rx_count <= spi_rx_count + 1;                // increment bit counter
      if (spi_rx_count == 5'd15) begin                 // received all 16 bits
        threshold_reg    <= {spi_rx_shift[14:0], spi_mosi}; // latch final value
        threshold_locked <= 1'b1;                      // lock forever until rst
        spi_rx_count     <= 5'd0;                      // reset counter
      end
    end
  end

  //----------------------------------------------------------------------
  // SPI TX block - streams captured FIFO data back to Rubik Pi
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk or posedge rst) begin
    if (rst) begin
      spi_shift_reg <= 32'b0;  // clear shift register on reset
      spi_bit_count <= 5'd0;   // clear bit counter on reset
      fifo_rd_en    <= 1'b0;   // stop reading FIFO on reset
    end else if (!spi_cs && threshold_locked) begin  // only send after threshold is set
      if (spi_bit_count == 5'd0) begin               // start of a new word
        if (!fifo_empty) begin                        // only load if data available
          spi_shift_reg <= {16'b0, fifo_dout};        // 16 bit padding + 16 bit sample = 32 bits
          fifo_rd_en    <= 1'b1;                      // pulse read enable to advance FIFO
          spi_bit_count <= 5'd1;                      // start shifting
        end
      end else begin
        fifo_rd_en <= 1'b0;                              // drop rd_en after one cycle
        if (spi_bit_count == 5'd31)                      // finished all 32 bits of this word
          spi_bit_count <= 5'd0;                         // reset to load next word
        else begin
          spi_shift_reg <= {spi_shift_reg[30:0], 1'b0};  // shift left, MSB goes out on spi_miso
          spi_bit_count <= spi_bit_count + 1;             // advance bit counter
        end
      end
    end else begin
      spi_bit_count <= 5'd0;  // reset counter when CS goes high
      fifo_rd_en    <= 1'b0;  // make sure read enable is off
    end
  end

  //----------------------------------------------------------------------
  // Next state logic
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE:    next_state = (!trigger_internal) ? STATE_IDLE    : STATE_CAPTURE;
      STATE_CAPTURE: next_state = (!post_trig_done)   ? STATE_CAPTURE : STATE_SEND;
      STATE_SEND:    next_state = (!empty_sync)        ? STATE_SEND    : STATE_DONE;
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
        fifo_wr_en = 1'b1;  // keep filling FIFO with ADC data
        haptic_out = 1'b0;
      end
      STATE_CAPTURE: begin
        fifo_wr_en = 1'b1;  // keep writing post-trigger samples
        haptic_out = 1'b1;  // haptics on during capture
      end
      STATE_SEND: begin
        fifo_wr_en = 1'b0;  // stop writing, drain FIFO over SPI
        haptic_out = 1'b0;
      end
      STATE_DONE: begin
        fifo_wr_en = 1'b0;  // single cycle passthrough back to IDLE
        haptic_out = 1'b0;
      end
      default: begin
        fifo_wr_en = 1'b0;
        haptic_out = 1'b0;
      end
    endcase
  end

endmodule
`endif /* BUS_CAPTURE_FSM_V */