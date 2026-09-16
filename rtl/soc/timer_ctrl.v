`timescale 1ns/1ps
//=============================================================================
// timer_ctrl.v - 64-bit MTIME Timer Controller for RISC-V SoC
// Verilog 2001
//
// Register Map (addr[4:0]):
//   0x00: MTIME_LO[31:0]    - Lower 32 bits of mtime counter  (Read-only)
//   0x04: MTIME_HI[31:0]    - Upper 32 bits of mtime counter  (Read-only)
//   0x08: MTIMECMP_LO[31:0] - Lower 32 bits of compare value  (R/W)
//   0x0C: MTIMECMP_HI[31:0] - Upper 32 bits of compare value  (R/W)
//   0x10: CTRL[1:0]         - bit0=timer_en (R/W), bit1=timer_irq (R-only)
//
// timer_irq = 1 when (mtime >= mtimecmp) AND timer_en=1
// IRQ clears automatically when a new MTIMECMP value is written
//=============================================================================
module timer_ctrl (
    input  wire        clk,
    input  wire        rst,
    // Bus interface
    input  wire [4:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata,
    // Timer interrupt output
    output wire        timer_irq
);

    //-------------------------------------------------------------------------
    // Internal registers
    //-------------------------------------------------------------------------
    reg [63:0] mtime;
    reg [63:0] mtimecmp;
    reg        timer_en;

    //-------------------------------------------------------------------------
    // Interrupt logic (combinational)
    //-------------------------------------------------------------------------
    wire irq_active;
    assign irq_active = timer_en && (mtime >= mtimecmp);
    assign timer_irq  = irq_active;

    //-------------------------------------------------------------------------
    // Synchronous write and counter update
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime     <= 64'b0;
            mtimecmp  <= 64'hFFFFFFFF_FFFFFFFF; // start with max so no IRQ at reset
            timer_en  <= 1'b0;
        end else begin
            // Increment counter when enabled
            if (timer_en) begin
                mtime <= mtime + 64'd1;
            end

            // Register writes
            if (we) begin
                case (addr)
                    // 0x00, 0x04: MTIME is read-only (no write)
                    5'h08: mtimecmp[31:0]  <= wdata;        // MTIMECMP_LO write
                    5'h0C: mtimecmp[63:32] <= wdata;        // MTIMECMP_HI write
                    5'h10: timer_en        <= wdata[0];     // CTRL write
                    default: ;
                endcase
            end
        end
    end

    //-------------------------------------------------------------------------
    // Combinational read
    //-------------------------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (re) begin
            case (addr)
                5'h00: rdata = mtime[31:0];
                5'h04: rdata = mtime[63:32];
                5'h08: rdata = mtimecmp[31:0];
                5'h0C: rdata = mtimecmp[63:32];
                5'h10: rdata = {30'b0, irq_active, timer_en};
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule
