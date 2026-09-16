// =============================================================================
// Module      : pipe_reg
// Description : Generic parameterized pipeline register.
//               write_en = 1  → normal operation (capture d on posedge clk)
//               write_en = 0  → stall (hold current q unchanged)
//               flush    = 1  → insert NOP bubble (q <= 0)
//               flush takes priority over stall.
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module pipe_reg #(
    parameter WIDTH = 32
) (
    input                  clk,
    input                  rst,
    input                  write_en,   // 1=write, 0=stall (hold)
    input                  flush,      // 1=clear to 0 (NOP bubble)
    input  [WIDTH-1:0]     d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q <= {WIDTH{1'b0}};
        end else if (flush) begin
            q <= {WIDTH{1'b0}};   // Insert NOP bubble
        end else if (write_en) begin
            q <= d;               // Normal capture
        end
        // else: write_en=0 → stall, hold q
    end

endmodule
