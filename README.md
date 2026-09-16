# 32-bit RISC-V System-on-Chip (RV32I)

A custom 32-bit RISC-V processor (RV32I Base Integer Instruction Set) designed from scratch in Verilog 2001. The processor features a classic 5-stage pipeline with full data hazard resolution (forwarding and stalling) and memory-mapped I/O peripherals. 

This project was successfully simulated, synthesized for a 90nm ASIC technology node, and physically implemented on an Altera Cyclone IV FPGA.

## Features
* **Architecture:** 32-bit RISC-V (RV32I)
* **Pipeline:** 5-stage (Fetch, Decode, Execute, Memory, Write-Back)
* **Hazard Handling:** Full Forwarding Unit and Hazard Detection Unit (stalls for load-use data hazards and control hazards)
* **Memory-Mapped I/O:**
  * **GPIO:** Switches and Push-buttons (Inputs), Red/Green LEDs (Outputs)
  * **7-Segment Display Controller:** Drives 8x HEX displays on the FPGA
  * **UART:** 115200 baud, 8-N-1 serial communication (Hardware baud rate divider)
  * **Timer:** 64-bit mtime and mtimecmp hardware timer

## Implementation & Testing
1. **RTL Simulation:** Verified using Cadence Xcelium (	b_soc.v).
2. **ASIC Synthesis:** Logic synthesis performed using Cadence Genus targeting a standard 90nm foundry library.
3. **FPGA Hardware:** Successfully mapped, routed, and tested on the **Terasic DE2-115 (Altera Cyclone IV E)** development board using Quartus II.

## Repository Structure
* tl/core/ - The RISC-V CPU core files (ALU, Program Counter, Registers, Hazard Unit, etc.)
* tl/soc/ - The memory-mapped peripherals and top-level SoC integration (UART, GPIO, Bus Decoder)
* b_soc.v - Testbench for simulation
* syn_risc.tcl - Synthesis script for Cadence Genus

## Getting Started
To test the CPU on an FPGA:
1. Open the project in Quartus II.
2. Compile the design (	op_soc.v as top-level entity).
3. Assign the physical pins for the 50MHz clock, Switches, LEDs, and UART TX/RX.
4. Program the board using the USB-Blaster.

To observe the UART output, connect a logic analyzer (or Quartus SignalTap) to the uart_tx pin and trigger on a falling edge.
