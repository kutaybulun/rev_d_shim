module tx_0 {
  # Create xlconstant
  cell xilinx.com:ip:xlconstant:1.1 const_0 {
    CONST_WIDTH 9
    CONST_VAL 511
  }

  # Create blk_mem_gen
  cell xilinx.com:ip:blk_mem_gen:8.4 bram_0 {
    MEMORY_TYPE True_Dual_Port_RAM
    USE_BRAM_BLOCK Stand_Alone
    WRITE_WIDTH_A 64
    WRITE_DEPTH_A 512
    WRITE_WIDTH_B 32
    WRITE_DEPTH_B 1024
    ENABLE_A Always_Enabled
    ENABLE_B Always_Enabled
    REGISTER_PORTB_OUTPUT_OF_MEMORY_PRIMITIVES false
  }

  # Create axis_bram_reader
  cell pavel-demin:user:axis_bram_reader:1.0 reader_0 {
    AXIS_TDATA_WIDTH 64
    BRAM_DATA_WIDTH 64
    BRAM_ADDR_WIDTH 9
    CONTINUOUS TRUE
  } {
    BRAM_PORTA bram_0/BRAM_PORTA
    cfg_data const_0/dout
    aclk /pll_0/clk_out1
    aresetn /rst_slice_3/dout
  }

  # Create axis_broadcaster
  cell xilinx.com:ip:axis_broadcaster:1.1 bcast_0 {
    S_TDATA_NUM_BYTES.VALUE_SRC USER
    M_TDATA_NUM_BYTES.VALUE_SRC USER
    S_TDATA_NUM_BYTES 8
    M_TDATA_NUM_BYTES 4
    M00_TDATA_REMAP {tdata[31:0]}
    M01_TDATA_REMAP {tdata[63:32]}
  } {
    S_AXIS reader_0/M_AXIS
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

  # Create floating_point
  cell xilinx.com:ip:floating_point:7.1 fp_0 {
    OPERATION_TYPE Float_to_fixed
    RESULT_PRECISION_TYPE Custom
    C_RESULT_EXPONENT_WIDTH 2
    C_RESULT_FRACTION_WIDTH 22
  } {
    S_AXIS_A bcast_0/M00_AXIS
    aclk /pll_0/clk_out1
  }

  # Create floating_point
  cell xilinx.com:ip:floating_point:7.1 fp_1 {
    OPERATION_TYPE Float_to_fixed
    RESULT_PRECISION_TYPE Custom
    C_RESULT_EXPONENT_WIDTH 2
    C_RESULT_FRACTION_WIDTH 22
  } {
    S_AXIS_A bcast_0/M01_AXIS
    aclk /pll_0/clk_out1
  }

  # Create axis_combiner
  cell  xilinx.com:ip:axis_combiner:1.1 comb_0 {
    TDATA_NUM_BYTES.VALUE_SRC USER
    TDATA_NUM_BYTES 3
  } {
    S00_AXIS fp_0/M_AXIS_RESULT
    S01_AXIS fp_1/M_AXIS_RESULT
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

  # Create fir_compiler
  cell xilinx.com:ip:fir_compiler:7.2 fir_0 {
    DATA_WIDTH.VALUE_SRC USER
    DATA_WIDTH 24
    COEFFICIENTVECTOR {-1.6477803126673e-08, -4.73241780719431e-08, -7.93893762402556e-10, 3.09352974037909e-08, 1.86287085664036e-08, 3.27498519682074e-08, -6.30103868644643e-09, -1.52285727032021e-07, -8.30466648048943e-08, 3.14547654032246e-07, 3.05634502525888e-07, -4.74191327710916e-07, -7.13516534402831e-07, 5.47346324460726e-07, 1.33466461110536e-06, -4.14159890528364e-07, -2.1505811145434e-06, -6.77370237910856e-08, 3.07556819541765e-06, 1.0370505355367e-06, -3.94449781984647e-06, -2.59199328674329e-06, 4.51552941227161e-06, 4.74797884206863e-06, -4.49299646667899e-06, -7.39848885869424e-06, 3.57228568227438e-06, 1.02898719826237e-05, -1.50387150681059e-06, -1.30212988742999e-05, -1.83214145429432e-06, 1.50786566301658e-05, 6.35486748279423e-06, -1.59062147434029e-05, -1.17328848104954e-05, 1.50114974785596e-05, 1.7372574759798e-05, -1.20947251948756e-05, -2.24676444755539e-05, 7.16993553114205e-06, 2.61041439270352e-05, -6.63532856011916e-07, -2.74301832391597e-05, -6.55092457696323e-06, 2.58651810404159e-05, 1.32048515273499e-05, -2.1317677174528e-05, -1.77907085402518e-05, 1.436676627647e-05, 1.88203678903225e-05, -6.35774583750282e-06, -1.51630391175939e-05, -6.34777143600336e-07, 6.41598241707925e-06, 4.00817100547114e-06, 6.7578664887829e-06, -1.00568533107808e-06, -2.24038826835638e-05, -1.07627151802942e-05, 3.72348184414005e-05, 3.2701655435069e-05, -4.6862352007415e-05, -6.46546125464121e-05, 4.62618689241764e-05, 0.000104405214397357, -3.05417940111896e-05, -0.00014746208007481, -4.11988278994384e-06, 0.000187192202366089, 5.94739008909315e-05, -0.000215382226866196, -0.00013430624011575, 0.000223231771512739, 0.000223842528685186, -0.00020270758420517, -0.000319634221298429, 0.000148101277087398, 0.000410063948518449, -5.75617367437652e-05, -0.000481530969730516, -6.56786076534709e-05, 0.000520268200692712, 0.000212671507961849, -0.000514635575661532, -0.000369018523112966, 0.000457482080116169, 0.000515991288315472, -0.000348488643095732, -0.000632902740484264, 0.00019565498787737, 0.000700212218756191, -1.57980429849499e-05, -0.000703228531136762, -0.000166384366137857, 0.000635864178458659, 0.000320845304353809, -0.00050382612172403, -0.000416271542916756, 0.000326578173694164, 0.000425408104410912, -0.000137467845920125, -0.000331057773200808, -1.84374581160459e-05, 0.000131957667600652, 8.89996453664623e-05, 0.000152412457008811, -2.20123592827393e-05, -0.00047912778003751, -0.000226160900022274, 0.000781626283194707, 0.000680353983714684, -0.000973879698174067, -0.0013374715808644, 0.000957544253972286, 0.00215830757707662, -0.000633087262805248, -0.00306249739852838, -8.62724802143682e-05, 0.00392762459059574, 0.00125893562455588, -0.00459335728493682, -0.00289915526565417, 0.00487097490634664, 0.00496287757956818, -0.00455803664391539, -0.00733691415380758, 0.00345728084505496, 0.00983286212154261, -0.00139823904366904, -0.0121865678116845, -0.00174040610912354, 0.014062746409744, 0.00600874643597289, -0.0150660660015954, -0.01137053420847, 0.014748826587083, 0.0176878324514315, -0.0126189063584745, -0.0247140011981246, 0.00813110931172791, 0.0320875384224486, -0.000645073733882858, -0.0393183241035692, -0.0106929061200545, 0.0457380625458776, 0.0272512703315898, -0.0503228989148367, -0.051717794358685, 0.0510207185249084, 0.0905740901172399, -0.0416086426627032, -0.163752839902141, -0.0108030211279308, 0.356394916826446, 0.554828643152604, 0.356394916826445, -0.0108030211279307, -0.163752839902141, -0.0416086426627032, 0.0905740901172398, 0.0510207185249084, -0.0517177943586849, -0.0503228989148367, 0.0272512703315898, 0.0457380625458776, -0.0106929061200545, -0.0393183241035692, -0.000645073733882855, 0.0320875384224486, 0.00813110931172788, -0.0247140011981246, -0.0126189063584744, 0.0176878324514315, 0.0147488265870829, -0.01137053420847, -0.0150660660015954, 0.00600874643597288, 0.014062746409744, -0.00174040610912354, -0.0121865678116845, -0.00139823904366905, 0.00983286212154259, 0.00345728084505496, -0.00733691415380758, -0.00455803664391539, 0.00496287757956815, 0.00487097490634665, -0.00289915526565417, -0.00459335728493682, 0.00125893562455588, 0.00392762459059574, -8.62724802143759e-05, -0.00306249739852838, -0.000633087262805254, 0.00215830757707662, 0.000957544253972288, -0.0013374715808644, -0.000973879698174062, 0.000680353983714686, 0.000781626283194706, -0.000226160900022277, -0.0004791277800375, -2.20123592827382e-05, 0.000152412457008803, 8.89996453664583e-05, 0.000131957667600656, -1.84374581160419e-05, -0.000331057773200813, -0.000137467845920129, 0.000425408104410916, 0.000326578173694167, -0.000416271542916745, -0.000503826121724035, 0.000320845304353799, 0.000635864178458661, -0.00016638436613785, -0.000703228531136761, -1.57980429849744e-05, 0.000700212218756191, 0.000195654987877385, -0.000632902740484265, -0.000348488643095741, 0.00051599128831547, 0.000457482080116171, -0.000369018523112963, -0.000514635575661537, 0.000212671507961847, 0.000520268200692713, -6.56786076534692e-05, -0.000481530969730511, -5.75617367437655e-05, 0.000410063948518448, 0.000148101277087398, -0.000319634221298427, -0.00020270758420517, 0.000223842528685188, 0.000223231771512738, -0.000134306240115752, -0.000215382226866195, 5.94739008909304e-05, 0.000187192202366089, -4.11988278994438e-06, -0.00014746208007481, -3.0541794011189e-05, 0.000104405214397356, 4.62618689241748e-05, -6.46546125464118e-05, -4.68623520074133e-05, 3.27016554350691e-05, 3.72348184413998e-05, -1.07627151802942e-05, -2.24038826835659e-05, -1.00568533107809e-06, 6.75786648878254e-06, 4.00817100547117e-06, 6.41598241707818e-06, -6.34777143600528e-07, -1.51630391175948e-05, -6.35774583750266e-06, 1.88203678903231e-05, 1.436676627647e-05, -1.77907085402514e-05, -2.13176771745279e-05, 1.32048515273498e-05, 2.58651810404156e-05, -6.55092457696207e-06, -2.74301832391597e-05, -6.63532856012472e-07, 2.61041439270352e-05, 7.16993553114219e-06, -2.24676444755538e-05, -1.20947251948757e-05, 1.73725747597979e-05, 1.50114974785595e-05, -1.17328848104953e-05, -1.5906214743403e-05, 6.35486748279425e-06, 1.50786566301659e-05, -1.83214145429435e-06, -1.30212988742996e-05, -1.50387150681058e-06, 1.02898719826235e-05, 3.57228568227438e-06, -7.3984888586941e-06, -4.49299646667903e-06, 4.74797884206855e-06, 4.51552941227162e-06, -2.59199328674326e-06, -3.94449781984647e-06, 1.03705053553668e-06, 3.07556819541762e-06, -6.77370237911482e-08, -2.15058111454339e-06, -4.1415989052838e-07, 1.33466461110535e-06, 5.47346324460698e-07, -7.13516534402833e-07, -4.74191327710884e-07, 3.05634502525885e-07, 3.14547654032223e-07, -8.30466648048881e-08, -1.52285727032016e-07, -6.30103868644584e-09, 3.27498519682033e-08, 1.86287085664046e-08, 3.0935297403796e-08, -7.93893762403235e-10, -4.7324178071939e-08, -1.64778031266738e-08}
    COEFFICIENT_WIDTH 24
    QUANTIZATION Quantize_Only
    BESTPRECISION true
    FILTER_TYPE Interpolation
    INTERPOLATION_RATE 2
    NUMBER_PATHS 2
    RATESPECIFICATION Input_Sample_Period
    SAMPLEPERIOD 6250
    OUTPUT_ROUNDING_MODE Truncate_LSBs
    OUTPUT_WIDTH 24
  } {
    S_AXIS_DATA comb_0/M_AXIS
    aclk /pll_0/clk_out1
  }

  # Create axis_broadcaster
  cell xilinx.com:ip:axis_broadcaster:1.1 bcast_1 {
    S_TDATA_NUM_BYTES.VALUE_SRC USER
    M_TDATA_NUM_BYTES.VALUE_SRC USER
    S_TDATA_NUM_BYTES 6
    M_TDATA_NUM_BYTES 3
    M00_TDATA_REMAP {tdata[47:24]}
    M01_TDATA_REMAP {tdata[23:0]}
  } {
    S_AXIS fir_0/M_AXIS_DATA
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler:4.0 cic_0 {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Interpolation
    NUMBER_OF_STAGES 6
    FIXED_OR_INITIAL_RATE 3125
    INPUT_SAMPLE_FREQUENCY 0.04
    CLOCK_FREQUENCY 125
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 24
    USE_XTREME_DSP_SLICE false
  } {
    S_AXIS_DATA bcast_1/M00_AXIS
    aclk /pll_0/clk_out1
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler:4.0 cic_1 {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Interpolation
    NUMBER_OF_STAGES 6
    FIXED_OR_INITIAL_RATE 3125
    INPUT_SAMPLE_FREQUENCY 0.04
    CLOCK_FREQUENCY 125
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 24
    USE_XTREME_DSP_SLICE false
  } {
    S_AXIS_DATA bcast_1/M01_AXIS
    aclk /pll_0/clk_out1
  }

  # Create axis_combiner
  cell  xilinx.com:ip:axis_combiner:1.1 comb_1 {
    TDATA_NUM_BYTES.VALUE_SRC USER
    TDATA_NUM_BYTES 3
  } {
    S00_AXIS cic_0/M_AXIS_DATA
    S01_AXIS cic_1/M_AXIS_DATA
    aclk /pll_0/clk_out1
    aresetn /rst_0/peripheral_aresetn
  }

  # Create axis_constant
  cell pavel-demin:user:axis_constant:1.0 phase_0 {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data /cfg_slice_2/dout
    aclk /pll_0/clk_out1
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler:6.0 dds_0 {
    DDS_CLOCK_RATE 125
    SPURIOUS_FREE_DYNAMIC_RANGE 138
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    DSP48_USE Maximal
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 24
    DSP48_USE Minimal
  } {
    S_AXIS_PHASE phase_0/M_AXIS
    aclk /pll_0/clk_out1
  }

  # Create axis_lfsr
  cell pavel-demin:user:axis_lfsr:1.0 lfsr_0 {} {
    aclk /pll_0/clk_out1
    aresetn /rst_slice_3/dout
  }

  # Create cmpy
  cell xilinx.com:ip:cmpy:6.0 mult_0 {
    APORTWIDTH.VALUE_SRC USER
    BPORTWIDTH.VALUE_SRC USER
    APORTWIDTH 24
    BPORTWIDTH 24
    ROUNDMODE Random_Rounding
    OUTPUTWIDTH 14
  } {
    S_AXIS_A comb_1/M_AXIS
    S_AXIS_B dds_0/M_AXIS_DATA
    S_AXIS_CTRL lfsr_0/M_AXIS
    aclk /pll_0/clk_out1
  }
}
