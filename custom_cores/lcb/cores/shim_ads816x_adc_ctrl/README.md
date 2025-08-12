**Updated 2025-08-12**
# ADS816x ADC Control Core

The `shim_ads816x_adc_ctrl` module implements command-driven control for the Texas Instruments ADS816x ADC family (ADS8168, ADS8167, ADS8166) in the Rev D shim firmware. It handles SPI transactions, command sequencing, sample ordering, error detection, and synchronization for up to 8 ADC channels.

## Supported Devices

- ADS8168 (`ADS_MODEL_ID = 8`)
- ADS8167 (`ADS_MODEL_ID = 7`)
- ADS8166 (`ADS_MODEL_ID = 6`)

Set the target device using the `ADS_MODEL_ID` parameter.

## Inputs and Outputs

### Inputs

- `clk`, `resetn`: Main clock and active-low reset.
- `boot_test_skip`: Skips boot-time SPI register test if asserted.
- `boot_test_debug`: Enables debug output during boot test.
- `cmd_word [31:0]`: Command word from buffer.
- `cmd_buf_empty`: Indicates command buffer is empty.
- `trigger`: External trigger signal.
- `miso_sck`, `miso_resetn`, `miso`: SPI MISO clock, reset, and data.
- `data_buf_full`: Indicates data buffer is full.

### Outputs

- `setup_done`: Indicates successful boot/setup (set immediately if `boot_test_skip` is asserted).
- `cmd_word_rd_en`: Enables reading the next command word.
- `waiting_for_trig`: Indicates waiting for trigger.
- `data_word_wr_en`: Enables writing a data word to the output buffer.
- `data_word [31:0]`: Packed ADC data (two samples per word).
- Error flags: `boot_fail`, `cmd_buf_underflow`, `data_buf_overflow`, `unexp_trig`, `bad_cmd`.
- `n_cs`: SPI chip select (active low).
- `mosi`: SPI MOSI data.

## Operation

### Command Types

- **NO_OP (`2'b00`):** Delay or trigger wait.
- **ADC_RD (`2'b01`):** Read ADC samples.
- **SET_ORD (`2'b10`):** Set sample order for ADC channels.
- **CANCEL (`2'b11`):** Cancel current wait or delay.

### Command Word Structure

- `[31:30]` - Command code (2 bits).

#### NO_OP (`2'b00`)
- `[29]` - TRIGGER WAIT: Waits for external trigger if set; otherwise, waits for delay timer.
- `[28]` - CONTINUE: Expects next command immediately after current completes if set.
- `[25:0]` - Delay timer (in clock cycles) if TRIGGER WAIT is not set.

#### ADC_RD (`2'b01`)
- `[29]` - TRIGGER WAIT
- `[28]` - CONTINUE
- `[25:0]` - Delay timer (if TRIGGER WAIT is not set).

Initiates ADC read for 8 channels in the configured order. Output is 4 words, each packing two samples:
- `[15:0]` - First channel value
- `[31:16]` - Second channel value

#### SET_ORD (`2'b10`)
- `[23:21]` - Channel 7 index
- `[20:18]` - Channel 6 index
- `[17:15]` - Channel 5 index
- `[14:12]` - Channel 4 index
- `[11:9]`  - Channel 3 index
- `[8:6]`   - Channel 2 index
- `[5:3]`   - Channel 1 index
- `[2:0]`   - Channel 0 index

Configures sample order for ADC_RD commands. Default order is 0–7.

#### CANCEL (`2'b11`)
- `[29:0]` - Unused.

Cancels current wait/delay if issued when core is in DELAY or TRIG_WAIT state.

### Boot Test Skip

- If `boot_test_skip` is asserted, boot-time SPI register test is skipped and `setup_done` is set immediately.
- Otherwise, the core performs a register write/read test to verify SPI communication before setting `setup_done`.

### State Machine

- **RESET:** Initialization.
- **INIT/TEST_WR/REQ_RD/TEST_RD:** Boot-time SPI test (skipped if `boot_test_skip` is set).
- **IDLE:** Awaiting commands.
- **DELAY/TRIG_WAIT:** Wait for delay or trigger.
- **ADC_RD:** Perform ADC sampling.
- **ERROR:** Halt on error.

### Error Handling

- Boot readback mismatch (`boot_fail`)
- Unexpected triggers (`unexp_trig`)
- Invalid commands (`bad_cmd`)
- Buffer underflow (`cmd_buf_underflow`)
- Buffer overflow (`data_buf_overflow`)

## Notes

- SPI timing and chip select are managed to meet ADS816x requirements.
- Asynchronous FIFO and synchronizer modules are used for safe cross-domain data transfer.
- Data buffer output is packed as two samples per 32-bit word.

## References

- [ADS8168 Datasheet](https://www.ti.com/product/ADS8168)
- [ADS8167 Datasheet](https://www.ti.com/product/ADS8167)
- [ADS8166 Datasheet](https://www.ti.com/product/ADS8166)

---
*See the source code for detailed implementation and signal descriptions.*
