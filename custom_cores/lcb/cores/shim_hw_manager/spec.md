# Hardware Manager Core
*Updated 2025-06-04*

The `shim_hw_manager` module manages the hardware system's startup, operation, and shutdown processes. It implements a state machine to sequence power-up, configuration, SPI subsystem enable, and error/shutdown handling.

## Inputs and Outputs

### Inputs

- **Clock and Reset**
  - `clk`: System clock.
  - `aresetn`: Active-low reset.

- **System Control**
  - `sys_en`: System enable (turn the system on).
  - `spi_off`: SPI system powered off.
  - `ext_shutdown`: External shutdown.

- **Configuration Status**
  - `integ_thresh_avg_oob`: Integrator threshold average out of bounds.
  - `integ_window_oob`: Integrator window out of bounds.
  - `integ_en_oob`: Integrator enable register out of bounds.
  - `sys_en_oob`: System enable register out of bounds.
  - `lock_viol`: Configuration lock violation.

- **Shutdown Sense**
  - `shutdown_sense [7:0]`: Shutdown sense (per board).

- **Integrator Status**
  - `over_thresh [7:0]`: DAC over threshold (per board).
  - `thresh_underflow [7:0]`: DAC threshold core FIFO underflow (per board).
  - `thresh_overflow [7:0]`: DAC threshold core FIFO overflow (per board).

- **Trigger Buffer and Commands**
  - `bad_trig_cmd`: Bad trigger command.
  - `trig_buf_overflow`: Trigger buffer overflow.

- **DAC Buffers and Commands**
  - `bad_dac_cmd [7:0]`: Bad DAC command (per board).
  - `dac_cal_oob [7:0]`: DAC calibration out of bounds (per board).
  - `dac_val_oob [7:0]`: DAC value out of bounds (per board).
  - `dac_cmd_buf_underflow [7:0]`: DAC command buffer underflow (per board).
  - `dac_cmd_buf_overflow [7:0]`: DAC command buffer overflow (per board).
  - `unexp_dac_trig [7:0]`: Unexpected DAC trigger (per board).

- **ADC Buffers and Commands**
  - `bad_adc_cmd [7:0]`: Bad ADC command (per board).
  - `adc_cmd_buf_underflow [7:0]`: ADC command buffer underflow (per board).
  - `adc_cmd_buf_overflow [7:0]`: ADC command buffer overflow (per board).
  - `adc_data_buf_underflow [7:0]`: ADC data buffer underflow (per board).
  - `adc_data_buf_overflow [7:0]`: ADC data buffer overflow (per board).
  - `unexp_adc_trig [7:0]`: Unexpected ADC trigger (per board).

### Outputs

- **System Control**
  - `unlock_cfg`: Lock configuration.
  - `spi_clk_power_n`: SPI clock power (negated).
  - `spi_en`: SPI subsystem enable.
  - `shutdown_sense_en`: Shutdown sense enable.
  - `trig_en`: Trigger enable.
  - `n_shutdown_force`: Shutdown force (negated).
  - `n_shutdown_rst`: Shutdown reset (negated).

- **Status and Interrupts**
  - `status_word [31:0]`: Status word containing board number, status code, and state.
  - `ps_interrupt`: Interrupt signal.

## Operation

### State Machine Overview

- **IDLE**: Waits for `sys_en` to go high. Checks for out-of-bounds configuration values. If any OOB condition is detected, transitions to HALTED with the corresponding status code and asserts `ps_interrupt`. If all checks pass, locks configuration and powers up the SPI clock.
- **CONFIRM_SPI_INIT**: Waits for the SPI subsystem to be powered off (`spi_off`). If not powered off within `SPI_INIT_WAIT`, transitions to HALTED with a timeout status.
- **RELEASE_SD_F**: Releases shutdown force (`n_shutdown_force` high) and waits for `SHUTDOWN_FORCE_DELAY`.
- **PULSE_SD_RST**: Pulses `n_shutdown_rst` low for `SHUTDOWN_RESET_PULSE`, then sets it high again.
- **SD_RST_DELAY**: Waits for `SHUTDOWN_RESET_DELAY` after pulsing shutdown reset, then enables shutdown sense, powers up SPI clock, and enables SPI.
- **CONFIRM_SPI_START**: Waits for the SPI subsystem to start (`spi_off` deasserted). If not started within `SPI_START_WAIT`, transitions to HALTED with a timeout status. If started, enables triggers and asserts `ps_interrupt`.
- **RUNNING**: Normal operation. Continuously monitors for halt conditions. If any error or shutdown condition occurs, transitions to HALTED, disables outputs, and asserts `ps_interrupt`.
- **HALTED**: Waits for `sys_en` to go low, then returns to IDLE and clears status.

