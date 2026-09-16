// =============================================================================
// Module      : control_unit
// Description : RISC-V RV32I Main Control Unit (Instruction Decoder)
//               Generates all control signals from opcode, funct3, funct7.
//               Branch decisions use BrEq/BrLt from branch_comp (ID stage).
//
//   Control Signal Summary:
//     alu_src     : 0=rs2, 1=imm  (ALU operand B source)
//     ASel        : 0=rs1, 1=PC   (ALU operand A source — for AUIPC)
//     alu_op[3:0] : ALU operation (see alu.v for encoding)
//     reg_write_en: 1=write result to rd
//     mem_write   : 1=store to data memory
//     mem_read    : 1=load from data memory (used by hazard detection)
//     mem_to_reg  : 0=ALU result→rd, 1=memory read data→rd
//     is_link     : 1=rd←PC+4 (for JAL and JALR link address write)
//     br_unsigned : 0=signed compare, 1=unsigned compare (to branch_comp)
//     pc_src[1:0] : 00=PC+4, 01=branch/JAL target, 10=JALR target
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module control_unit (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    input        BrEq,          // From branch_comp: rs1 == rs2
    input        BrLt,          // From branch_comp: rs1 <  rs2 (signed or unsigned)
    // Control outputs
    output reg       alu_src,       // ALU op B: 0=rs2, 1=imm
    output reg       ASel,          // ALU op A: 0=rs1, 1=PC
    output reg [3:0] alu_op,
    output reg       reg_write_en,
    output reg       mem_write,
    output reg       mem_read,
    output reg       mem_to_reg,
    output reg       is_link,       // 1 → rd = PC+4 (JAL/JALR link address)
    output reg       br_unsigned,   // 0=signed, 1=unsigned (to branch_comp)
    output reg [1:0] pc_src         // 00=PC+4, 01=branch/JAL, 10=JALR
);

    // ---- Opcode constants (RISC-V RV32I) ----
    localparam OP      = 7'b0110011; // R-type
    localparam OP_IMM  = 7'b0010011; // I-type ALU
    localparam LOAD    = 7'b0000011; // I-type Load
    localparam STORE   = 7'b0100011; // S-type
    localparam BRANCH  = 7'b1100011; // B-type
    localparam JAL     = 7'b1101111; // J-type
    localparam JALR    = 7'b1100111; // I-type
    localparam LUI     = 7'b0110111; // U-type
    localparam AUIPC   = 7'b0010111; // U-type

    // ---- ALU operation codes (match alu.v) ----
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;

    always @(*) begin
        // ---- Safe defaults (NOP behavior) ----
        alu_src      = 1'b0;
        ASel         = 1'b0;
        alu_op       = ALU_ADD;
        reg_write_en = 1'b0;
        mem_write    = 1'b0;
        mem_read     = 1'b0;
        mem_to_reg   = 1'b0;
        is_link      = 1'b0;
        br_unsigned  = 1'b0;
        pc_src       = 2'b00;

        case (opcode)

            // ------------------------------------------------------------------
            // R-type: add, sub, sll, slt, sltu, xor, srl, sra, or, and
            // ------------------------------------------------------------------
            OP: begin
                reg_write_en = 1'b1;
                case (funct3)
                    3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD; // add/sub
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // sra/srl
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end

            // ------------------------------------------------------------------
            // I-type ALU: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
            // ------------------------------------------------------------------
            OP_IMM: begin
                reg_write_en = 1'b1;
                alu_src = 1'b1;  // use immediate
                case (funct3)
                    3'b000: alu_op = ALU_ADD;                        // ADDI
                    3'b001: alu_op = ALU_SLL;                        // SLLI
                    3'b010: alu_op = ALU_SLT;                        // SLTI
                    3'b011: alu_op = ALU_SLTU;                       // SLTIU
                    3'b100: alu_op = ALU_XOR;                        // XORI
                    3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL; // SRAI/SRLI
                    3'b110: alu_op = ALU_OR;                         // ORI
                    3'b111: alu_op = ALU_AND;                        // ANDI
                    default: alu_op = ALU_ADD;
                endcase
            end

            // ------------------------------------------------------------------
            // Load: lb, lh, lw, lbu, lhu
            // Address = rs1 + sign_ext(imm)
            // ------------------------------------------------------------------
            LOAD: begin
                reg_write_en = 1'b1;
                alu_src      = 1'b1;  // immediate for address calculation
                mem_read     = 1'b1;
                mem_to_reg   = 1'b1;
                alu_op       = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // Store: sb, sh, sw
            // Address = rs1 + sign_ext(imm)
            // ------------------------------------------------------------------
            STORE: begin
                alu_src   = 1'b1;  // immediate for address calculation
                mem_write = 1'b1;
                alu_op    = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // Branch: beq, bne, blt, bge, bltu, bgeu
            // Branch target = PC + sign_ext(imm<<1) — computed in ID stage
            // ------------------------------------------------------------------
            BRANCH: begin
                alu_op = ALU_ADD;  // ALU not used for branch (branch_comp handles it)
                case (funct3)
                    3'b000: begin // BEQ
                        br_unsigned = 1'b0;
                        pc_src = BrEq ? 2'b01 : 2'b00;
                    end
                    3'b001: begin // BNE
                        br_unsigned = 1'b0;
                        pc_src = (!BrEq) ? 2'b01 : 2'b00;
                    end
                    3'b100: begin // BLT (signed)
                        br_unsigned = 1'b0;
                        pc_src = BrLt ? 2'b01 : 2'b00;
                    end
                    3'b101: begin // BGE (signed: taken if NOT less-than)
                        br_unsigned = 1'b0;
                        pc_src = (!BrLt) ? 2'b01 : 2'b00;
                    end
                    3'b110: begin // BLTU (unsigned)
                        br_unsigned = 1'b1;
                        pc_src = BrLt ? 2'b01 : 2'b00;
                    end
                    3'b111: begin // BGEU (unsigned: taken if NOT less-than)
                        br_unsigned = 1'b1;
                        pc_src = (!BrLt) ? 2'b01 : 2'b00;
                    end
                    default: begin
                        br_unsigned = 1'b0;
                        pc_src = 2'b00;
                    end
                endcase
            end

            // ------------------------------------------------------------------
            // JAL: rd = PC+4, PC = PC + sign_ext(imm<<1)
            // Jump target = PC + imm — same adder as branch target in ID stage
            // ------------------------------------------------------------------
            JAL: begin
                reg_write_en = 1'b1;
                is_link      = 1'b1;   // rd ← PC+4 (link address)
                pc_src       = 2'b01;  // jump to PC + imm
                alu_op       = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // JALR: rd = PC+4, PC = (rs1 + sign_ext(imm)) & ~1
            // Jump target = rs1_fwd + imm — computed in ID using dedicated adder
            // ------------------------------------------------------------------
            JALR: begin
                reg_write_en = 1'b1;
                is_link      = 1'b1;   // rd ← PC+4 (link address)
                alu_src      = 1'b1;   // imm as ALU op B (for address, not used for rd)
                pc_src       = 2'b10;  // jump to rs1 + imm
                alu_op       = ALU_ADD;
            end

            // ------------------------------------------------------------------
            // LUI: rd = {imm[31:12], 12'b0}
            // ALU: op2 = imm (already upper-shifted by imm_gen), op = LUI (pass)
            // ------------------------------------------------------------------
            LUI: begin
                reg_write_en = 1'b1;
                alu_src      = 1'b1;   // imm as ALU op B
                alu_op       = ALU_LUI; // pass-through op2
            end

            // ------------------------------------------------------------------
            // AUIPC: rd = PC + {imm[31:12], 12'b0}
            // ALU: op A = PC, op B = imm, op = ADD
            // ------------------------------------------------------------------
            AUIPC: begin
                reg_write_en = 1'b1;
                ASel         = 1'b1;   // PC as ALU op A
                alu_src      = 1'b1;   // imm as ALU op B
                alu_op       = ALU_ADD;
            end

            default: begin
                // Unknown opcode — NOP (all defaults already set)
            end
        endcase
    end

endmodule
