// =============================================================================
// Module      : inst_mem
// Description : Instruction Memory (Read-Only ROM).
//               - 4096 x 32-bit words = 16 KB
//               - Word-addressed (addr[13:2] used, byte address input)
//               - Asynchronous (combinational) read
//               - Initialized from "instructions.txt" via $readmemh
//               - Quartus II: Infers M9K Block RAM (ROM mode)
//               - For synthesis initialization, use .mif file in Quartus
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module inst_mem (
    input  [31:0] addr,     // Byte address (word-aligned; addr[1:0] ignored)
    output [31:0] inst      // 32-bit instruction word
);

    // 256 x 32-bit instruction memory (1 KB)
    // Fits easily in FPGA LEs since it's asynchronous
    reg [31:0] mem [0:255];

    // Load memory contents from hex file for simulation
    // Working directory = E:/Project/RISC_SOC  (ModelSim project root)
    // Quartus synthesis: use altsyncram with .mif file
    initial begin
        $readmemh("mem/instructions.txt", mem);
    end

    // Combinational read ??? word-addressed (divide byte addr by 4)
    assign inst = mem[addr[9:2]];

endmodule
