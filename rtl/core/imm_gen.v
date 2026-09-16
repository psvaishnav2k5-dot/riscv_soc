// =============================================================================
// Module      : imm_gen
// Description : RISC-V RV32I Immediate Generator
//               Extracts and sign-extends the immediate for all instruction
//               formats: I, S, B, U, J.
//               Opcode determines the format.
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module imm_gen (
    input  [31:0] instruction,  // Full 32-bit instruction word
    output reg [31:0] imm_out   // Sign-extended immediate value
);

    // Opcode field
    wire [6:0] opcode;
    assign opcode = instruction[6:0];

    // RV32I Opcode constants
    localparam LOAD    = 7'b0000011;  // I-type: LB, LH, LW, LBU, LHU
    localparam OP_IMM  = 7'b0010011;  // I-type: ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
    localparam JALR    = 7'b1100111;  // I-type: JALR
    localparam STORE   = 7'b0100011;  // S-type: SB, SH, SW
    localparam BRANCH  = 7'b1100011;  // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
    localparam LUI     = 7'b0110111;  // U-type: LUI
    localparam AUIPC   = 7'b0010111;  // U-type: AUIPC
    localparam JAL     = 7'b1101111;  // J-type: JAL

    always @(*) begin
        case (opcode)
            // ---- I-type: imm[11:0] = inst[31:20] ----
            LOAD,
            OP_IMM,
            JALR:
                imm_out = {{20{instruction[31]}}, instruction[31:20]};

            // ---- S-type: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7] ----
            STORE:
                imm_out = {{20{instruction[31]}},
                            instruction[31:25],
                            instruction[11:7]};

            // ---- B-type: imm[12|10:5] = inst[31|30:25],
            //              imm[4:1|11]  = inst[11:8|7], imm[0]=0 ----
            BRANCH:
                imm_out = {{19{instruction[31]}},
                            instruction[31],
                            instruction[7],
                            instruction[30:25],
                            instruction[11:8],
                            1'b0};

            // ---- U-type: imm[31:12] = inst[31:12], imm[11:0] = 0 ----
            LUI,
            AUIPC:
                imm_out = {instruction[31:12], 12'b0};

            // ---- J-type: imm[20|10:1|11|19:12] = inst[31|30:21|20|19:12],
            //              imm[0] = 0 ----
            JAL:
                imm_out = {{11{instruction[31]}},
                            instruction[31],
                            instruction[19:12],
                            instruction[20],
                            instruction[30:21],
                            1'b0};

            // Default: zero (NOP / R-type has no immediate)
            default:
                imm_out = 32'b0;
        endcase
    end

endmodule
