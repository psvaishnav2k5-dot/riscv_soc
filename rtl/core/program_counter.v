// =============================================================================
// Module      : program_counter
// Description : 32-bit Program Counter register.
//               pc_write = 1  → update PC to next_pc on clock edge
//               pc_write = 0  → stall (hold current PC)
//               rst           → reset PC to 0x00000000
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module program_counter (
    input        clk,
    input        rst,
    input        pc_write,      // 1=update PC, 0=stall (hold)
    input  [31:0] next_pc,
    output reg [31:0] pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'h0000_0000;
        else if (pc_write)
            pc <= next_pc;
        // else: stall — hold PC
    end

endmodule
