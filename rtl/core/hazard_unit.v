// =============================================================================
// Module      : hazard_unit
// Description : Hazard Detection Unit — Load-Use Stall Generator.
//               Detects load-use hazards: when a LOAD instruction in the EX
//               stage writes a register needed by the immediately following
//               instruction in ID stage.
//
//   Hazard condition:
//     ID_EX_mem_read == 1 (current EX instruction is a LOAD)
//     AND (ID_EX_rd == IF_ID_rs1 OR ID_EX_rd == IF_ID_rs2) (register match)
//     AND ID_EX_rd != 0 (not x0)
//
//   Actions on hazard detection:
//     PC_write    = 0  → stall PC (don't advance)
//     IF_ID_write = 0  → stall IF/ID register (keep current instruction)
//     ID_EX_flush = 1  → flush ID/EX register (insert NOP bubble)
//
//   Note: Branch hazards (when branch reads a register being loaded/computed)
//   are handled by the stall mechanism plus the flush from branch resolution.
//   A load-before-branch results in 2 stall cycles automatically.
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module hazard_unit (
    // From ID/EX pipeline register
    input        ID_EX_mem_read,  // 1 if EX-stage instruction is a LOAD
    input  [4:0] ID_EX_rd,        // Destination register of EX-stage instruction

    // From IF/ID pipeline register (current ID-stage instruction)
    input  [4:0] IF_ID_rs1,       // Source register 1 of ID-stage instruction
    input  [4:0] IF_ID_rs2,       // Source register 2 of ID-stage instruction

    // Stall/flush control outputs
    output       PC_write,        // 1=allow PC update, 0=stall PC
    output       IF_ID_write,     // 1=allow IF/ID update, 0=stall IF/ID
    output       ID_EX_flush      // 1=flush ID/EX (insert NOP bubble)
);

    // Hazard detected when:
    //   EX-stage instruction is a load AND
    //   its destination matches a source of the ID-stage instruction
    wire load_use_hazard;
    assign load_use_hazard = ID_EX_mem_read &&
                             (ID_EX_rd != 5'b0) &&
                             ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2));

    // On hazard: stall PC and IF/ID, flush ID/EX (NOP bubble)
    assign PC_write    = ~load_use_hazard;  // 0 on hazard (stall)
    assign IF_ID_write = ~load_use_hazard;  // 0 on hazard (stall)
    assign ID_EX_flush =  load_use_hazard;  // 1 on hazard (flush)

endmodule
