`timescale 1ns/1ps
module tb_top_soc;

    reg CLOCK_50;
    reg [3:0] KEY;
    reg [17:0] SW;
    wire [17:0] LEDR;
    wire [8:0] LEDG;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
    wire UART_TXD;
    reg UART_RXD;

    top_soc u_soc (
        .CLOCK_50 (CLOCK_50),
        .KEY      (KEY),
        .SW       (SW),
        .LEDR     (LEDR),
        .LEDG     (LEDG),
        .HEX0     (HEX0),
        .HEX1     (HEX1),
        .HEX2     (HEX2),
        .HEX3     (HEX3),
        .HEX4     (HEX4),
        .HEX5     (HEX5),
        .HEX6     (HEX6),
        .HEX7     (HEX7),
        .UART_TXD (UART_TXD),
        .UART_RXD (UART_RXD)
    );

    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50; // 50 MHz
    end

    initial begin
        // Initialize inputs
        SW = 18'b0;
        KEY = 4'b1111; // Active low buttons, not pressed
        UART_RXD = 1'b1;

        // Reset
        KEY[0] = 1'b0; // Press reset
        #200;
        KEY[0] = 1'b1; // Release reset

        // Run simulation for 50us
        #50000;

        $display(">>> SoC simulation complete.");
        $stop;
    end

endmodule
