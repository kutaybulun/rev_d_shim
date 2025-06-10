import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb_coverage.coverage import *
import atexit

STATE_BIN_LABELS = {
    1: "IDLE",
    2: "CONFIRM_SPI_INIT",
    3: "RELEASE_SD_F",
    4: "PULSE_SD_RST",
    5: "SD_RST_DELAY",
    6: "CONFIRM_SPI_START",
    7: "RUNNING",
    8: "HALTED"
}

STATUS_BIN_LABELS = {
    0:    "STATUS_EMPTY",
    1:    "STATUS_OK",
    2:    "STATUS_PS_SHUTDOWN",
    256:  "STATUS_SPI_START_TIMEOUT",
    257:  "STATUS_SPI_INIT_TIMEOUT",
    512:  "STATUS_INTEG_THRESH_AVG_OOB",
    513:  "STATUS_INTEG_WINDOW_OOB",
    514:  "STATUS_INTEG_EN_OOB",
    515:  "STATUS_SYS_EN_OOB",
    516:  "STATUS_LOCK_VIOL",
    768:  "STATUS_SHUTDOWN_SENSE",
    769:  "STATUS_EXT_SHUTDOWN",
    1024: "STATUS_OVER_THRESH",
    1025: "STATUS_THRESH_UNDERFLOW",
    1026: "STATUS_THRESH_OVERFLOW",
    1280: "STATUS_BAD_TRIG_CMD",
    1281: "STATUS_TRIG_BUF_OVERFLOW",
    1536: "STATUS_BAD_DAC_CMD",
    1537: "STATUS_DAC_CAL_OOB",
    1538: "STATUS_DAC_VAL_OOB",
    1539: "STATUS_DAC_BUF_UNDERFLOW",
    1540: "STATUS_DAC_BUF_OVERFLOW",
    1541: "STATUS_UNEXP_DAC_TRIG",
    1792: "STATUS_BAD_ADC_CMD",
    1793: "STATUS_ADC_BUF_UNDERFLOW",
    1794: "STATUS_ADC_BUF_OVERFLOW",
    1795: "STATUS_ADC_DATA_BUF_UNDERFLOW",
    1796: "STATUS_ADC_DATA_BUF_OVERFLOW",
    1797: "STATUS_UNEXP_ADC_TRIG",
}


@CoverPoint("hw_manager.state",
            xf = lambda dut: int(dut.state.value),
            bins = list(STATE_BIN_LABELS.keys()),
            rel = lambda x, y: x == y,
            at_least = 1)
@CoverPoint("hw_manager.status_code",
            xf = lambda dut: dut.status_code.value,
            bins = list(STATUS_BIN_LABELS.keys()),
            rel = lambda x, y: x == y,
            at_least = 1)
def sample_coverage(dut):
    pass

async def _coverage_monitor(dut):
    await RisingEdge(dut.clk)
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()
        sample_coverage(dut)

def start_coverage_monitor(dut):
    cocotb.start_soon(_coverage_monitor(dut))

def write_report():
    coverage_db.export_to_xml("hw_manager_coverage.xml")
    coverage_db.export_to_yaml("hw_manager_coverage.yaml")

atexit.register(write_report)
