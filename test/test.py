# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start VGA Simulation")

    # Set the clock period to approx 39.7 ns (25.175 MHz for standard VGA)
    clock = Clock(dut.clk, 39.7, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize dedicated inputs and IOs
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Apply Reset
    dut._log.info("Applying Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut._log.info("Reset Released")

    # Run the simulation for a portion of a VGA frame
    # 30,000 cycles roughly covers one full horizontal scanline including blanking
    dut._log.info("Running simulation for 30,000 clock cycles...")
    await ClockCycles(dut.clk, 30000)

    # Verify that the output pins are driving valid binary logic (0 or 1)
    # This assertion prevents failures caused by floating (Z) or undefined (X) states
    assert dut.uo_out.value.is_resolvable, "Output contains undefined (X) or high-impedance (Z) states"
    
    dut._log.info("Test complete")