### Halt/Error Conditions

The system transitions to HALTED and sets the appropriate status code if any of the following occur:
- `sys_en` goes low (processing system shutdown)
- Configuration lock violation (`lock_viol`)
- Shutdown detected via `shutdown_sense` or `ext_shutdown`
- Integrator thresholds exceeded or hardware error underflow/overflow conditions
- Trigger buffer or command errors
- DAC/ADC buffer or command errors
- Unexpected DAC/ADC triggers occur
- SPI subsystem fails to start or initialize within timeout

### Status Word Format

The 32-bit `status_word` is formatted as:
```
[31:29] - Board number (3 bits)
[28:4]  - Status code (25 bits)
[3:0]   - State machine state (4 bits)
```

### Status Codes
Status codes are 25 bits wide and include:

- `0x00001`: `STATUS_OK` - System is operating normally.
- `0x00002`: `STATUS_PS_SHUTDOWN` - Processing system shutdown.
- `0x00100`: `STATUS_SPI_START_TIMEOUT` - SPI start timeout.
- `0x00101`: `STATUS_SPI_INIT_TIMEOUT` - SPI initialization timeout.
- `0x00200`: `STATUS_INTEG_THRESH_AVG_OOB` - Integrator threshold average out of bounds.
- `0x00201`: `STATUS_INTEG_WINDOW_OOB` - Integrator window out of bounds.
- `0x00202`: `STATUS_INTEG_EN_OOB` - Integrator enable register out of bounds.
- `0x00203`: `STATUS_SYS_EN_OOB` - System enable register out of bounds.
- `0x00204`: `STATUS_LOCK_VIOL` - Configuration lock violation.
- `0x00300`: `STATUS_SHUTDOWN_SENSE` - Shutdown sense detected.
- `0x00301`: `STATUS_EXT_SHUTDOWN` - External shutdown triggered.
- `0x00400`: `STATUS_OVER_THRESH` - DAC over threshold.
- `0x00401`: `STATUS_THRESH_UNDERFLOW` - DAC threshold FIFO underflow.
- `0x00402`: `STATUS_THRESH_OVERFLOW` - DAC threshold FIFO overflow.
- `0x00500`: `STATUS_BAD_TRIG_CMD` - Bad trigger command.
- `0x00501`: `STATUS_TRIG_BUF_OVERFLOW` - Trigger buffer overflow.
- `0x00600`: `STATUS_BAD_DAC_CMD` - Bad DAC command.
- `0x00601`: `STATUS_DAC_CAL_OOB` - DAC calibration out of bounds.
- `0x00602`: `STATUS_DAC_VAL_OOB` - DAC value out of bounds.
- `0x00603`: `STATUS_DAC_BUF_UNDERFLOW` - DAC command buffer underflow.
- `0x00604`: `STATUS_DAC_BUF_OVERFLOW` - DAC command buffer overflow.
- `0x00605`: `STATUS_UNEXP_DAC_TRIG` - Unexpected DAC trigger.
- `0x00700`: `STATUS_BAD_ADC_CMD` - Bad ADC command.
- `0x00701`: `STATUS_ADC_BUF_UNDERFLOW` - ADC command buffer underflow.
- `0x00702`: `STATUS_ADC_BUF_OVERFLOW` - ADC command buffer overflow.
- `0x00703`: `STATUS_ADC_DATA_BUF_UNDERFLOW` - ADC data buffer underflow.
- `0x00704`: `STATUS_ADC_DATA_BUF_OVERFLOW` - ADC data buffer overflow.
- `0x00705`: `STATUS_UNEXP_ADC_TRIG` - Unexpected ADC trigger.

## Board Number Extraction

For error/status signals that are 8 bits wide (per board), the board number is extracted as the index of the first asserted bit.
