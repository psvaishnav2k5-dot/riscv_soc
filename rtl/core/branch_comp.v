// =============================================================================
// Module      : branch_comp
// Description : RISC-V Branch Comparator (used in ID stage for early resolution)
//               Compares two 32-bit operands.
//               br_unsigned = 0 → signed comparison  (for BLT, BGE)
//               br_unsigned = 1 → unsigned comparison (for BLTU, BGEU)
//               Outputs:
//                 BrEq  = (rs1 == rs2)
//                 BrLt  = (rs1 < rs2), signed or unsigned based on br_unsigned
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module branch_comp (
    input  [31:0] rs1_data,     // Operand 1 (may be forwarded)
    input  [31:0] rs2_data,     // Operand 2 (may be forwarded)
    input         br_unsigned,  // 0=signed compare, 1=unsigned compare
    output        BrEq,         // 1 if rs1 == rs2
    output        BrLt          // 1 if rs1 < rs2 (signed or unsigned)
);

    // Equality comparison (same for signed and unsigned)
    assign BrEq = (rs1_data == rs2_data);

    // Less-than: signed or unsigned based on br_unsigned
    // Verilog: $signed() for signed comparison
    assign BrLt = br_unsigned ? (rs1_data < rs2_data) :      // unsigned
                                ($signed(rs1_data) < $signed(rs2_data)); // signed

endmodule
