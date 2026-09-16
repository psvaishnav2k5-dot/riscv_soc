`timescale 1ns/1ps
module soc_bus (
    input  wire        clk,
    input  wire        rst,

    // CPU interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        cpu_we,
    input  wire        cpu_re,
    input  wire [3:0]  cpu_byte_en,
    output wire [31:0] cpu_rdata,

    // DRAM interface
    output wire [31:0] dram_addr,
    output wire [31:0] dram_wdata,
    output wire        dram_we,
    output wire        dram_re,
    output wire [3:0]  dram_byte_en,
    input  wire [31:0] dram_rdata,

    // GPIO interface
    output wire [3:0]  gpio_addr,
    output wire [31:0] gpio_wdata,
    output wire        gpio_we,
    output wire        gpio_re,
    input  wire [31:0] gpio_rdata,

    // UART interface
    output wire [3:0]  uart_addr,
    output wire [31:0] uart_wdata,
    output wire        uart_we,
    output wire        uart_re,
    input  wire [31:0] uart_rdata,

    // SEG7 interface
    output wire [3:0]  seg7_addr,
    output wire [31:0] seg7_wdata,
    output wire        seg7_we,
    output wire        seg7_re,
    input  wire [31:0] seg7_rdata,

    // Timer interface
    output wire [4:0]  timer_addr,
    output wire [31:0] timer_wdata,
    output wire        timer_we,
    output wire        timer_re,
    input  wire [31:0] timer_rdata
);

    wire is_dram   = (cpu_addr[31:14] == 18'h4); 
    wire is_peri   = (cpu_addr[31:28] == 4'h4);
    wire sel_gpio  = is_peri && (cpu_addr[14:12] == 3'b000);
    wire sel_uart  = is_peri && (cpu_addr[14:12] == 3'b001);
    wire sel_seg7  = is_peri && (cpu_addr[14:12] == 3'b010);
    wire sel_timer = is_peri && (cpu_addr[14:12] == 3'b100);

    assign dram_addr    = cpu_addr;
    assign dram_wdata   = cpu_wdata;
    assign dram_we      = cpu_we  & is_dram;
    assign dram_re      = cpu_re  & is_dram;
    assign dram_byte_en = cpu_byte_en;

    assign gpio_addr    = cpu_addr[3:0];
    assign gpio_wdata   = cpu_wdata;
    assign gpio_we      = cpu_we & sel_gpio;
    assign gpio_re      = cpu_re & sel_gpio;

    assign uart_addr    = cpu_addr[3:0];
    assign uart_wdata   = cpu_wdata;
    assign uart_we      = cpu_we & sel_uart;
    assign uart_re      = cpu_re & sel_uart;

    assign seg7_addr    = cpu_addr[3:0];
    assign seg7_wdata   = cpu_wdata;
    assign seg7_we      = cpu_we & sel_seg7;
    assign seg7_re      = cpu_re & sel_seg7;

    assign timer_addr   = cpu_addr[4:0];
    assign timer_wdata  = cpu_wdata;
    assign timer_we     = cpu_we & sel_timer;
    assign timer_re     = cpu_re & sel_timer;

    assign cpu_rdata = is_dram    ? dram_rdata  :
                       sel_gpio   ? gpio_rdata  :
                       sel_uart   ? uart_rdata  :
                       sel_seg7   ? seg7_rdata  :
                       sel_timer  ? timer_rdata :
                       32'h0;

endmodule
