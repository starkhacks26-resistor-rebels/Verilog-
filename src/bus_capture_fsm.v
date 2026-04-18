//========================================================================
// BusCapture_FSM - FULL INTEGRATED VERSION FOR KR260
//========================================================================
`ifndef BUS_CAPTURE_FSM_V
`define BUS_CAPTURE_FSM_V
`include "circular_fifo.v"

module BusCapture_FSM
(
  // Clock and Reset
  (* keep=1 *) input  logic        clk,        // Internal 250MHz PL Clock
  (* keep=1 *) input  logic        rst,        // Active high reset

  // ADC eval board (16-bit Parallel Mode)
  (* keep=1 *) input  logic [15:0] adc_data,   // DB0-DB15 from PMODs
  (* keep=1 *) input  logic        adc_dco,    // Connected to BUSY pin

  // Rubik Pi SPI interface
  (* keep=1 *) input  logic        spi_sclk,   
  (* keep=1 *) input  logic        spi_cs,     
  (* keep=1 *) input  logic        spi_mosi,   
  (* keep=1 *) output logic        spi_miso,   

  // Haptics output
  (* keep=1 *) output logic        haptic_out, 

  // Testing
  (* keep=1 *) output logic [1:0]  state       
);

  //----------------------------------------------------------------------
  // State Encodings (Restored Original Style)
  //----------------------------------------------------------------------
  localparam STATE_IDLE    = 2'b00; 
  localparam STATE_CAPTURE = 2'b01; 
  localparam STATE_SEND    = 2'b10; 
  localparam STATE_DONE    = 2'b11; 

  logic [1:0]  state_reg, next_state;

  //----------------------------------------------------------------------
  // Internal Signals
  //----------------------------------------------------------------------
  logic        fifo_wr_en;   
  logic        fifo_rd_en;   
  logic        fifo_empty;   
  logic [15:0] fifo_dout;

  localparam POST_TRIG_MAX = 32'd2_000_000; 
  logic [31:0] post_trig_count;
  logic        post_trig_done;

  logic [31:0] spi_shift_reg; 
  logic [4:0]  spi_bit_count; 
  logic [15:0] spi_rx_shift, threshold_reg;
  logic [4:0]  spi_rx_count;
  logic        threshold_locked;

  logic [15:0] adc_data_sync;
  logic        dco_sync_0, dco_sync_1;
  logic        empty_sync;
  logic        adc_ready_pulse; 
  logic        trigger_internal;

  // Assignments
  assign state            = state_reg;
  assign post_trig_done   = (post_trig_count >= POST_TRIG_MAX);
  assign spi_miso         = spi_shift_reg[31];
  assign trigger_internal = (adc_data_sync >= threshold_reg);

  //----------------------------------------------------------------------
  // Synchronizers & Falling Edge Detector (KR260 FIX)
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    adc_data_sync   <= adc_data;     
    dco_sync_0      <= adc_dco;      
    dco_sync_1      <= dco_sync_0;   
    empty_sync      <= fifo_empty;   
  end

  assign adc_ready_pulse = (dco_sync_1 && !dco_sync_0);

  //----------------------------------------------------------------------
  // CircularFIFO Instantiation
  //----------------------------------------------------------------------
  CircularFIFO fifo0 (
    .wr_clk (clk),
    .rd_clk (spi_sclk),
    .rst    (rst),
    .din    (adc_data_sync),
    .wr_en  (fifo_wr_en && adc_ready_pulse), // Restored original logic + pulse fix
    .rd_en  (fifo_rd_en),
    .dout   (fifo_dout),
    .full   (),
    .empty  (fifo_empty)
  );

  //----------------------------------------------------------------------
  // State Register and Sample Counter
  //----------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      state_reg <= STATE_IDLE;
      post_trig_count <= 32'b0;
    end else begin
      state_reg <= next_state;
      if (state_reg == STATE_CAPTURE && adc_ready_pulse)
        post_trig_count <= post_trig_count + 1;
      else if (state_reg != STATE_CAPTURE)
        post_trig_count <= 32'b0;
    end
  end

  //----------------------------------------------------------------------
  // Next State Logic (Restored Original Logic)
  //----------------------------------------------------------------------
  always_comb begin
    case(state_reg)
      STATE_IDLE:    next_state = (!trigger_internal) ? STATE_IDLE    : STATE_CAPTURE;
      STATE_CAPTURE: next_state = (!post_trig_done)   ? STATE_CAPTURE : STATE_SEND;
      STATE_SEND:    next_state = (!empty_sync)       ? STATE_SEND    : STATE_DONE;
      STATE_DONE:    next_state = STATE_IDLE;
      default:       next_state = STATE_IDLE;
    endcase
  end

  //----------------------------------------------------------------------
  // Output Logic (RESTORED ORIGINAL BLOCK)
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

  //----------------------------------------------------------------------
  // SPI Block (Restored SPI Logic)
  //----------------------------------------------------------------------
  always_ff @(posedge spi_sclk or posedge rst) begin
    if (rst) begin
      spi_rx_shift     <= 16'b0;
      spi_rx_count     <= 5'd0;
      threshold_reg    <= 16'b0;
      threshold_locked <= 1'b0;
      spi_shift_reg    <= 32'b0;
      spi_bit_count    <= 5'd0;
      fifo_rd_en       <= 1'b0;
    end else if (!spi_cs) begin
      if (!threshold_locked) begin
        spi_rx_shift <= {spi_rx_shift[14:0], spi_mosi};
        if (spi_rx_count == 5'd15) begin
          threshold_reg    <= {spi_rx_shift[14:0], spi_mosi};
          threshold_locked <= 1'b1;
          spi_rx_count     <= 5'd0;
        end else spi_rx_count <= spi_rx_count + 1;
      end else begin
        if (spi_bit_count == 5'd0) begin
          if (!fifo_empty) begin
            spi_shift_reg <= {16'b0, fifo_dout}; 
            fifo_rd_en    <= 1'b1;
            spi_bit_count <= 5'd1;
          end
        end else begin
          fifo_rd_en <= 1'b0;
          if (spi_bit_count == 5'd31) spi_bit_count <= 5'd0;
          else begin
            spi_shift_reg <= {spi_shift_reg[30:0], 1'b0};
            spi_bit_count <= spi_bit_count + 1;
          end
        end
      end
    end else begin
      spi_bit_count <= 5'd0;
      fifo_rd_en    <= 1'b0;
    end
  end

endmodule
`endif