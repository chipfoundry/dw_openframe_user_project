# SPDX-FileCopyrightText: 2026 ChipFoundry
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

"""Chip-level test of the example counter through the double-wide padframe.

The wrapper maps user_proj_counter as follows:
  GPIO 0      user clock (input)
  GPIO 1      active-low reset (input with pull-up)
  GPIO 13:2   count[11:0] (outputs)
  GPIO 62:14  unused, configured as analog (not driven)

The counter is also held in reset by the frame power-on reset (porb_l) and
by the master reset pad (resetb_l), so both paths through the harness are
exercised.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer
from caravel_cocotb.caravel_interfaces import report_test, test_configure

CLK_GPIO = 0
RST_GPIO = 1
COUNT_RANGE = (13, 2)
COUNT_MASK = 0xFFF
FIRST_UNUSED_GPIO = 14
NUM_GPIOS = 63
USER_CLK_NS = 40
# rst_n release is synchronized inside the macro (two flops), so allow a few
# cycles before the counter is expected to be running.
RESET_RELEASE_CYCLES = 4


async def user_cycles(dut, count):
    for _ in range(count):
        await FallingEdge(dut.gpio0)


def read_count(env):
    # monitor_gpio() reads X/Z as 0, so check the pads are really driven.
    high, low = COUNT_RANGE
    for gpio in range(low, high + 1):
        value = env.dut._id(f"gpio{gpio}_monitor", False).value
        assert value.is_resolvable, f"count GPIO {gpio} is not driven ({value})"
    return env.monitor_gpio_range(COUNT_RANGE)


@cocotb.test()
@report_test
async def counter(dut):
    env = await test_configure(dut, timeout_cycles=40000)

    env.drive_gpio(CLK_GPIO, 0)
    env.drive_gpio(RST_GPIO, 0)
    cocotb.start_soon(Clock(dut.gpio0, USER_CLK_NS, units="ns").start())

    await user_cycles(dut, 8)
    assert read_count(env) == 0, f"count is {read_count(env):#x} while rst_n is low"

    for gpio in range(FIRST_UNUSED_GPIO, NUM_GPIOS):
        value = dut._id(f"gpio{gpio}_monitor", False).value
        assert not value.is_resolvable, f"unused GPIO {gpio} is driven ({value})"

    env.drive_gpio(RST_GPIO, 1)
    await user_cycles(dut, RESET_RELEASE_CYCLES)
    start = read_count(env)
    assert 0 < start <= RESET_RELEASE_CYCLES, f"count is {start:#x} after reset release"
    cycles = 300
    await user_cycles(dut, cycles)
    count = read_count(env)
    expected = (start + cycles) & COUNT_MASK
    assert count == expected, f"count {count:#x}, expected {expected:#x} after {cycles} cycles"
    cocotb.log.info(f"[counter] counted {start:#x} -> {count:#x} over {cycles} user clocks")

    # GPIO 1 is configured with a pull-up: an undriven reset pin must not
    # reset the counter.
    env.release_gpio(RST_GPIO)
    start = read_count(env)
    await user_cycles(dut, 16)
    rst_pad = dut.gpio1_monitor.value
    assert rst_pad.is_resolvable and int(rst_pad) == 1, f"GPIO 1 not pulled up ({rst_pad})"
    count = read_count(env)
    assert count == (start + 16) & COUNT_MASK, (
        f"count {count:#x} stalled with GPIO 1 undriven (from {start:#x})"
    )
    cocotb.log.info("[counter] reset pad pull-up keeps the counter running")

    # Assert the master reset pad (resetb_pad -> xres pad -> resetb_l).
    dut.resetb_tb.value = 0
    await user_cycles(dut, 4)
    assert read_count(env) == 0, f"count is {read_count(env):#x} during master reset"
    dut.resetb_tb.value = 1
    await user_cycles(dut, RESET_RELEASE_CYCLES)
    start = read_count(env)
    await user_cycles(dut, 16)
    count = read_count(env)
    assert count == (start + 16) & COUNT_MASK, (
        f"count {count:#x} did not resume after master reset (from {start:#x})"
    )

    await Timer(1, units="ns")
    cocotb.log.info("[counter] reset paths and count outputs verified")
