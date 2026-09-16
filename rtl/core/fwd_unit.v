// =============================================================================
// Module      : fwd_unit
// Description : Data Forwarding Unit for RAW Hazard Resolution.
//               Detects Read-After-Write hazards and selects ALU operands
//               from the appropriate pipeline stage to avoid stalls.
//
//   ForwardA / ForwardB encoding:
//     2'b00 = No forwarding — use register file output (no hazard)
//     2'b10 = EX/MEM forward — ALU result from EX/MEM pipeline register
//             (1-cycle-old result: previous instruction's EX output)
//     2'b01 = MEM/WB forward — write-back data from MEM/WB pipeline register
//             (2-cycle-old result: two instructions ago)
//
//   Priority: EX/MEM forwarding takes priority over MEM/WB forwarding
//             (closer, fresher result)
//
//   Conditions:
//     - Only forward if the source register (Rd) is NOT x0 (hardwired zero)
//     - Only forward if RegWrite is enabled in that stage
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module fwd_unit (
    // EX/MEM pipeline register signals
    input        EX_MEM_reg_write,  // RegWrite in EX/MEM stage
    input  [4:0] EX_MEM_rd,         // Destination register in EX/MEM

    // MEM/WB pipeline register signals
    input        MEM_WB_reg_write,  // RegWrite in MEM/WB stage
    input  [4:0] MEM_WB_rd,         // Destination register in MEM/WB

    // Current EX stage source registers (from ID/EX pipeline register)
    input  [4:0] ID_EX_rs1,         // Source register 1 in EX stage
    input  [4:0] ID_EX_rs2,         // Source register 2 in EX stage

    // Forwarding select outputs (to EX stage muxes)
    output reg [1:0] ForwardA,      // Select for ALU operand A
    output reg [1:0] ForwardB       // Select for ALU operand B
);

    always @(*) begin
        // ---- ForwardA: select source for ALU operand A (rs1) ----
        if (EX_MEM_reg_write &&
            (EX_MEM_rd != 5'b0) &&
            (EX_MEM_rd == ID_EX_rs1)) begin
            ForwardA = 2'b10;   // Forward from EX/MEM (1-cycle hazard)
        end
        else if (MEM_WB_reg_write &&
                 (MEM_WB_rd != 5'b0) &&
                 (MEM_WB_rd == ID_EX_rs1)) begin
            ForwardA = 2'b01;   // Forward from MEM/WB (2-cycle hazard)
        end
        else begin
            ForwardA = 2'b00;   // No forwarding — use register file
        end

        // ---- ForwardB: select source for ALU operand B (rs2) ----
        if (EX_MEM_reg_write &&
            (EX_MEM_rd != 5'b0) &&
            (EX_MEM_rd == ID_EX_rs2)) begin
            ForwardB = 2'b10;   // Forward from EX/MEM (1-cycle hazard)
        end
        else if (MEM_WB_reg_write &&
                 (MEM_WB_rd != 5'b0) &&
                 (MEM_WB_rd == ID_EX_rs2)) begin
            ForwardB = 2'b01;   // Forward from MEM/WB (2-cycle hazard)
        end
        else begin
            ForwardB = 2'b00;   // No forwarding — use register file
        end
    end

endmodule
