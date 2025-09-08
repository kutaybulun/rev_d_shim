import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, ReadWrite

from shim_trigger_core_base import shim_trigger_core_base

async def setup_testbench(dut, clk_period=4, time_unit='ns'):
    tb = shim_trigger_core_base(dut, clk_period, time_unit)
    return tb

# DIRECTED TESTS
@cocotb.test()
async def test_reset(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_reset")

    # Reset the DUT
    await tb.reset()

    # Give time before ending the test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_set_lockout_cmd(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_set_lockout_cmd")

    # First have the DUT at a known state
    await tb.reset()

    # Start monitor_cmd_done and monitor_state_transitions tasks
    monitor_cmd_done_task = cocotb.start_soon(tb.monitor_cmd_done())
    monitor_state_transitions_task = cocotb.start_soon(tb.monitor_state_transitions())

    # Actual Reset
    await tb.reset()

    # Command to set lockout with a valid value
    cmd_type = 2
    lock_out_value1 = tb.TRIGGER_LOCKOUT_MIN
    cmd_word1 = (cmd_type << 29) | (lock_out_value1 & 0x1FFFFFFF)

    # Command to set lockout with an invalid value
    lock_out_value2 = tb.TRIGGER_LOCKOUT_MIN - 1
    cmd_word2 = (cmd_type << 29) | (lock_out_value2 & 0x1FFFFFFF)

    cmd_list = [cmd_word1, cmd_word2]

    # Start the command buffer model
    await RisingEdge(dut.clk)
    cmd_buf_task = cocotb.start_soon(tb.command_buf_model(cmd_list))
    scoreboard_executing_cmd_task = cocotb.start_soon(tb.executing_command_scoreboard(len(cmd_list)))
    await cmd_buf_task
    await scoreboard_executing_cmd_task

    # Give time before ending the test and ensure we don't collide with other tests
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    cmd_buf_task.kill()
    monitor_cmd_done_task.kill()
    monitor_state_transitions_task.kill()
    scoreboard_executing_cmd_task.kill()

@cocotb.test()
async def test_sync_ch_cmd(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_sync_ch_cmd")

    # First have the DUT at a known state
    await tb.reset()

    # Start monitor_cmd_done and monitor_state_transitions tasks
    monitor_cmd_done_task = cocotb.start_soon(tb.monitor_cmd_done())
    monitor_state_transitions_task = cocotb.start_soon(tb.monitor_state_transitions())

    # Actual Reset
    await tb.reset()

    # Command to sync channels
    cmd_type = 1
    cmd_word = (cmd_type << 29)

    cmd_list = [cmd_word]

    # Start the command buffer model
    await RisingEdge(dut.clk)
    cmd_buf_task = cocotb.start_soon(tb.command_buf_model(cmd_list))
    scoreboard_executing_cmd_task = cocotb.start_soon(tb.executing_command_scoreboard(len(cmd_list)))
    await cmd_buf_task
    
    # Drive dac and adc waiting signals to all 1 to allow SYNC_CH to complete after some time
    for _ in range(20):
        await RisingEdge(dut.clk)

    tb.dut.dac_waiting_for_trig.value = 0xFF
    tb.dut.adc_waiting_for_trig.value = 0xFF

    await scoreboard_executing_cmd_task
    # Give time before ending the test and ensure we don't collide with other tests
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    cmd_buf_task.kill()
    monitor_cmd_done_task.kill()
    monitor_state_transitions_task.kill()
    scoreboard_executing_cmd_task.kill()

@cocotb.test()
async def test_expect_ext_trig_cmd(dut):
    tb = await setup_testbench(dut)
    tb.dut._log.info("STARTING TEST: test_expect_ext_trig_cmd")

    # First have the DUT at a known state
    await tb.reset()

    # Start monitor_cmd_done and monitor_state_transitions tasks
    monitor_cmd_done_task = cocotb.start_soon(tb.monitor_cmd_done())
    monitor_state_transitions_task = cocotb.start_soon(tb.monitor_state_transitions())

    # Actual Reset
    await tb.reset()
    
    # Command to set trig_lockout with a valid value
    cmd_type = 2
    lock_out_value = tb.TRIGGER_LOCKOUT_MIN + 5
    cmd_word = (cmd_type << 29) | (lock_out_value & 0x1FFFFFFF)
    cmd_list = [cmd_word]

    # Command to expect external trigger
    cmd_type = 3
    num_external_triggers = 5
    cmd_word = (cmd_type << 29) | (num_external_triggers & 0x1FFFFFFF)
    cmd_list.append(cmd_word)

    # Start the command buffer model
    await RisingEdge(dut.clk)
    cmd_buf_task = cocotb.start_soon(tb.command_buf_model(cmd_list))
    scoreboard_executing_cmd_task = cocotb.start_soon(tb.executing_command_scoreboard(len(cmd_list)))
    await cmd_buf_task

    # Drive external trigger signal after some time
    for _ in range(10):
        await RisingEdge(dut.clk)

    tb.dut.ext_trig.value = 1

    await scoreboard_executing_cmd_task

    # Give time before ending the test and ensure we don't collide with other tests
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    cmd_buf_task.kill()
    monitor_cmd_done_task.kill()
    monitor_state_transitions_task.kill()
    scoreboard_executing_cmd_task.kill()