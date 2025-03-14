`timescale 1 ns / 1 ps

module hw_manager #(
  // Delays for the various timeouts, default to 1 second at 250 MHz
  parameter integer POWERON_WAIT   = 250000000, // Delay after releasing "shutdown_force" and "n_shutdown_rst"
  parameter integer BUF_LOAD_WAIT  = 250000000, // Full buffer load from DMA after "dma_en" is set
  parameter integer SPI_START_WAIT = 250000000, // SPI start after "spi_en" is set
  parameter integer SPI_STOP_WAIT  = 250000000  // SPI stop after "spi_en" is cleared
)
(
  input   wire          clk,
  input   wire          rst,

  // Inputs
  input   wire          sys_en,         // System enable
  input   wire          dac_buf_full,   // DAC buffer full
  input   wire          spi_running,    // SPI running
  input   wire          ext_shutdown,   // External shutdown
  input   wire          shutdown_sense, // Shutdown sense
  input   wire  [ 2:0]  sense_num,      // Shutdown sense number
  input   wire  [ 7:0]  over_thresh,    // Over threshold (per board)
  input   wire  [ 7:0]  dac_empty_read, // DAC empty read (per board)
  input   wire  [ 7:0]  adc_full_write, // ADC full write (per board)
  input   wire  [ 7:0]  premat_trig,    // Premature trigger (per board)
  input   wire  [ 7:0]  premat_dac_div, // Premature DAC division (per board)
  input   wire  [ 7:0]  premat_adc_div, // Premature ADC division (per board)

  // Outputs
  output  reg           sys_rst,        // System reset
  output  reg           dma_en,         // DMA enable
  output  reg           spi_en,         // SPI subsystem enable
  output  reg           trig_en,        // Trigger enable
  output  reg           shutdown_force, // Shutdown force
  output  reg           n_shutdown_rst, // Shutdown reset (negated)
  output  wire  [31:0]  status_word,    // Status - Status word
  output  reg           ps_interrupt    // Interrupt signal
);

  // Internal signals
  reg [3:0]  state;       // State machine state
  reg [31:0] timer;       // Timer for various timeouts
  reg [2:0]  board_num;   // Status - Board number (if applicable)
  reg [24:0] status_code; // Status - Status code

  // Concatenated status word
  assign status_word = {board_num, status_code, state};

  // State encoding
  localparam  IDLE      = 4'd1,
              POWERON   = 4'd2,
              START_DMA = 4'd3,
              START_SPI = 4'd4,
              RUNNING   = 4'd5,
              HALTED    = 4'd6;

  // Status codes
  localparam  STATUS_OK                   = 25'h1,
              STATUS_PS_SHUTDOWN          = 25'h2,
              STATUS_DAC_BUF_FILL_TIMEOUT = 25'h3,
              STATUS_SPI_START_TIMEOUT    = 25'h4,
              STATUS_OVER_THRESH          = 25'h5,
              STATUS_SHUTDOWN_SENSE       = 25'h6,
              STATUS_EXT_SHUTDOWN         = 25'h7,
              STATUS_DAC_EMPTY_READ       = 25'h8,
              STATUS_ADC_FULL_WRITE       = 25'h9,
              STATUS_PREMAT_TRIG          = 25'hA,
              STATUS_PREMAT_DAC_DIV       = 25'hB,
              STATUS_PREMAT_ADC_DIV       = 25'hC;

  // Main state machine
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      timer <= 0;
      sys_rst <= 1;
      shutdown_force <= 1;
      n_shutdown_rst <= 1;
      dma_en <= 0;
      spi_en <= 0;
      trig_en <= 0;
      status_code <= STATUS_OK;
      board_num <= 0;
      ps_interrupt <= 0;
    end else begin

      // State machine
      case (state)

        // Idle state, hardware shut down, waiting for system enable to go high
        // When enabled, remove the system reset and shutdown force, reset the shutdown
        IDLE: begin
          if (sys_en) begin
            state <= POWERON;
            timer <= 0;
            sys_rst <= 0;
            shutdown_force <= 0;
            n_shutdown_rst <= 0;
          end // if (sys_en)
          
        end // IDLE

        // Hold the shutdown latch reset high (n_shutdown_rst low) while we wait for the system to power on
        // Once the power is on, release the shutdown latch reset and start the DMA
        POWERON: begin
          if (timer >= POWERON_WAIT) begin
            state <= START_DMA;
            timer <= 0;
            n_shutdown_rst <= 1;
          end else begin
            timer <= timer + 1;
          end // if (timer >= POWERON_WAIT)
        end // POWERON

        // Wait for the DAC buffer to fill from the DMA before starting the SPI
        // If the buffer doesn't fill in time, halt the system
        START_DMA: begin
          if (dac_buf_full) begin
            state <= START_SPI;
            timer <= 0;
            spi_en <= 1;
          end else if (timer >= BUF_LOAD_WAIT) begin
            state <= HALTED;
            timer <= 0;
            sys_rst <= 1;
            shutdown_force <= 1;
            dma_en <= 0;
            status_code <= STATUS_DAC_BUF_FILL_TIMEOUT;
            ps_interrupt <= 1;
          end else begin
            timer <= timer + 1;
          end // if (dac_buf_full)
        end // START_DMA

        // Wait for the SPI subsystem to start before running the system
        // If the SPI subsystem doesn't start in time, halt the system
        START_SPI: begin
          if (spi_running) begin
            state <= RUNNING;
            timer <= 0;
            trig_en <= 1;
            ps_interrupt <= 1;
          end else if (timer >= SPI_START_WAIT) begin
            state <= HALTED;
            timer <= 0;
            sys_rst <= 1;
            shutdown_force <= 1;
            dma_en <= 0;
            spi_en <= 0;
            status_code <= STATUS_SPI_START_TIMEOUT;
            ps_interrupt <= 1;
          end else begin
            timer <= timer + 1;
          end // if (spi_running)
        end // START_SPI

        // Main running state, check for various error conditions or shutdowns
        RUNNING: begin
          // Reset the interrupt if needed
          if (ps_interrupt) begin
            ps_interrupt <= 0;
          end // if (ps_interrupt)

          // Check for various error conditions or shutdowns
          if (!sys_en || over_thresh || shutdown_sense || ext_shutdown || dac_empty_read || adc_full_write || premat_trig || premat_dac_div || premat_adc_div) begin
            // Set the status code and halt the system
            state <= HALTED;
            timer <= 0;
            sys_rst <= 1;
            shutdown_force <= 1;
            dma_en <= 0;
            spi_en <= 0;
            trig_en <= 0;
            ps_interrupt <= 1;

            // Processing system shutdown
            if (!sys_en) status_code <= STATUS_PS_SHUTDOWN;

            // Integrator core over threshold
            else if (over_thresh) begin
              status_code <= STATUS_OVER_THRESH;
              board_num <=  over_thresh[0] ? 3'd0 :
                over_thresh[1] ? 3'd1 :
                over_thresh[2] ? 3'd2 :
                over_thresh[3] ? 3'd3 :
                over_thresh[4] ? 3'd4 :
                over_thresh[5] ? 3'd5 :
                over_thresh[6] ? 3'd6 : 3'd7;
            end // if (over_thresh)

            // Hardware shutdown sense core detected a shutdown
            else if (shutdown_sense) begin
              status_code <= STATUS_SHUTDOWN_SENSE;
              board_num <= sense_num;
            end // if (shutdown_sense)

            // External shutdown
            else if (ext_shutdown) status_code <= STATUS_EXT_SHUTDOWN;

            // DAC read attempt from empty buffer
            else if (dac_empty_read) begin
              status_code <= STATUS_DAC_EMPTY_READ;
              board_num <=  dac_empty_read[0] ? 3'd0 :
                    dac_empty_read[1] ? 3'd1 :
                    dac_empty_read[2] ? 3'd2 :
                    dac_empty_read[3] ? 3'd3 :
                    dac_empty_read[4] ? 3'd4 :
                    dac_empty_read[5] ? 3'd5 :
                    dac_empty_read[6] ? 3'd6 : 3'd7;
            end // if (dac_empty_read)

            // ADC write attempt to full buffer
            else if (adc_full_write) begin
              status_code <= STATUS_ADC_FULL_WRITE;
              board_num <=  adc_full_write[0] ? 3'd0 :
                    adc_full_write[1] ? 3'd1 :
                    adc_full_write[2] ? 3'd2 :
                    adc_full_write[3] ? 3'd3 :
                    adc_full_write[4] ? 3'd4 :
                    adc_full_write[5] ? 3'd5 :
                    adc_full_write[6] ? 3'd6 : 3'd7;
            end // if (adc_full_write)

            // Premature trigger (trigger occurred before the DAC was pre-loaded and ready)
            else if (premat_trig) begin
              status_code <= STATUS_PREMAT_TRIG;
              board_num <=  premat_trig[0] ? 3'd0 :
                    premat_trig[1] ? 3'd1 :
                    premat_trig[2] ? 3'd2 :
                    premat_trig[3] ? 3'd3 :
                    premat_trig[4] ? 3'd4 :
                    premat_trig[5] ? 3'd5 :
                    premat_trig[6] ? 3'd6 : 3'd7;
            end // if (premat_trig)

            // Premature DAC divider (DAC transfer took longer than the DAC divider)
            else if (premat_dac_div) begin
              status_code <= STATUS_PREMAT_DAC_DIV;
              board_num <=  premat_dac_div[0] ? 3'd0 :
                    premat_dac_div[1] ? 3'd1 :
                    premat_dac_div[2] ? 3'd2 :
                    premat_dac_div[3] ? 3'd3 :
                    premat_dac_div[4] ? 3'd4 :
                    premat_dac_div[5] ? 3'd5 :
                    premat_dac_div[6] ? 3'd6 : 3'd7;
            end // if (premat_dac_div)

            // Premature ADC division (ADC transfer took longer than the ADC divider)
            else if (premat_adc_div) begin
              status_code <= STATUS_PREMAT_ADC_DIV;
              board_num <=  premat_adc_div[0] ? 3'd0 :
                    premat_adc_div[1] ? 3'd1 :
                    premat_adc_div[2] ? 3'd2 :
                    premat_adc_div[3] ? 3'd3 :
                    premat_adc_div[4] ? 3'd4 :
                    premat_adc_div[5] ? 3'd5 :
                    premat_adc_div[6] ? 3'd6 : 3'd7;
            end // if (premat_adc_div)

          end // if (!sys_en || over_thresh || shutdown_sense || ext_shutdown || dac_empty_read || adc_full_write || premat_trig || premat_dac_div || premat_adc_div)
        end // RUNNING

        // Wait in the halted state until the system enable goes low
        HALTED: begin
          // Reset the interrupt if needed
          if (ps_interrupt) begin
            ps_interrupt <= 0;
          end // if (ps_interrupt)
          // If the system enable goes low, go to IDLE and clear the status code
          if (~sys_en) begin 
            state <= IDLE;
            status_code <= STATUS_OK;
            board_num <= 0;
          end
        end // HALTED

      endcase // case (state)
    end // if (rst) else
  end // always @(posedge clk or posedge rst)

endmodule
