// =============================================================================
// Module      : data_mem
// Description : Data Memory (Read-Write RAM) with byte/halfword/word access.
//               - 4096 x 32-bit words = 16 KB
//               - Synchronous write with byte enables
//               - Asynchronous (combinational) read
//               - Byte/halfword/word size controlled via funct3
//               - Read data returned as raw 32-bit word; sign extension
//                 is performed in the WB stage of top_core.v
//
//   Write byte enable generation (based on funct3 and addr[1:0]):
//     SB (funct3=000): write 1 byte at addr[1:0] offset
//     SH (funct3=001): write 2 bytes at addr[1] offset (half-word aligned)
//     SW (funct3=010): write all 4 bytes
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module data_mem (
    input        clk,
    // Write interface
    input  [31:0] addr,       // Byte address (word-aligned for SW/LW)
    input  [31:0] wdata,      // Write data (caller replicates for SB/SH)
    input  [3:0]  byte_en,    // Byte enables (from top_core based on funct3)
    input         we,         // Write enable (1=write)
    // Read interface
    output [31:0] rdata       // Raw 32-bit word read (no sign extension here)
);

    // 256 x 32-bit data memory (1 KB)
    reg [31:0] mem [0:255];

    // Initialize all memory to 0 first, then overwrite with hex file
    // This prevents X (unknown) on uninitialized addresses in simulation
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'b0;
        $readmemh("mem/data_mem.txt", mem);
    end

    // Synchronous write with individual byte enables
    always @(posedge clk) begin
        if (we) begin
            if (byte_en[0]) mem[addr[9:2]][7:0]   <= wdata[7:0];
            if (byte_en[1]) mem[addr[9:2]][15:8]  <= wdata[15:8];
            if (byte_en[2]) mem[addr[9:2]][23:16] <= wdata[23:16];
            if (byte_en[3]) mem[addr[9:2]][31:24] <= wdata[31:24];
        end
    end

    // Asynchronous (combinational) read
    assign rdata = mem[addr[9:2]];

endmodule
