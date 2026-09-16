`timescale 1ns/1ps
//=============================================================================
// gpio_ctrl.v - GPIO Controller for RISC-V SoC (DE2-115)
// Verilog 2001
//
// Register Map (addr[3:0]):
//   0x00: LEDR_REG[17:0]  - Red LEDs       (R/W)
//   0x04: LEDG_REG[8:0]   - Green LEDs     (R/W)
//   0x08: SW_REG[17:0]    - Slide switches  (Read-only)
//   0x0C: KEY_REG[3:0]    - Push keys       (Read-only, 1=pressed/active)
//=============================================================================
module gpio_ctrl (
    input  wire        clk,
    input  wire        rst,
    // Bus interface
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata,
    // GPIO outputs
    output wire [17:0] ledr,
    output wire [8:0]  ledg,
    // GPIO inputs
    input  wire [17:0] sw,
    input  wire [3:0]  key
);

    //-------------------------------------------------------------------------
    // Internal registers
    //-------------------------------------------------------------------------
    reg [17:0] ledr_reg;
    reg [8:0]  ledg_reg;

    //-------------------------------------------------------------------------
    // Synchronous write
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ledr_reg <= 18'b0;
            ledg_reg <= 9'b0;
        end else if (we) begin
            case (addr)
                4'h0: ledr_reg <= wdata[17:0];
                4'h4: ledg_reg <= wdata[8:0];
                default: ;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Combinational read
    //-------------------------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (re) begin
            case (addr)
                4'h0: rdata = {14'b0, ledr_reg};
                4'h4: rdata = {23'b0, ledg_reg};
                4'h8: rdata = {14'b0, sw};
                4'hC: rdata = {28'b0, ~key};   // invert: 1=pressed
                default: rdata = 32'b0;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Output assignments
    //-------------------------------------------------------------------------
    assign ledr = ledr_reg;
    assign ledg = ledg_reg;

endmodule
