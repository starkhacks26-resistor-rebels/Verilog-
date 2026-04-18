//========================================================================
// BusCapture_FSM
//========================================================================
`ifndef BUS_CAPTURE_FSM_V         
`define BUS_CAPTURE_FSM_V         
`include "CircularFIFO.v"          

module BusCapture_FSM
(
  // Clock and Reset
  (* keep=1 *) input  logic        clk,       // main FPGA clock
  (* keep=1 *) input  logic        rst,       // active high reset

  // ADC eval board
  (* keep=1 *) input  logic [17:0] adc_data,  // 18 bit sample from AD7606C-18
  (* keep=1 *) input  logic        adc_dco,   // data clock from ADC, pulses when sample is ready

  // Rubik Pi SPI interface
  (* keep=1 *) input  logic        spi_sclk,  // SPI clock driven by Rubik Pi (master)
  (* keep=1 *) input  logic        spi_cs,    // chip select, active low means Rubik Pi is talking
  (* keep=1 *) input  logic        trigger_in,// Rubik Pi pulls this high to start capture
  (* keep=1 *) output logic        spi_miso,  // FPGA sends data back to Rubik Pi on this pin

  // Haptics output
  (* keep=1 *) output logic        haptic_out,// goes high during CAPTURE state to drive haptic motor

  // Testing
  (* keep=1 *) output logic [1:0]  state      // exposes current FSM state for debugging
);

  //----------------------------------------------------------------------
  // State encodings
  //----------------------------------------------------------------------
  localparam STATE_IDLE    = 2'b00;  // waiting for trigger, FIFO constantly filling
  localparam STATE_CAPTURE = 2'b01;  // trigger received, counting post-trigger samples
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
  logic [17:0] fifo_dout;    // 18 bit word coming out of FIFO, loaded into SPI shift reg

  // Post-trigger sample counter
  localparam POST_TRIG_MAX = 32'd2_000_000; // 2 sec at 1 MSPS = 2 million samples
  logic [31:0] post_trig_count; // counts up each clk cycle while in CAPTURE state
  logic        post_trig_done;  // goes high when count hits POST_TRIG_MAX

  // SPI shift register
  logic [31:0] spi_shift_reg; // holds one 18 bit sample padded to 32, shifts out MSB first
  logic [4:0]  spi_bit_count; // counts 0-31, tracks which bit we are sending right now

  // Synchronizers
  logic [17:0] adc_data_d1, adc_data_sync; // two flop sync: adc_data -> clk domain
  logic        empty_d1, empty_sync;        // two flop sync: fifo_empty -> clk domain

  assign state          = state_reg;                      // expose state register to output port
  assign post_trig_done = (post_trig_count >= POST_TRIG_MAX); // high when 2 sec of post-trigger samples collected
  assign spi_miso       = spi_shift_reg[31];              // always output MSB of shift register to Rubik Pi

  //----------------------------------------------------------------------
  // CircularFIFO instantiation (Dual Clock)
  //----------------------------------------------------------------------
  CircularFIFO fifo0 (
    .wr_clk (clk),          // write side runs on main FPGA clock
    .rd_clk (spi_sclk),     // read side runs on SPI clock from Rubik Pi
    .rst    (rst),          // shared reset
    .din    (adc_data_sync),// synchronized ADC data goes in
    .wr_en  (fifo_wr_en),   // FSM controls when to write
    .rd_en  (fifo_rd_en),   // SPI block controls when to read
    .dout   (fifo_dout),    // 18 bit word comes out when rd_en is high
    .full   (fifo_full),    // high when FIFO is full
    .empty  (fifo_empty)    // high when FIFO is empty, used to end SEND state
  );

  // Synchronizer Logic
  always_ff @(posedge clk) begin
    adc_data_d1   <= adc_data;      // first flop: capture raw ADC data
    adc_data_sync <= adc_data_d1;   // second flop: now stable in clk domain
    empty_d1      <= fifo_empty;    // first flop: capture raw empty flag
    empty_sync    <= empty_d1;      // second flop: now stable in clk domain
  end

  // State Register
  always_ff @(posedge clk) begin
    if (rst) state_reg <= STATE_IDLE;  // reset always goes to IDLE
    else     state_reg <= next_state;  // otherwise advance to next state each cycle
  end

  // Post-trigger counter
  always_ff @(posedge clk) begin
    if (rst)                              post_trig_count <= 32'b0; // reset clears counter
    else if (state_reg == STATE_CAPTURE)  post_trig_count <= post_trig_count + 1; // count up each cycle in CAPTURE
    else                                  post_trig_count <= 32'b0; // any other state resets counter
  end

  //----------------------------------------------------------------------
  // SPI Logic (The "Drain") - Runs on spi_sclk
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk or posedge rst) begin
    if (rst) begin
      spi_shift_reg <= 32'b0;  // clear shift register on reset
      spi_bit_count <= 5'd0;   // clear bit counter on reset
      fifo_rd_en    <= 1'b0;   // stop reading FIFO on reset
    end else if (!spi_cs) begin              // spi_cs low means Rubik Pi is actively talking
      if (spi_bit_count == 5'd0) begin       // bit count 0 means start of a new word
        if (!fifo_empty) begin               // only load if there is data to send
          spi_shift_reg <= {14'b0, fifo_dout}; // load 18 bit sample padded to 32 bits
          fifo_rd_en    <= 1'b1;               // pulse read enable to advance FIFO to next word
          spi_bit_count <= 5'd1;               // move to bit 1, start shifting
        end
      end else begin
        fifo_rd_en <= 1'b0;                    // only pulse rd_en for one cycle then drop it
        if (spi_bit_count == 5'd31)            // finished sending all 32 bits of this word
          spi_bit_count <= 5'd0;               // reset to 0 to load next word on next cycle
        else begin
          spi_shift_reg <= {spi_shift_reg[30:0], 1'b0}; // shift left, MSB goes out on spi_miso
          spi_bit_count <= spi_bit_count + 1;            // advance bit counter
        end
      end
    end else begin                   // spi_cs high means Rubik Pi stopped talking
      spi_bit_count <= 5'd0;         // reset counter ready for next transaction
      fifo_rd_en    <= 1'b0;         // make sure read enable is off
    end
  end

  //----------------------------------------------------------------------
  // Next state logic
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE:    next_state = (!trigger_in) ? STATE_IDLE : STATE_CAPTURE;
      STATE_CAPTURE: next_state = (!post_trig_done) ? STATE_CAPTURE : STATE_SEND;
      STATE_SEND:    next_state = (!empty_sync) ? STATE_SEND : STATE_DONE;
      STATE_DONE:    next_state = STATE_IDLE;
      default:       next_state = STATE_IDLE;
    endcase
  end

  //----------------------------------------------------------------------
  // Output logic 
    case(state_reg)
      STATE_IDLE: begin
        fifo_wr_en = 1'b1;
        haptic_out = 1'b0;
      end
      STATE_CAPTURE: begin
        fifo_wr_en = 1'b1;
        haptic_out = 1'b1;
      end
      STATE_SEND: begin
        fifo_wr_en = 1'b0;
        haptic_out = 1'b0;
      end
      STATE_DONE: begin
        fifo_wr_en = 1'b0;
        haptic_out = 1'b0;
      end
      default: begin
        fifo_wr_en = 1'b0;
        haptic_out = 1'b0;
      end
    endcase

endmodule
`endif