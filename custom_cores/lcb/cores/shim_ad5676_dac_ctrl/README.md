**Updated 2025-08-12**
# AD5676 DAC Control Core

The `shim_ad5676_dac_ctrl` module manages the AD5676 DAC in the Rev D shim firmware. It handles SPI communication, command sequencing, calibration, error detection, and synchronization for all 8 DAC channels.

## Inputs and Outputs

### Inputs

- `clk`, `resetn`: Main clock and active-low reset.
- `boot_test_skip`: Skips boot-time DAC test and sets up the core immediately.
- `boot_test_debug`: Enables debug output during boot test.
- `cmd_word [31:0]`: Command word from buffer.
- `cmd_buf_empty`: Indicates if command buffer is empty.
- `trigger`: External trigger signal.
- `ldac_shared`: Shared LDAC signal (for error detection).
- `miso_sck`, `miso_resetn`, `miso`: SPI MISO clock, reset, and data.

### Outputs

- `setup_done`: Indicates successful boot and setup (set immediately if `boot_test_skip` is asserted).
- `cmd_word_rd_en`: Enables reading the next command word.
- `data_word_wr_en`, `data_word [31:0]`: Output data word and write enable (for debug readback).
- `waiting_for_trig`: Indicates waiting for trigger.
- Error flags: `boot_fail`, `cmd_buf_underflow`, `data_buf_overflow`, `unexp_trig`, `bad_cmd`, `cal_oob`, `dac_val_oob`.
- `abs_dac_val_concat [119:0]`: Concatenated absolute DAC values.
- `n_cs`: SPI chip select (active low).
- `mosi`: SPI MOSI data.
- `ldac`: LDAC output for DAC update.

## Operation

### Command Types

- **NO_OP (`2'b00`):** Delay or trigger wait, optional LDAC pulse.
- **DAC_WR (`2'b01`):** Write DAC values (4 words, 2 channels each).
- **SET_CAL (`2'b10`):** Set calibration value for a channel.
- **CANCEL (`2'b11`):** Cancel current wait or delay.

### Command Word Structure

`[31:30]` - Command code (2 bits).

#### NO_OP Command (`2'b00`)
- `[29]` - TRIGGER WAIT: Waits for external trigger if set, otherwise uses delay timer.
- `[28]` - CONTINUE: Expects next command immediately after current completes.
- `[27]` - LDAC: Pulses LDAC at end of command if set.
- `[25:0]` - Delay timer (clock cycles, used if TRIGGER WAIT is not set).

#### DAC_WR Command (`2'b01`)
- Same bit structure as NO_OP for trigger, continue, LDAC, and delay.
- After command, expects 4 words (each `[31:16]` = channel N+1, `[15:0]` = channel N).
- Channels are updated in pairs: (0,1), (2,3), (4,5), (6,7).
- LDAC is pulsed after all channels are updated if LDAC flag is set.

#### SET_CAL Command (`2'b10`)
- `[18:16]` - Channel index (0-7).
- `[15:0]`  - Signed calibration value (range: -`ABS_CAL_MAX` to `ABS_CAL_MAX`).

#### CANCEL Command (`2'b11`)
- Cancels current wait state (trigger or delay) and returns to IDLE.

### State Machine

- **RESET:** Initialization.
- **INIT/TEST_WR/REQ_RD/TEST_RD:** Boot-time test and verification (skipped if `boot_test_skip` is asserted).
- **IDLE:** Awaiting commands.
- **DELAY/TRIG_WAIT:** Wait for delay or trigger.
- **DAC_WR:** Perform DAC update.
- **ERROR:** Halt on error.

### Calibration

- Per-channel signed calibration, bounded by `ABS_CAL_MAX`.
- Calibration values are applied to DAC updates.
- Out-of-bounds calibration or DAC values set error flags.

### Error Handling

- Boot readback mismatch.
- Unexpected triggers or LDAC assertion.
- Invalid commands.
- Buffer underflow/overflow.
- Out-of-bounds calibration or DAC values.

## Notes

- SPI timing and chip select meet AD5676 requirements.
- Offset/signed conversions handled internally.
- Asynchronous FIFO and synchronizer modules ensure safe cross-domain data transfer.
- `boot_test_skip` input allows skipping boot-time DAC test for faster startup or testing.

## References

- [AD5676 Datasheet](https://www.analog.com/en/products/ad5676.html)
- [7 Series Memory Resources](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources)

---
*See the source code for detailed implementation and signal descriptions.*
