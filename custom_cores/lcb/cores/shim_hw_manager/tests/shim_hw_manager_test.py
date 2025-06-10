import cocotb
from cocotb.triggers import RisingEdge , Timer, ReadOnly, FallingEdge
from shim_hw_manager_base import shim_hw_manager_base
from shim_hw_manager_coverage import start_coverage_monitor

# Create a setup function that can be called by each test
async def setup_testbench(dut):
    # Delay parameters should be the same with shim_hw_manager.v
    tb = shim_hw_manager_base(dut, clk_period=4, time_unit="ns",
                        SHUTDOWN_FORCE_DELAY=250,
                        SHUTDOWN_RESET_PULSE=25,
                        SHUTDOWN_RESET_DELAY=250,
                        SPI_INIT_WAIT=2500,
                        SPI_START_WAIT=2500)
    return tb

# Helper function to set up the testbench and go to RUNNING state
async def normal_start_up_with_no_log(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("SYSTEM WILL GO TO RUNNING STATE: normal_start_up_with_no_log")

    # Initialize and reset
    await tb.reset()

    # Enable the system
    dut.sys_en.value = 1

    # Wait for CONFIRM_SPI_START state
    await tb.wait_for_state(6, None, True, tb.SPI_INIT_WAIT + tb.SHUTDOWN_FORCE_DELAY + tb.SHUTDOWN_RESET_DELAY + tb.SHUTDOWN_RESET_PULSE + 5)
    
    # Simulate SPI subsystem being off (initialized)
    await RisingEdge(dut.clk)
    dut.spi_off.value = 0  # SPI is running
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Now should be in RUNNING state
    # wait one cycle for interrupt to be cleared
    state = int(dut.state.value)
    assert state == 7, f"Expected state 7, got {state}"
    await RisingEdge(dut.clk)
    assert dut.ps_interrupt.value == 0, "Interrupt should be cleared"
    tb.dut._log.info("now in RUNNING state")
    return tb


# At the IDLE state if there is an error in the configuration, the system should go to HALTED state.
@cocotb.test()
async def test_configuration_errors(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_configuration_errors")
    
    # Start coverage monitor
    start_coverage_monitor(dut)

    # Error conditions to test for
    error_conditions = [
        (dut.integ_thresh_avg_oob, 0x0200, "STATUS_INTEG_THRESH_AVG_OOB"),
        (dut.integ_window_oob, 0x0201, "STATUS_INTEG_WINDOW_OOB"),
        (dut.integ_en_oob, 0x0202, "STATUS_INTEG_EN_OOB"),
        (dut.sys_en_oob, 0x0203, "STATUS_SYS_EN_OOB")
    ]

    # Iterate through each error condition
    for error_signal, expected_status, status_name in error_conditions:
        await tb.reset()
        tb.dut._log.info(f"TESTING ERROR CONDITION: {status_name}")
        error_signal.value = 1  # Set the error signal to 1
        dut.sys_en.value = 1  # Enable the system
        tb.dut._log.info(f"sys_en = {dut.sys_en.value}, {status_name} = {error_signal.value}")
        await tb.check_state_and_status(1, 1)  # IDLE = 1, STATUS_OK = 1

        await tb.wait_for_state(8) # HALTED = 8
        tb.dut._log.info(f"sys_en = {dut.sys_en.value}, {status_name} = {error_signal.value}")
        await tb.check_state_and_status(8, expected_status)  # Check that we are in HALTED = 8 state with the expected status
        await RisingEdge(dut.clk)
        error_signal.value = 0 # Reset the error signal
        dut.sys_en.value = 0  # Reset the sys_en signal

# In a normal startup, the system should go from IDLE to RUNNING state. This test checks the state transitions for that.
@cocotb.test()
async def test_normal_startup(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_normal_startup")

    # Initialize and reset
    await tb.reset()

    # Start coverage monitor
    start_coverage_monitor(dut)
    
    # Verify we start in IDLE state
    await tb.check_state_and_status(1, 1)  # IDLE = 1, STATUS_OK = 1
    
    # Enable the system
    dut.sys_en.value = 1
    dut.spi_off.value = 1  # SPI initially off (not initialized)
    
    # Wait for CONFIRM_SPI_INIT state
    await tb.wait_for_state(2)  # CONFIRM_SPI_INIT = 2
    await tb.check_state_and_status(2, 1)  # Check that we are in CONFIRM_SPI_INIT state
    
    # Simulate SPI being initialized (off)
    await tb.wait_cycles(10)
    dut.spi_off.value = 1  # Confirm SPI is off (initialized)
    
    # Wait for RELEASE_SD_F state
    await tb.wait_for_state(3, None, False, tb.SPI_INIT_WAIT + 1000)  # RELEASE_SD_F = 3
    await tb.check_state_and_status(3, 1)  # Check that we are in RELEASE_SD_F state

    # Wait for PULSE_SD_RST state
    await tb.wait_for_state(4, None, False, tb.SHUTDOWN_FORCE_DELAY + 1000)  # PULSE_SD_RST = 4
    await tb.check_state_and_status(4, 1)  # Check that we are in PULSE_SD_RST state

    # Wait for SD_RST_DELAY state
    await tb.wait_for_state(5, None, False, tb.SHUTDOWN_RESET_PULSE + 1000)  # SD_RST_DELAY = 5
    await tb.check_state_and_status(5, 1)  # Check that we are in SD_RST_DELAY state

    # Wait for CONFIRM_SPI_START state
    await tb.wait_for_state(6, None, False, tb.SHUTDOWN_RESET_DELAY + 1000)  # CONFIRM_SPI_START = 6
    await tb.check_state_and_status(6, 1)  # Check that we are in CONFIRM_SPI_START state
    await tb.wait_cycles(100)  # Wait for a few cycles to set spi_running
    dut.spi_off.value = 0  # Set SPI running (not off)

    # Should reach RUNNING state
    await tb.wait_for_state(7, None, False, tb.SPI_START_WAIT + 1000)  # RUNNING = 7

    # Check that system is properly enabled
    assert dut.n_shutdown_force.value == 1, "Shutdown force should be released"
    assert dut.n_shutdown_rst.value == 1, "Shutdown reset should be released"
    assert dut.shutdown_sense_en.value == 1, "Shutdown sense should be enabled"
    assert dut.spi_en.value == 1, "SPI should be enabled"
    assert dut.trig_en.value == 1, "Trigger should be enabled"
    assert dut.ps_interrupt.value == 1, "Interrupt should be asserted"
    
    await RisingEdge(dut.clk)
    await ReadOnly()  # Ensure all signals are updated
    assert dut.ps_interrupt.value == 0, "Interrupt should be cleared"

    # Verify we're in RUNNING state with STATUS_OK
    await tb.check_state_and_status(7, 1)  # RUNNING = 7, STATUS_OK = 1

# When in HALTED state, the system should be able to go back to IDLE state when sys_en goes low
@cocotb.test()
async def test_halted_to_idle(dut):
    tb = await normal_start_up_with_no_log(dut)
    tb.dut._log.info("STARTING TEST: test_halted_to_idle")

    # Start coverage monitor
    start_coverage_monitor(dut)

    # Simulate a runtime error
    await RisingEdge(dut.clk)
    dut.lock_viol.value = 1
    await RisingEdge(dut.clk) # where the error is detected
    await RisingEdge(dut.clk) # where the state is updated
    # Check that the system is in HALTED state
    await tb.check_state_and_status(8, 0x0204)  # HALTED = 8, STATUS_LOCK_VIOL = 0x0204
    assert dut.n_shutdown_force.value == 0, "Expected shutdown force"
    assert dut.shutdown_sense_en.value == 0, "Expected shutdown sense disabled"
    assert dut.spi_clk_power_n == 1, "Expected SPI clock power disabled"
    assert dut.spi_en.value == 0, "Expected SPI disabled"
    assert dut.trig_en.value == 0, "Expected trigger disabled"
    assert dut.ps_interrupt.value == 1, "Expected interrupt asserted"

    await RisingEdge(dut.clk)
    dut.sys_en.value = 0  # Enable signal goes low
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await tb.check_state_and_status(1, 1)  # IDLE = 1, STATUS_OK = 1
    assert dut.unlock_cfg.value == 1, "Expected unlock_cfg to be 1"
    


# Test runtime errors in RUNNING state, system should go to HALTED state
@cocotb.test()
async def test_runtime_errors(dut):

    # Start coverage monitor
    start_coverage_monitor(dut)

    error_conditions = [
        (dut.sys_en, 0x0002, "STATUS_PS_SHUTDOWN"),
        (dut.lock_viol, 0x0204, "STATUS_LOCK_VIOL"),
        (dut.shutdown_sense, 0x0300, "STATUS_SHUTDOWN_SENSE"),
        (dut.ext_shutdown, 0x0301, "STATUS_EXT_SHUTDOWN"),
        (dut.over_thresh, 0x0400, "STATUS_OVER_THRESH"),
        (dut.thresh_underflow, 0x0401, "STATUS_THRESH_UNDERFLOW"),
        (dut.thresh_overflow, 0x0402, "STATUS_THRESH_OVERFLOW"),
        (dut.bad_trig_cmd, 0x0500, "STATUS_BAD_TRIG_CMD"),
        (dut.trig_buf_overflow, 0x0501, "STATUS_TRIG_BUF_OVERFLOW"),
        (dut.bad_dac_cmd, 0x0600, "STATUS_BAD_DAC_CMD"),
        (dut.dac_cal_oob, 0x0601, "STATUS_DAC_CAL_OOB"),
        (dut.dac_val_oob, 0x0602, "STATUS_DAC_VAL_OOB"),
        (dut.dac_cmd_buf_underflow, 0x0603, "STATUS_DAC_BUF_UNDERFLOW"),
        (dut.dac_cmd_buf_overflow, 0x0604, "STATUS_DAC_BUF_OVERFLOW"),
        (dut.unexp_dac_trig, 0x0605, "STATUS_UNEXP_DAC_TRIG"),
        (dut.bad_adc_cmd, 0x0700, "STATUS_BAD_ADC_CMD"),
        (dut.adc_cmd_buf_underflow, 0x0701, "STATUS_ADC_BUF_UNDERFLOW"),
        (dut.adc_cmd_buf_overflow, 0x0702, "STATUS_ADC_BUF_OVERFLOW"),
        (dut.adc_data_buf_underflow, 0x0703, "STATUS_ADC_DATA_BUF_UNDERFLOW"),
        (dut.adc_data_buf_overflow, 0x0704, "STATUS_ADC_DATA_BUF_OVERFLOW"),
        (dut.unexp_adc_trig, 0x0705, "STATUS_UNEXP_ADC_TRIG")
    ]

    for error_signal, expected_status, status_name in error_conditions:
        tb = await normal_start_up_with_no_log(dut)
        tb.dut._log.info(f"Testing error condition: {status_name}")

        # Set the error signal
        await RisingEdge(dut.clk)
        if expected_status == 0x0002:
            error_signal.value = 0
        else:
            error_signal.value = 1

        await RisingEdge(dut.clk) # where the error is detected
        await RisingEdge(dut.clk) # where the state is updated

        # Check that we are in HALTED state
        await tb.check_state_and_status(8, expected_status)

        assert dut.n_shutdown_force.value == 0, "Expected shutdown force"
        assert dut.shutdown_sense_en.value == 0, "Expected shutdown sense disabled"
        assert dut.spi_clk_power_n == 1, "Expected SPI clock power disabled"
        assert dut.spi_en.value == 0, "Expected SPI disabled"
        assert dut.trig_en.value == 0, "Expected trigger disabled"
        assert dut.ps_interrupt.value == 1, "Expected interrupt asserted"

# Test SPI init timeout, the system should go to HALTED state
@cocotb.test()
async def test_spi_init_timeout(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_spi_init_timeout")

    # Initialize and reset
    await tb.reset()

    # Start coverage monitor
    start_coverage_monitor(dut)

    # Enable the system
    dut.sys_en.value = 1
    dut.spi_off.value = 0 

    # Wait for CONFIRM_SPI_INIT state
    await tb.wait_for_state(2, None, True, 10)
    await RisingEdge(dut.clk)

    # Simulate SPI init timeout
    tb.dut._log.info(f"SPI INIT WAIT parameter is {dut.SPI_INIT_WAIT.value}")
    tb.dut._log.info(f"Simulating SPI init timeout, waiting for {tb.SPI_INIT_WAIT} cycles")
    await tb.wait_cycles(tb.SPI_INIT_WAIT)
    tb.dut._log.info(f"timer value is {int(dut.timer.value)}, maximum wait time was {tb.SPI_INIT_WAIT}")
    await RisingEdge(dut.clk)

    await tb.check_state_and_status(8, 0x0101)  # HALTED = 8, STATUS_SPI_INIT_TIMEOUT = 0x0101
    assert dut.n_shutdown_force.value == 0, "Expected shutdown force"
    assert dut.shutdown_sense_en.value == 0, "Expected shutdown sense disabled"
    assert dut.spi_clk_power_n == 1, "Expected SPI clock power disabled"
    assert dut.spi_en.value == 0, "Expected SPI disabled"
    assert dut.trig_en.value == 0, "Expected trigger disabled"
    assert dut.ps_interrupt.value == 1, "Expected interrupt asserted"

# Test SPI start timeout, the system should go to HALTED state
@cocotb.test()
async def test_spi_start_timeout(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_spi_start_timeout")

    # Initialize and reset
    await tb.reset()

    # Start coverage monitor
    start_coverage_monitor(dut)

    # Enable the system
    dut.sys_en.value = 1
    dut.spi_off.value = 1  # SPI starts off

    # Wait for CONFIRM_SPI_START state
    await tb.wait_for_state(6, None, True, tb.SPI_INIT_WAIT + tb.SHUTDOWN_FORCE_DELAY + tb.SHUTDOWN_RESET_DELAY + tb.SHUTDOWN_RESET_PULSE + 5)

    # Keep SPI off (doesn't start)
    await RisingEdge(dut.clk)
    dut.spi_off.value = 1

    # Simulate SPI start timeout
    tb.dut._log.info(f"SPI START WAIT parameter is {dut.SPI_START_WAIT.value}")
    tb.dut._log.info(f"Simulating SPI start timeout, waiting for {tb.SPI_START_WAIT} cycles")
    await tb.wait_cycles(tb.SPI_START_WAIT)
    tb.dut._log.info(f"timer value is {int(dut.timer.value)}, maximum wait time was {tb.SPI_START_WAIT}")
    await RisingEdge(dut.clk)

    await tb.check_state_and_status(8, 0x0100) # HALTED = 8, STATUS_SPI_START_TIMEOUT = 0x0100
    assert dut.n_shutdown_force.value == 0, "Expected shutdown force"
    assert dut.shutdown_sense_en.value == 0, "Expected shutdown sense disabled"
    assert dut.spi_clk_power_n.value == 1, "Expected SPI clock power off"
    assert dut.spi_en.value == 0, "Expected SPI disabled"
    assert dut.ps_interrupt.value == 1, "Expected interrupt asserted"

# Test to see if extract board number function works correctly
# The board number is extracted from the over threshold bits
# The board number is the position of the first bit set to 1
# The function should be able to extract the board number from the over threshold bits
@cocotb.test()
async def test_extract_board_number(dut):
    tb = await normal_start_up_with_no_log(dut)
    tb.dut._log.info("STARTING TEST: test_extract_board_number")

    # Start coverage monitor
    start_coverage_monitor(dut)

    # Test each bit position 
    for i in range(8):
        dut.over_thresh.value = 1 << i
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        await tb.check_state(8)
        tb.dut._log.info(f"Checking board number {i}, got {int(dut.board_num.value)}")
        assert dut.board_num.value == i, f"Expected board number {i}, got {int(dut.board_num.value)}"

        await normal_start_up_with_no_log(dut)
    
# Test to see if extract board number function works correctly when multiple DACs are over threshold for instance
# The board number extracted would be the lowest bit set to 1
@cocotb.test()
async def test_extract_board_num_multiple_bits(dut):
    tb = await normal_start_up_with_no_log(dut)
    tb.dut._log.info("STARTING TEST: test_extract_board_num_multiple_bits")

    # Start coverage monitor
    start_coverage_monitor(dut)

    # Test multiple bits set
    dut.over_thresh.value = 0b00110101
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await tb.check_state(8)
    assert dut.board_num.value == 0, f"Board number should be 0 (lowest bit), got {dut.board_num.value}"

    
