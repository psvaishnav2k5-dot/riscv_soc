// =============================================================================
// Module      : tb_top_core
// Description : Testbench for the 5-Stage Pipelined RISC-V CPU Core
//               Instantiates top_core, inst_mem, and data_mem.
//               Runs a test program from instructions.hex.
//               Dumps waveforms for ModelSim viewing.
// Author      : RISC-V SoC Project
// Simulator   : ModelSim-Altera 10.1d (Quartus II 13.1)
// Language    : Verilog 2001
// =============================================================================

`timescale 1ns / 1ps

module tb_top_core;

    // ---- DUT signals ----
    reg        clk;
    reg        rst;

    // Instruction memory interface
    wire [31:0] imem_addr;
    wire [31:0] imem_data;

    // Data memory interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_byte_en;
    wire        dmem_we;
    wire        dmem_re;
    wire [31:0] dmem_rdata;

    // Debug
    wire [31:0] dbg_pc;
    wire [31:0] dbg_alu_result;

    // ---- Clock Generation ----
    // 25 MHz clock (40 ns period) — matches DE2-115 target
    initial clk = 0;
    always #20 clk = ~clk;   // 40 ns period = 25 MHz

    // ---- DUT Instantiation ----
    top_core u_dut (
        .clk          (clk),
        .rst          (rst),
        .imem_addr    (imem_addr),
        .imem_data    (imem_data),
        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_byte_en (dmem_byte_en),
        .dmem_we      (dmem_we),
        .dmem_re      (dmem_re),
        .dmem_rdata   (dmem_rdata),
        .dbg_pc       (dbg_pc),
        .dbg_alu_result(dbg_alu_result)
    );

    // ---- Instruction Memory ----
    inst_mem u_imem (
        .addr (imem_addr),
        .inst (imem_data)
    );

    // ---- Data Memory ----
    data_mem u_dmem (
        .clk      (clk),
        .addr     (dmem_addr),
        .wdata    (dmem_wdata),
        .byte_en  (dmem_byte_en),
        .we       (dmem_we),
        .rdata    (dmem_rdata)
    );

    // ---- Test Stimulus ----
    integer i;
    initial begin
        // Dump waveforms
        $dumpfile("tb_top_core.vcd");
        $dumpvars(0, tb_top_core);

        // Reset for 5 cycles
        rst = 1;
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst = 0;

        $display("==============================================");
        $display(" RISC-V CPU Core Simulation Start");
        $display("==============================================");

        // Run for 200 cycles — enough to execute test program
        repeat(200) @(posedge clk);

        $display("==============================================");
        $display(" Simulation Complete — Register File Dump:");
        $display("==============================================");

        // Dump register file contents at end of simulation
        // (Access via hierarchical reference)
        for (i = 0; i < 32; i = i + 1) begin
            if (i == 0)
                $display("  x%0d  = 0x%08h  (hardwired 0)", i, 32'b0);
            else
                $display("  x%0d  = 0x%08h", i, u_dut.u_reg_file.regs[i]);
        end

        $display("==============================================");
        $finish;
    end

    // ---- Monitor: print each instruction execution ----
    always @(posedge clk) begin
        if (!rst) begin
            $display("[T=%0t] PC=0x%08h | INST=0x%08h | ALU=0x%08h",
                     $time, dbg_pc, imem_data, dbg_alu_result);
        end
    end

    // ---- Timeout watchdog ----
    initial begin
        #100000; // 100 us timeout
        $display("TIMEOUT: Simulation exceeded time limit!");
        $finish;
    end

endmodule
