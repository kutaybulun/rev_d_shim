module ad5676_dac_ctrl #(
  parameter ABS_CAL_MAX = 16'd4096 // Maximum absolute calibration value
)(
  input  wire        clk,
  input  wire        resetn,

  output reg         setup_done,

  output reg         cmd_word_rd_en,
  input  wire [31:0] cmd_word,
  input  wire        cmd_buf_empty,

  input  wire        trigger,
  input  wire        ldac_shared,
  output reg         cmd_buf_underflow,
  output reg         unexp_trig,
  output reg         bad_cmd,
  output reg         cal_oob,
  output reg         dac_val_oob,
  
  output reg [119:0] abs_dac_val_concat,

  output reg         n_cs,
  output reg         mosi,
  input  wire        miso,
  input  wire        miso_sck,
  output reg         ldac
);

  // State and command processing registers
  reg [ 2:0] state;
  reg        cmd_finished;
  reg [ 2:0] next_cmd_state;
  // Command word processing bits
  reg        do_ldac;
  reg        wait_for_trigger;
  reg        expect_next;
  // Timer
  reg [24:0] timer;
  // Calibration
  reg signed [15:0] cal_val;
  // DAC control signals
  reg        read_next_dac_word;
  reg        dac_ready;
  reg [ 5:0] dac_update_timer;
  reg [ 2:0] dac_channel;
  wire       last_dac_channel;
  reg [ 4:0] dac_spi_bit;
  reg signed [15:0] first_dac_val_signed;
  reg signed [16:0] first_dac_val_cal_signed;
  reg [15:0] first_dac_val_cal;
  reg signed [15:0] second_dac_val_signed;
  reg signed [16:0] second_dac_val_cal_signed;
  reg [15:0] second_dac_val_cal;
  reg [14:0] abs_dac_val [0:7]; // Stored absolute DAC values for each channel
  reg [ 1:0] dac_load_stage;

  // Internal constants
  localparam DAC_UPDATE_DELAY = 6'd41; // Minimum DAC delay clock cycles (minus 1)

  // States
  localparam INIT = 3'd0; // Initial state
  localparam IDLE = 3'd1; // Idle state, waiting for commands
  localparam DELAY = 3'd2; // Delay state, waiting for timer to expire
  localparam TRIG_WAIT = 3'd3; // Waiting for trigger state
  localparam DAC_WR = 3'd4; // DAC write state
  localparam ERROR = 3'd5; // Error state, invalid command or unexpected condition

  // Command types
  localparam CMD_NO_OP = 2'b00;
  localparam CMD_DAC_WR = 2'b01;
  localparam CMD_SET_CAL = 2'b10;

  localparam LDAC_BIT = 29; // Bit position for DO LDAC in the command word
  localparam TRIG_BIT = 28; // Bit position for TRIGGER WAIT in the command word
  localparam CONT_BIT = 27; // Bit position for CONTINUE in the command word


  //// State machine transitions
  // Current command is finished
  always @* begin
    cmd_finished = (state == IDLE && ~cmd_buf_empty) 
                  || (state == DELAY && timer == 0)
                  || (state == TRIG_WAIT && trigger)
                  || (state == DAC_WR && dac_ready && ~wait_for_trigger && timer == 0);
  end
   // Next state from upcoming command
  always @* begin
    next_cmd_state =  cmd_buf_empty ? expect_next ? ERROR : IDLE : // If buffer is empty, error if expecting next command, otherwise IDLE
                      (cmd_word[31:30] == CMD_NO_OP) ? cmd_word[TRIG_BIT] ? TRIG_WAIT : DELAY : // If command is NO_OP, either wait for trigger or delay depending on TRIG_BIT
                      (cmd_word[31:30] == CMD_DAC_WR) ? DAC_WR : // If command is DAC write, go to DAC_WR state
                      (cmd_word[31:30] == CMD_SET_CAL) ? IDLE : // If command is SET_CAL, go to IDLE
                      ERROR; // If command is not recognized, go to ERROR state
  end
  // State transition logic
  always @(posedge clk) begin
    if (~resetn) state <= INIT; // Reset to initial state
    else if (state == INIT) state <= IDLE; // Transition from INIT to IDLE
    else if (cal_oob) state <= ERROR; // Error if calibration value is out of bounds
    else if (trigger && state != TRIG_WAIT) state <= ERROR; // Error if trigger occurs when not waiting for one
    else if (state == DAC_WR && ldac_shared) state <= ERROR; // Error if global LDAC is asserted while this DAC is writing
    else if (read_next_dac_word && cmd_buf_empty) state <= ERROR; // Error if DAC sample is expected but buffer is empty
    else if (cmd_finished) state <= next_cmd_state; // Transition to state of next command if command is finished
    else if (state == DAC_WR && dac_ready) state <= wait_for_trigger ? TRIG_WAIT : DELAY; // If the DAC write is done, go to the proper wait state
    else if (state == DAC_WR && dac_val_oob) state <= ERROR; // Error if calibrated DAC value is out of bounds
  end
  // Setup done logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) setup_done <= 1'b0; // Reset setup done on reset or error
    else if (state == INIT) setup_done <= 1'b1; // Set setup done when entering INIT state
  end



  //// Command bits processing
  // do_ldac, wait_for_trigger, expect_next logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) begin
      do_ldac <= 1'b0;
      wait_for_trigger <= 1'b0;
      expect_next <= 1'b0;
    end else if (cmd_finished && ~cmd_buf_empty && next_cmd_state != ERROR) begin
      do_ldac <= cmd_word[LDAC_BIT]; // Set do_ldac based on command word
      wait_for_trigger <= cmd_word[TRIG_BIT]; // Set wait_for_trigger based on command word
      expect_next <= cmd_word[CONT_BIT]; // Set expect_next based on command word
    end
  end
  // Command word read enable logic
  always @* begin
    cmd_word_rd_en = state != ERROR && ~cmd_buf_empty && 
                     (read_next_dac_word || cmd_finished);
  end


  //// Timer logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) timer <= 25'd0;
    else if (cmd_finished && next_cmd_state != ERROR) begin
      // If the next command is a delay or DAC write with a delay, load the timer
      if (next_cmd_state == DELAY || (next_cmd_state == DAC_WR && ~cmd_word[TRIG_BIT])) begin
        timer <= cmd_word[24:0]; // Load timer with delay value from command word
      end
    end else if (timer > 0) timer <= timer - 1; // Decrement timer
  end


  //// Errors
  // Unexpected trigger logic
  always @(posedge clk) begin
    if (~resetn) unexp_trig <= 1'b0;
    else if (state != TRIG_WAIT && trigger) unexp_trig <= 1'b1; // Unexpected trigger if triggered while not waiting for one
    else if (state == DAC_WR && ldac_shared) unexp_trig <= 1'b1; // Unexpected trigger if global LDAC is asserted while writing
    
  end
  // Bad command logic
  always @(posedge clk) begin
    if (~resetn) bad_cmd <= 1'b0;
    else if (cmd_finished && ~cmd_buf_empty && next_cmd_state == ERROR) bad_cmd <= 1'b1; // Bad command if next command is parsed as ERROR
  end
  // Command buffer underflow logic
  always @(posedge clk) begin
    if (~resetn) cmd_buf_underflow <= 1'b0;
    else if (((cmd_finished && expect_next) || read_next_dac_word) && cmd_buf_empty) cmd_buf_underflow <= 1'b1; // Underflow if expecting buffer item but buffer is empty
  end
  

  // LDAC activation logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) ldac <= 1'b0;
    else if (do_ldac && cmd_finished) begin
      ldac <= 1'b1; // If do_ldac is set, activate LDAC at the end of the command (except for IDLE)
    end
    else ldac <= 1'b0; // Otherwise, deactivate LDAC
  end
  // Update absolute DAC values concatenation
  always @(posedge clk) begin
    if (~resetn || state == ERROR) abs_dac_val_concat <= 120'd0; // Reset concatenation on reset or error
    else if (ldac) begin
      // Concatenate absolute DAC values when LDAC is asserted
      abs_dac_val_concat <= {abs_dac_val[7], abs_dac_val[6], abs_dac_val[5], 
                             abs_dac_val[4], abs_dac_val[3], abs_dac_val[2], 
                             abs_dac_val[1], abs_dac_val[0]};
    end
  end
      


  //// Calibration
  always @(posedge clk) begin
    if (~resetn) begin
      cal_val <= 16'd0;
      cal_oob <= 1'b0;
    end else if (cmd_finished && next_cmd_state == IDLE && cmd_word[31:30] == CMD_SET_CAL) begin
      if ($signed(cmd_word[15:0]) <= $signed(ABS_CAL_MAX) && $signed(cmd_word[15:0]) >= -$signed(ABS_CAL_MAX)) begin
        cal_val <= cmd_word[15:0]; // Set calibration value if within bounds
      end else begin
        cal_oob <= 1'b1; // Set out-of-bounds flag if calibration value is out of range
      end
    end
  end

  //// DAC control signals
  // DAC channels done
  assign last_dac_channel = &dac_channel; // Last channel is when all bits are set
  // Read next DAC word logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) read_next_dac_word <= 1'b0;
    // If next command is DAC write, immediately read next DAC word (two channels)
    else if (cmd_finished && next_cmd_state == DAC_WR) read_next_dac_word <= 1'b1;
    // If writing to DAC and finished the second channel (every other, but not on ch 7), read the next word (two channels)
    else if (state == DAC_WR && dac_channel[0] && ~last_dac_channel && dac_update_timer == 0) read_next_dac_word <= 1'b1;
    else read_next_dac_word <= 1'b0;
  end
  // DAC word timer logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) dac_update_timer <= 6'd0;
    else if (cmd_finished && next_cmd_state == DAC_WR) dac_update_timer <= DAC_UPDATE_DELAY;
    else if (state == DAC_WR && dac_update_timer == 0 && ~last_dac_channel) dac_update_timer <= DAC_UPDATE_DELAY;
    else if (state == DAC_WR && dac_update_timer > 0) dac_update_timer <= dac_update_timer - 1;
  end
  // DAC ready logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) dac_ready <= 1'b0;
    else if (state == DAC_WR && dac_update_timer == 0 && last_dac_channel) dac_ready <= 1'b1; // Ready when all channels are written
    else dac_ready <= 1'b0; // Not ready otherwise
  end
  // DAC channel logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) dac_channel <= 3'd0;
    else if (cmd_finished && next_cmd_state == DAC_WR) dac_channel <= 3'd0;
    else if (state == DAC_WR && dac_update_timer == 0) dac_channel <= dac_channel + 1; // Increment channel when timer is done
  end
  // DAC value loading logic
  always @(posedge clk) begin
    if (~resetn || state == ERROR) begin
      first_dac_val_signed <= 16'd0;
      first_dac_val_cal_signed <= 17'd0;
      first_dac_val_cal <= 16'd0;
      second_dac_val_signed <= 16'd0;
      second_dac_val_cal_signed <= 17'd0;
      second_dac_val_cal <= 16'd0;
      abs_dac_val[0] <= 15'd0;
      abs_dac_val[1] <= 15'd0;
      abs_dac_val[2] <= 15'd0;
      abs_dac_val[3] <= 15'd0;
      abs_dac_val[4] <= 15'd0;
      abs_dac_val[5] <= 15'd0;
      abs_dac_val[6] <= 15'd0;
      abs_dac_val[7] <= 15'd0;
      dac_load_stage <= 2'b00;
      dac_val_oob <= 1'b0;
    end else 
      case (dac_load_stage)
        2'b00: begin // Initial stage, waiting for the first DAC value to be loaded
          if (read_next_dac_word && ~cmd_buf_empty) begin
            // Reject DAC value of 0xFFFF
            if (cmd_word[15:0] == 16'hFFFF || cmd_word[31:16] == 16'hFFFF) dac_val_oob <= 1'b1;
            else begin
              first_dac_val_signed <= offset_to_signed(cmd_word[15:0]); // Load first DAC value from command word
              second_dac_val_signed <= offset_to_signed(cmd_word[31:16]); // Load second DAC value from command word
              dac_load_stage <= 2'b01; // Move to next stage
            end
          end
        end
        2'b01: begin // Second stage, adding calibration and getting absolute values
          first_dac_val_cal_signed <= first_dac_val_signed + cal_val; // Add calibration to first DAC value
          second_dac_val_cal_signed <= second_dac_val_signed + cal_val; // Add calibration to second DAC value
          abs_dac_val[dac_channel] <= signed_to_abs(first_dac_val_cal_signed); // Convert first DAC value to absolute
          abs_dac_val[dac_channel + 1] <= signed_to_abs(second_dac_val_cal_signed); // Convert second DAC value to absolute
          dac_load_stage <= 2'b10; // Move to final stage
        end
        2'b10: begin // Final conversion stage, converting to offset representation
          // Make sure the calibrated values are within bounds
          if (first_dac_val_cal_signed < -32767 || first_dac_val_cal_signed > 32767 ||
              second_dac_val_cal_signed < -32767 || second_dac_val_cal_signed > 32767) dac_val_oob <= 1'b1;
          else begin
            first_dac_val_cal <= signed_to_offset(first_dac_val_cal_signed);
            second_dac_val_cal <= signed_to_offset(second_dac_val_cal_signed);
            dac_load_stage <= 2'b00; // Conversion is done
          end
        end
      endcase
  end
  // DAC SPI bit logic
  always @(posedge clk) begin
    if (~resetn || state != DAC_WR) dac_spi_bit <= 5'd0;
    else if (state == DAC_WR && dac_load_stage == 2'b10) dac_spi_bit <= 5'd23;
    else if (state == DAC_WR && dac_spi_bit > 0) dac_spi_bit <= dac_spi_bit - 1; // Decrement SPI bit counter
  end
  // SPI MOSI bits
  always @* begin
    // Determine first/second by parity of the channel
    if (state == DAC_WR && ~dac_channel[0]) mosi = first_dac_val_cal[dac_spi_bit];
    else if (state == DAC_WR && dac_channel[0]) mosi = second_dac_val_cal[dac_spi_bit];
    else mosi = 1'b0; // Default to 0 when not writing
  end

  // Convert from offset to signed     
  // Given a 16-bit 0-65535 number, treat 32768 as 0, 0 as -32768, and 65535 as +32767.
  function signed [15:0] offset_to_signed(input [15:0] raw_dac_val);
    begin
      if (raw_dac_val < 32768) begin
        offset_to_signed = raw_dac_val - 32768; // Convert to signed by subtracting 32768
      end else begin
        offset_to_signed = raw_dac_val - 65536; // Convert to signed by subtracting 65536
      end
    end
  endfunction

  // Convert the signed value to absolute value
  function [14:0] signed_to_abs(input signed [15:0] signed_val);
    begin
      if (signed_val < 0) begin
        signed_to_abs = -signed_val; // If negative, take the absolute value
      end else begin
        signed_to_abs = signed_val; // If positive, keep the value as is
      end
    end
  endfunction

  // Convert signed value to offset (0-65535) representation
  function [15:0] signed_to_offset(input signed [15:0] signed_val);
    begin
      if (signed_val < 0) begin
        signed_to_offset = signed_val + 32768; // Convert negative to offset by adding 32768
      end else begin
        signed_to_offset = signed_val + 65536; // Convert positive to offset by adding 65536
      end
    end
  endfunction      

endmodule
