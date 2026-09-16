`timescale 1ns/1ps
//=============================================================================
// seg7_ctrl.v - 7-Segment Display Controller for RISC-V SoC (DE2-115)
// Verilog 2001
//
// Register Map (addr[3:0]):
//   0x00: SEG01_REG - bits[6:0]=HEX0 pattern, bits[14:8]=HEX1 pattern (R/W)
//   0x04: SEG23_REG - bits[6:0]=HEX2 pattern, bits[14:8]=HEX3 pattern (R/W)
//   0x08: SEG45_REG - bits[6:0]=HEX4 pattern, bits[14:8]=HEX5 pattern (R/W)
//   0x0C: SEG67_REG - bits[6:0]=HEX6 pattern, bits[14:8]=HEX7 pattern (R/W)
//
// Segment encoding: CPU writes 1=segment ON
// Hardware output is active-LOW: hex_out = ~reg_value
//=============================================================================
module seg7_ctrl (
    input  wire        clk,
    input  wire        rst,
    // Bus interface
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata,
    // 7-segment outputs (active LOW to DE2-115 hardware)
    output wire [6:0]  hex0,
    output wire [6:0]  hex1,
    output wire [6:0]  hex2,
    output wire [6:0]  hex3,
    output wire [6:0]  hex4,
    output wire [6:0]  hex5,
    output wire [6:0]  hex6,
    output wire [6:0]  hex7
);

    //-------------------------------------------------------------------------
    // Internal registers (logical: 1=segment ON)
    //-------------------------------------------------------------------------
    reg [15:0] seg01_reg;   // [6:0]=HEX0, [14:8]=HEX1
    reg [15:0] seg23_reg;   // [6:0]=HEX2, [14:8]=HEX3
    reg [15:0] seg45_reg;   // [6:0]=HEX4, [14:8]=HEX5
    reg [15:0] seg67_reg;   // [6:0]=HEX6, [14:8]=HEX7

    //-------------------------------------------------------------------------
    // Write logic
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seg01_reg <= 16'b0;
            seg23_reg <= 16'b0;
            seg45_reg <= 16'b0;
            seg67_reg <= 16'b0;
        end else if (we) begin
            case (addr)
                4'h0: seg01_reg <= wdata[15:0];
                4'h4: seg23_reg <= wdata[15:0];
                4'h8: seg45_reg <= wdata[15:0];
                4'hC: seg67_reg <= wdata[15:0];
                default: ;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Combinational read (returns logical values as written)
    //-------------------------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (re) begin
            case (addr)
                4'h0: rdata = {17'b0, seg01_reg[14:8], 1'b0, seg01_reg[6:0]};
                4'h4: rdata = {17'b0, seg23_reg[14:8], 1'b0, seg23_reg[6:0]};
                4'h8: rdata = {17'b0, seg45_reg[14:8], 1'b0, seg45_reg[6:0]};
                4'hC: rdata = {17'b0, seg67_reg[14:8], 1'b0, seg67_reg[6:0]};
                default: rdata = 32'b0;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Output: invert for active-LOW DE2-115 hardware
    //-------------------------------------------------------------------------
    assign hex0 = ~seg01_reg[6:0];
    assign hex1 = ~seg01_reg[14:8];
    assign hex2 = ~seg23_reg[6:0];
    assign hex3 = ~seg23_reg[14:8];
    assign hex4 = ~seg45_reg[6:0];
    assign hex5 = ~seg45_reg[14:8];
    assign hex6 = ~seg67_reg[6:0];
    assign hex7 = ~seg67_reg[14:8];

endmodule
