`timescale 1ns/1ps
module top_soc (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,       // active LOW
    input  wire [17:0] SW,
    output wire [17:0] LEDR,
    output wire [8:0]  LEDG,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [6:0]  HEX4, HEX5, HEX6, HEX7,
    output wire        UART_TXD,
    input  wire        UART_RXD
);

    wire clk = CLOCK_50;
    wire rst = ~KEY[0];

    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we, dmem_re;
    wire [3:0]  dmem_byte_en;

    wire [31:0] dbg_pc;
    wire [31:0] dbg_alu_result;

    top_core u_cpu (
        .clk         (clk),
        .rst         (rst),
        .imem_addr   (imem_addr),
        .imem_data   (imem_data),
        .dmem_addr   (dmem_addr),
        .dmem_wdata  (dmem_wdata),
        .dmem_we     (dmem_we),
        .dmem_re     (dmem_re),
        .dmem_byte_en(dmem_byte_en),
        .dmem_rdata  (dmem_rdata),
        .dbg_pc      (dbg_pc),
        .dbg_alu_result(dbg_alu_result)
    );

    inst_mem u_imem (
        .addr  (imem_addr),
        .inst  (imem_data)
    );

    wire [31:0] dram_addr, dram_wdata, dram_rdata;
    wire        dram_we, dram_re;
    wire [3:0]  dram_byte_en;

    wire [3:0]  gpio_addr, uart_addr, seg7_addr;
    wire [31:0] gpio_wdata, uart_wdata, seg7_wdata;
    wire [31:0] gpio_rdata, uart_rdata, seg7_rdata;
    wire        gpio_we, uart_we, seg7_we;
    wire        gpio_re, uart_re, seg7_re;

    wire [4:0]  timer_addr;
    wire [31:0] timer_wdata, timer_rdata;
    wire        timer_we, timer_re;

    soc_bus u_bus (
        .clk          (clk),
        .rst          (rst),
        .cpu_addr     (dmem_addr),
        .cpu_wdata    (dmem_wdata),
        .cpu_we       (dmem_we),
        .cpu_re       (dmem_re),
        .cpu_byte_en  (dmem_byte_en),
        .cpu_rdata    (dmem_rdata),

        .dram_addr    (dram_addr),
        .dram_wdata   (dram_wdata),
        .dram_we      (dram_we),
        .dram_re      (dram_re),
        .dram_byte_en (dram_byte_en),
        .dram_rdata   (dram_rdata),

        .gpio_addr    (gpio_addr),
        .gpio_wdata   (gpio_wdata),
        .gpio_we      (gpio_we),
        .gpio_re      (gpio_re),
        .gpio_rdata   (gpio_rdata),

        .uart_addr    (uart_addr),
        .uart_wdata   (uart_wdata),
        .uart_we      (uart_we),
        .uart_re      (uart_re),
        .uart_rdata   (uart_rdata),

        .seg7_addr    (seg7_addr),
        .seg7_wdata   (seg7_wdata),
        .seg7_we      (seg7_we),
        .seg7_re      (seg7_re),
        .seg7_rdata   (seg7_rdata),

        .timer_addr   (timer_addr),
        .timer_wdata  (timer_wdata),
        .timer_we     (timer_we),
        .timer_re     (timer_re),
        .timer_rdata  (timer_rdata)
    );

    data_mem u_dmem (
        .clk     (clk),
        .addr    (dram_addr),
        .wdata   (dram_wdata),
        .we      (dram_we),
        .byte_en (dram_byte_en),
        .rdata   (dram_rdata)
    );

    gpio_ctrl u_gpio (
        .clk   (clk),
        .rst   (rst),
        .addr  (gpio_addr),
        .wdata (gpio_wdata),
        .we    (gpio_we),
        .re    (gpio_re),
        .rdata (gpio_rdata),
        .ledr  (LEDR),
        .ledg  (LEDG),
        .sw    (SW),
        .key   (KEY)
    );

    uart_ctrl u_uart (
        .clk      (clk),
        .rst      (rst),
        .addr     (uart_addr),
        .wdata    (uart_wdata),
        .we       (uart_we),
        .re       (uart_re),
        .rdata    (uart_rdata),
        .uart_tx  (UART_TXD),
        .uart_rx  (UART_RXD)
    );

    seg7_ctrl u_seg7 (
        .clk   (clk),
        .rst   (rst),
        .addr  (seg7_addr),
        .wdata (seg7_wdata),
        .we    (seg7_we),
        .re    (seg7_re),
        .rdata (seg7_rdata),
        .hex0  (HEX0),
        .hex1  (HEX1),
        .hex2  (HEX2),
        .hex3  (HEX3),
        .hex4  (HEX4),
        .hex5  (HEX5),
        .hex6  (HEX6),
        .hex7  (HEX7)
    );

    wire timer_irq;
    timer_ctrl u_timer (
        .clk       (clk),
        .rst       (rst),
        .addr      (timer_addr),
        .wdata     (timer_wdata),
        .we        (timer_we),
        .re        (timer_re),
        .rdata     (timer_rdata),
        .timer_irq (timer_irq)
    );

endmodule
