// =============================================================================
// Module      : alu
// Description : 32-bit Arithmetic Logic Unit for RISC-V RV32I
//               Supports all RV32I arithmetic, logic, and shift operations.
//
//   alu_op encoding:
//     4'b0000 = ADD   (add, addi, loads, stores, auipc address)
//     4'b0001 = SUB   (sub)
//     4'b0010 = AND   (and, andi)
//     4'b0011 = OR    (or,  ori)
//     4'b0100 = XOR   (xor, xori)
//     4'b0101 = SLL   (sll, slli)  — shift amount = op2[4:0]
//     4'b0110 = SRL   (srl, srli)  — logical right shift
//     4'b0111 = SRA   (sra, srai)  — arithmetic right shift
//     4'b1000 = SLT   (slt, slti)  — signed less-than → result is 0 or 1
//     4'b1001 = SLTU  (sltu, sltiu)— unsigned less-than
//     4'b1010 = LUI   (lui)        — pass op2 directly (imm already shifted)
//     4'b1011 = unused (reserved)
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module alu #(
    parameter WIDTH = 32
) (
    input  [WIDTH-1:0] op1,     // Operand 1 (rs1 or PC)
    input  [WIDTH-1:0] op2,     // Operand 2 (rs2 or immediate)
    input  [3:0]       alu_op,  // ALU operation select
    output reg [WIDTH-1:0] res  // Result
);

    // Shift amount is lower 5 bits of op2 (RISC-V spec)
    wire [4:0] shamt;
    assign shamt = op2[4:0];

    always @(*) begin
        case (alu_op)
            4'b0000: res = op1 + op2;                          // ADD
            4'b0001: res = op1 - op2;                          // SUB
            4'b0010: res = op1 & op2;                          // AND
            4'b0011: res = op1 | op2;                          // OR
            4'b0100: res = op1 ^ op2;                          // XOR
            4'b0101: res = op1 << shamt;                       // SLL
            4'b0110: res = op1 >> shamt;                       // SRL (logical)
            4'b0111: res = $signed(op1) >>> shamt;             // SRA (arithmetic)
            4'b1000: res = ($signed(op1) < $signed(op2))       // SLT (signed)
                           ? {{(WIDTH-1){1'b0}}, 1'b1}
                           : {WIDTH{1'b0}};
            4'b1001: res = (op1 < op2)                         // SLTU (unsigned)
                           ? {{(WIDTH-1){1'b0}}, 1'b1}
                           : {WIDTH{1'b0}};
            4'b1010: res = op2;                                // LUI (pass-through imm)
            default: res = {WIDTH{1'b0}};
        endcase
    end

endmodule
