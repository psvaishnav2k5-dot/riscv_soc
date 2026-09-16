// =============================================================================
// Module      : reg_file
// Description : RISC-V 32x32 Register File
//               - 32 general-purpose 32-bit registers (x0 - x31)
//               - x0 is hardwired to 0 (reads always return 0, writes ignored)
//               - 2 asynchronous read ports (rs1, rs2)
//               - 1 synchronous write port (rd, on posedge clk)
//               - Write-before-read: if rd == rs1 and write_en=1,
//                 read returns the NEW value (forwarding within reg file)
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module reg_file (
    input        clk,
    input        rst,
    // Write port
    input        write_en,
    input  [4:0]  rd,           // Destination register address
    input  [31:0] write_data,   // Data to write
    // Read port 1
    input  [4:0]  rs1,          // Source register 1 address
    output [31:0] read_data1,   // Data from rs1
    // Read port 2
    input  [4:0]  rs2,          // Source register 2 address
    output [31:0] read_data2    // Data from rs2
);

    // Register array — 32 registers x 32 bits
    reg [31:0] regs [1:31];  // x1..x31 (x0 is implicit 0)

    // Synchronous write (x0 write is ignored)
    always @(posedge clk or posedge rst) begin : REG_WRITE_BLOCK
        integer i;
        if (rst) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (write_en && (rd != 5'b0))
                regs[rd] <= write_data;
        end
    end

    // Asynchronous read with x0 hardwired to 0
    // Write-before-read: forward new value if write happening to same register
    assign read_data1 = (rs1 == 5'b0) ? 32'b0 :
                        (write_en && (rd == rs1) && (rd != 5'b0)) ? write_data :
                        regs[rs1];

    assign read_data2 = (rs2 == 5'b0) ? 32'b0 :
                        (write_en && (rd == rs2) && (rd != 5'b0)) ? write_data :
                        regs[rs2];

endmodule
