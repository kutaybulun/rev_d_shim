`timescale 1 ns / 1 ps

module axi_shim_cfg #
(
  parameter integer AXI_ADDR_WIDTH = 16,

  // Trigger lockout (+0)
  parameter integer TRIGGER_LOCKOUT_MIN = 0,
  parameter integer TRIGGER_LOCKOUT_MAX = {32{1'b1}},
  parameter integer TRIGGER_LOCKOUT_DEFAULT = 250000, // 1 ms at 250MHz

  // Calibration offset (+4)
  parameter integer CALIBRATION_OFFSET_MIN = -2048,
  parameter integer CALIBRATION_OFFSET_MAX = 2048,
  parameter integer CALIBRATION_OFFSET_DEFAULT = 0,

  // DAC divider (+8)
  parameter integer DAC_DIVIDER_MIN = 200,
  parameter integer DAC_DIVIDER_MAX = {16{1'b1}},
  parameter integer DAC_DIVIDER_DEFAULT = 1000,

  // Integrator threshold average (+12)
  parameter integer INTEGRATOR_THRESHOLD_AVERAGE_MIN = 0,
  parameter integer INTEGRATOR_THRESHOLD_AVERAGE_MAX = {1{1'b1}},
  parameter integer INTEGRATOR_THRESHOLD_AVERAGE_DEFAULT = 1 << 14,
  
  // Integrator window (+16)
  parameter integer INTEGRATOR_WINDOW_MIN = 2048,
  parameter integer INTEGRATOR_WINDOW_MAX = {32{1'b1}},
  parameter integer INTEGRATOR_WINDOW_DEFAULT = 5000000, // 100 ms at 50MHz

  // Integrator enable default
  parameter integer INTEG_EN_DEFAULT = 1
)
(
  // System signals
  input  wire                       aclk,
  input  wire                       aresetn,

  input  wire                       unlock,

  // Configuration outputs
  output reg  [31:0]         trig_lockout,
  output reg  [15:0]         cal_offset,
  output reg  [15:0]         dac_divider,
  output reg  [15:0]         integ_thresh_avg,
  output reg  [31:0]         integ_window,
  output reg                 integ_en,
  output wire                sys_en,

  // Configuration bounds
  output wire  trig_lockout_oob,
  output wire  cal_offset_oob,
  output wire  dac_divider_oob,
  output wire  integ_thresh_avg_oob,
  output wire  integ_window_oob,
  output reg   lock_viol,

  // AXI4-Line subordinate port
  input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_awaddr,  // AXI4-Lite subordinate: Write address
  input  wire                       s_axi_awvalid, // AXI4-Lite subordinate: Write address valid
  output wire                       s_axi_awready, // AXI4-Lite subordinate: Write address ready
  input  wire [31:0]                s_axi_wdata,   // AXI4-Lite subordinate: Write data
  input  wire [3:0]                 s_axi_wstrb,   // AXI4-Lite subordinate: Write strobe
  input  wire                       s_axi_wvalid,  // AXI4-Lite subordinate: Write data valid
  output wire                       s_axi_wready,  // AXI4-Lite subordinate: Write data ready
  output wire [1:0]                 s_axi_bresp,   // AXI4-Lite subordinate: Write response
  output wire                       s_axi_bvalid,  // AXI4-Lite subordinate: Write response valid
  input  wire                       s_axi_bready,  // AXI4-Lite subordinate: Write response ready
  input  wire [AXI_ADDR_WIDTH-1:0]  s_axi_araddr,  // AXI4-Lite subordinate: Read address
  input  wire                       s_axi_arvalid, // AXI4-Lite subordinate: Read address valid
  output wire                       s_axi_arready, // AXI4-Lite subordinate: Read address ready
  output wire [31:0]                s_axi_rdata,   // AXI4-Lite subordinate: Read data
  output wire [1:0]                 s_axi_rresp,   // AXI4-Lite subordinate: Read data response
  output wire                       s_axi_rvalid,  // AXI4-Lite subordinate: Read data valid
  input  wire                       s_axi_rready   // AXI4-Lite subordinate: Read data ready
);

  function integer clogb2 (input integer value);
    for(clogb2 = 0; value > 0; clogb2 = clogb2 + 1) value = value >> 1;
  endfunction

  localparam integer CFG_DATA_WIDTH = 1024;
  localparam integer AXI_DATA_WIDTH = 32;
  localparam integer ADDR_LSB = clogb2(AXI_DATA_WIDTH/8 - 1);
  localparam integer CFG_SIZE = CFG_DATA_WIDTH/AXI_DATA_WIDTH;
  localparam integer CFG_WIDTH = CFG_SIZE > 1 ? clogb2(CFG_SIZE-1) : 1;

  reg int_bvalid_reg, int_bvalid_next;
  reg int_rvalid_reg, int_rvalid_next;
  reg [AXI_DATA_WIDTH-1:0] int_rdata_reg, int_rdata_next;

  wire [AXI_DATA_WIDTH-1:0] int_data_mux [CFG_SIZE-1:0];
  wire [CFG_DATA_WIDTH-1:0] int_data_wire;
  wire [CFG_DATA_WIDTH-1:0] int_axi_data_wire;
  wire [CFG_DATA_WIDTH-1:0] int_data_modified_wire;
  wire [CFG_DATA_WIDTH-1:0] int_initial_data_wire;
  wire [CFG_SIZE-1:0] int_ce_wire;
  wire int_wvalid_wire;

  reg locked;

  genvar j, k;

  assign int_wvalid_wire = s_axi_awvalid & s_axi_wvalid;
  
  generate
    for(j = 0; j < CFG_SIZE; j = j + 1)
    begin : WORDS
      assign int_data_mux[j] = int_data_wire[j*AXI_DATA_WIDTH+AXI_DATA_WIDTH-1:j*AXI_DATA_WIDTH];
      assign int_ce_wire[j] = int_wvalid_wire & (s_axi_awaddr[ADDR_LSB+CFG_WIDTH-1:ADDR_LSB] == j);
      for(k = 0; k < AXI_DATA_WIDTH; k = k + 1)
      begin : BITS
        
        // Flipflops for AXI data
        FDRE #(
          .INIT(1'b0)
        ) FDRE_data (
          .CE(int_ce_wire[j] & s_axi_wstrb[k/8]),
          .C(aclk),
          .R(~aresetn),
          .D(s_axi_wdata[k]),
          .Q(int_axi_data_wire[j*AXI_DATA_WIDTH + k])
        );

        // Track if the data has been modified since reset
        FDRE #(
          .INIT(1'b0)
        ) FDRE_data_modified (
          .CE(int_ce_wire[j] & s_axi_wstrb[k/8]),
          .C(aclk),
          .R(~aresetn),
          .D(1'b1),
          .Q(int_data_modified_wire[j*AXI_DATA_WIDTH + k])
        );
      end
    end
  endgenerate

  // Initial values
  assign int_data_wire = int_axi_data_wire | (~int_data_modified_wire & int_initial_data_wire);
  assign int_initial_data_wire = {
    {(CFG_DATA_WIDTH/32 - 6){32'b0}},
    INTEG_EN_DEFAULT,
    INTEGRATOR_WINDOW_DEFAULT,
    INTEGRATOR_THRESHOLD_AVERAGE_DEFAULT,
    DAC_DIVIDER_DEFAULT,
    CALIBRATION_OFFSET_DEFAULT,
    TRIGGER_LOCKOUT_DEFAULT
  };

  // Out of bounds checks
  assign trig_lockout_oob = trig_lockout < TRIGGER_LOCKOUT_MIN || trig_lockout > TRIGGER_LOCKOUT_MAX;
  assign cal_offset_oob = $signed(cal_offset) < CALIBRATION_OFFSET_MIN || $signed(cal_offset) > CALIBRATION_OFFSET_MAX
                        || $signed(cal_offset) < -$signed((1 << 15) - 1) || $signed(cal_offset) > (1 << 15) - 1;
  assign dac_divider_oob = dac_divider < DAC_DIVIDER_MIN || dac_divider > DAC_DIVIDER_MAX
                        || dac_divider > (1 << 16) - 1;
  assign integ_thresh_avg_oob = integ_thresh_avg < INTEGRATOR_THRESHOLD_AVERAGE_MIN || integ_thresh_avg > INTEGRATOR_THRESHOLD_AVERAGE_MAX
                        || integ_thresh_avg > (1 << 16) - 1;
  assign integ_window_oob = integ_window < INTEGRATOR_WINDOW_MIN || integ_window > INTEGRATOR_WINDOW_MAX;

  assign sys_en = int_data_wire[192];

  always @(posedge aclk)
  begin
    if(~aresetn)
    begin
      int_bvalid_reg <= 1'b0;
      int_rvalid_reg <= 1'b0;
      int_rdata_reg <= {(AXI_DATA_WIDTH){1'b0}};

      trig_lockout <= TRIGGER_LOCKOUT_DEFAULT;
      cal_offset <= CALIBRATION_OFFSET_DEFAULT;
      dac_divider <= DAC_DIVIDER_DEFAULT;
      integ_thresh_avg <= INTEGRATOR_THRESHOLD_AVERAGE_DEFAULT;
      integ_window <= INTEGRATOR_WINDOW_DEFAULT;
      integ_en <= 0;

      locked <= 1'b0;
      lock_viol <= 1'b0;
    end
    else
    begin
      int_bvalid_reg <= int_bvalid_next;
      int_rvalid_reg <= int_rvalid_next;
      int_rdata_reg <= int_rdata_next;

      // Lock the configuration registers
      if(sys_en) begin
        locked <= 1'b1;
        trig_lockout <= int_data_wire[31:0];
        cal_offset <= int_data_wire[63:32];
        dac_divider <= int_data_wire[95:64];
        integ_thresh_avg <= int_data_wire[127:96];
        integ_window <= int_data_wire[159:128];
        integ_en <= int_data_wire[160];
      end else if (unlock) begin
        locked <= 1'b0;
        lock_viol <= 1'b0;
      end

      // Check for lock violations if locked
      if(locked) begin
        if(trig_lockout != int_data_wire[31:0] 
          || cal_offset != int_data_wire[63:32]
          || dac_divider != int_data_wire[95:64]
          || integ_thresh_avg != int_data_wire[127:96]
          || integ_window != int_data_wire[159:128]
          || integ_en != int_data_wire[160]) begin
          lock_viol <= 1'b1;
        end
      end

    end
  end

  always @*
  begin
    int_bvalid_next = int_bvalid_reg;

    if(int_wvalid_wire)
    begin
      int_bvalid_next = 1'b1;
    end

    if(s_axi_bready & int_bvalid_reg)
    begin
      int_bvalid_next = 1'b0;
    end
  end

  always @*
  begin
    int_rvalid_next = int_rvalid_reg;
    int_rdata_next = int_rdata_reg;

    if(s_axi_arvalid)
    begin
      int_rvalid_next = 1'b1;
      int_rdata_next = int_data_mux[s_axi_araddr[ADDR_LSB+CFG_WIDTH-1:ADDR_LSB]];
    end

    if(s_axi_rready & int_rvalid_reg)
    begin
      int_rvalid_next = 1'b0;
    end
  end

  assign s_axi_bresp = 2'd0;
  assign s_axi_rresp = 2'd0;

  assign s_axi_awready = int_wvalid_wire;
  assign s_axi_wready = int_wvalid_wire;
  assign s_axi_bvalid = int_bvalid_reg;
  assign s_axi_arready = 1'b1;
  assign s_axi_rdata = int_rdata_reg;
  assign s_axi_rvalid = int_rvalid_reg;

endmodule
