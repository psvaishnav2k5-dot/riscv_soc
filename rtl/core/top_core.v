// =============================================================================
// Module      : top_core
// Description : 5-Stage Pipelined RISC-V RV32I CPU Core
//               Stages: IF → ID → EX → MEM → WB
//
//   Pipeline Features:
//     - Data forwarding (EX/MEM→EX, MEM/WB→EX) via fwd_unit
//     - Load-use hazard detection and stall via hazard_unit
//     - Early branch resolution in ID stage (1-cycle branch penalty)
//     - Branch/JAL target = PC + imm (dedicated ID-stage adder)
//     - JALR target       = rs1_fwd + imm (dedicated ID-stage adder)
//     - JAL/JALR link address (PC+4) carried through pipeline to WB
//     - Full RV32I: R, I, S, B, U, J instruction types
//     - Byte/halfword/word loads and stores with sign extension
//
//   External Memory Interface:
//     - imem_addr/imem_data : instruction memory (ROM)
//     - dmem_*              : data memory (RAM) with byte enables
//     inst_mem and data_mem instantiated externally (in top_soc or testbench)
//
// Author      : RISC-V SoC Project
// Target      : Altera Cyclone IV E (DE2-115), Quartus II 13.1
// Language    : Verilog 2001
// =============================================================================

module top_core (
    input        clk,
    input        rst,

    // ---- Instruction Memory Interface ----
    output [31:0] imem_addr,    // Byte address of instruction to fetch
    input  [31:0] imem_data,    // Instruction word from memory

    // ---- Data Memory Interface ----
    output [31:0] dmem_addr,    // Byte address for load/store
    output [31:0] dmem_wdata,   // Write data (byte-replicated for SB/SH)
    output [3:0]  dmem_byte_en, // Byte enables (from funct3 + addr[1:0])
    output        dmem_we,      // Write enable (store instructions)
    output        dmem_re,      // Read enable  (load instructions)
    input  [31:0] dmem_rdata,   // Raw 32-bit read data (sign-ext in WB)

    // ---- Debug Outputs ----
    output [31:0] dbg_pc,
    output [31:0] dbg_alu_result
);

// =============================================================================
// -------------------------  IF STAGE  ----------------------------------------
// =============================================================================

    // Program Counter
    wire [31:0] pc;
    wire [31:0] next_pc;
    wire [31:0] pc_plus4;
    wire        PC_write;       // from hazard unit

    assign pc_plus4 = pc + 32'd4;
    assign imem_addr = pc;
    assign dbg_pc    = pc;

    program_counter u_pc (
        .clk      (clk),
        .rst      (rst),
        .pc_write (PC_write),
        .next_pc  (next_pc),
        .pc       (pc)
    );

// =============================================================================
// -------------------------  IF/ID PIPELINE REGISTER  -------------------------
// =============================================================================

    wire        IF_ID_write;    // from hazard unit (stall)
    wire        IF_flush;       // branch taken / JAL / JALR flush

    // Registered PC and instruction in ID stage
    reg [31:0] pc_ID;
    reg [31:0] inst_ID;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_ID   <= 32'b0;
            inst_ID <= 32'b0;
        end else if (IF_flush) begin
            // Branch taken / jump: insert NOP bubble (keep PC for link calc)
            inst_ID <= 32'b0;   // NOP = ADDI x0,x0,0
            pc_ID   <= pc;      // PC of flushed instruction (not needed but clean)
        end else if (IF_ID_write) begin
            pc_ID   <= pc;
            inst_ID <= imem_data;
        end
        // else: stall — hold current IF/ID values
    end

// =============================================================================
// -------------------------  ID STAGE  ----------------------------------------
// =============================================================================

    // ---- Instruction decode ----
    wire [6:0] opcode_ID;
    wire [4:0] rs1_ID, rs2_ID, rd_ID;
    wire [2:0] funct3_ID;
    wire [6:0] funct7_ID;

    assign opcode_ID = inst_ID[6:0];
    assign rd_ID     = inst_ID[11:7];
    assign funct3_ID = inst_ID[14:12];
    assign rs1_ID    = inst_ID[19:15];
    assign rs2_ID    = inst_ID[24:20];
    assign funct7_ID = inst_ID[31:25];

    // ---- Immediate Generator ----
    wire [31:0] imm_ID;
    imm_gen u_imm_gen (
        .instruction (inst_ID),
        .imm_out     (imm_ID)
    );

    // ---- Write-back signals (from WB stage) needed for reg file write ----
    wire        reg_write_en_WB;
    wire [4:0]  rd_WB;
    wire [31:0] write_data_WB;

    // ---- Register File ----
    wire [31:0] reg_data1, reg_data2;
    reg_file u_reg_file (
        .clk        (clk),
        .rst        (rst),
        .write_en   (reg_write_en_WB),
        .rd         (rd_WB),
        .write_data (write_data_WB),
        .rs1        (rs1_ID),
        .rs2        (rs2_ID),
        .read_data1 (reg_data1),
        .read_data2 (reg_data2)
    );

    // ---- Control Unit ----
    wire        alu_src_ID;
    wire        ASel_ID;
    wire [3:0]  alu_op_ID;
    wire        reg_write_en_ID;
    wire        mem_write_ID;
    wire        mem_read_ID;
    wire        mem_to_reg_ID;
    wire        is_link_ID;
    wire        br_unsigned_ID;
    wire [1:0]  pc_src_ID;
    wire        BrEq, BrLt;

    control_unit u_ctrl (
        .opcode       (opcode_ID),
        .funct3       (funct3_ID),
        .funct7       (funct7_ID),
        .BrEq         (BrEq),
        .BrLt         (BrLt),
        .alu_src      (alu_src_ID),
        .ASel         (ASel_ID),
        .alu_op       (alu_op_ID),
        .reg_write_en (reg_write_en_ID),
        .mem_write    (mem_write_ID),
        .mem_read     (mem_read_ID),
        .mem_to_reg   (mem_to_reg_ID),
        .is_link      (is_link_ID),
        .br_unsigned  (br_unsigned_ID),
        .pc_src       (pc_src_ID)
    );

    // ---- Branch forwarding muxes (forward to branch comparator in ID stage) ----
    // These forward from EX/MEM and MEM/WB to allow correct branch comparison
    // when a RAW hazard exists between a prior instruction and the branch.
    wire [31:0] EX_MEM_fwd_data;   // from EX/MEM (defined later)
    wire [31:0] MEM_WB_fwd_data;   // from MEM/WB (defined later)
    wire        EX_MEM_reg_write;
    wire [4:0]  EX_MEM_rd;
    wire        MEM_WB_reg_write_fwd;
    wire [4:0]  MEM_WB_rd_fwd;

    // Branch source forward select for rs1
    wire [31:0] br_rs1_data;
    assign br_rs1_data = (EX_MEM_reg_write && (EX_MEM_rd != 5'b0) && (EX_MEM_rd == rs1_ID)) ? EX_MEM_fwd_data  :
                         (MEM_WB_reg_write_fwd && (MEM_WB_rd_fwd != 5'b0) && (MEM_WB_rd_fwd == rs1_ID)) ? MEM_WB_fwd_data :
                         reg_data1;

    // Branch source forward select for rs2
    wire [31:0] br_rs2_data;
    assign br_rs2_data = (EX_MEM_reg_write && (EX_MEM_rd != 5'b0) && (EX_MEM_rd == rs2_ID)) ? EX_MEM_fwd_data  :
                         (MEM_WB_reg_write_fwd && (MEM_WB_rd_fwd != 5'b0) && (MEM_WB_rd_fwd == rs2_ID)) ? MEM_WB_fwd_data :
                         reg_data2;

    // ---- Branch Comparator (ID stage, uses forwarded rs1/rs2) ----
    branch_comp u_br_comp (
        .rs1_data    (br_rs1_data),
        .rs2_data    (br_rs2_data),
        .br_unsigned (br_unsigned_ID),
        .BrEq        (BrEq),
        .BrLt        (BrLt)
    );

    // ---- PC Targets computed in ID stage ----
    wire [31:0] branch_jal_target;    // PC + imm (for BRANCH and JAL)
    wire [31:0] jalr_sum;             // rs1_fwd + imm (intermediate wire)
    wire [31:0] jalr_target;          // JALR target with bit0 cleared (RISC-V spec)

    assign branch_jal_target = pc_ID + imm_ID;
    assign jalr_sum          = br_rs1_data + imm_ID;
    assign jalr_target       = {jalr_sum[31:1], 1'b0};  // clear bit0 per RISC-V spec

    // ---- PC Source Mux ----
    //   pc_src: 00=PC+4, 01=branch/JAL target, 10=JALR target
    assign next_pc = (pc_src_ID == 2'b01) ? branch_jal_target :
                     (pc_src_ID == 2'b10) ? jalr_target       :
                     pc_plus4;

    // ---- IF flush: any jump or taken branch flushes the IF/ID register ----
    assign IF_flush = (pc_src_ID != 2'b00);

    // ---- Hazard Unit ----
    wire        IF_ID_write_haz;  // hazard unit output
    wire        PC_write_haz;
    wire        ID_EX_flush;      // flush ID/EX control signals (NOP bubble)

    // Connect from ID/EX register (defined below)
    wire        ID_EX_mem_read;
    wire [4:0]  ID_EX_rd;
    wire [4:0]  ID_EX_rs1;
    wire [4:0]  ID_EX_rs2;

    hazard_unit u_hazard (
        .ID_EX_mem_read (ID_EX_mem_read),
        .ID_EX_rd       (ID_EX_rd),
        .IF_ID_rs1      (rs1_ID),
        .IF_ID_rs2      (rs2_ID),
        .PC_write       (PC_write_haz),
        .IF_ID_write    (IF_ID_write_haz),
        .ID_EX_flush    (ID_EX_flush)
    );

    // Combine hazard stall with branch flush priority
    // Branch flush takes priority — even on stall, if branch taken, flush IF
    assign PC_write    = PC_write_haz;
    assign IF_ID_write = IF_ID_write_haz && !IF_flush;
    // (if branch taken during a stall, the stall bubble is in ID — flush wins)

// =============================================================================
// -------------------------  ID/EX PIPELINE REGISTER  -------------------------
// =============================================================================

    // Data registers
    reg [31:0] pc_EX;
    reg [31:0] pc_plus4_EX;
    reg [31:0] rs1_data_EX;
    reg [31:0] rs2_data_EX;
    reg [31:0] imm_EX;
    reg [4:0]  rd_EX_r;
    reg [4:0]  rs1_EX_r;
    reg [4:0]  rs2_EX_r;
    reg [2:0]  funct3_EX;
    // Control registers
    reg        alu_src_EX;
    reg        ASel_EX;
    reg [3:0]  alu_op_EX;
    reg        reg_write_en_EX;
    reg        mem_write_EX;
    reg        mem_read_EX;
    reg        mem_to_reg_EX;
    reg        is_link_EX;

    // Assign to named wires for hazard/forwarding units
    assign ID_EX_rd       = rd_EX_r;
    assign ID_EX_rs1      = rs1_EX_r;
    assign ID_EX_rs2      = rs2_EX_r;
    assign ID_EX_mem_read = mem_read_EX;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // NOP bubble
            pc_EX          <= 32'b0;
            pc_plus4_EX    <= 32'b0;
            rs1_data_EX    <= 32'b0;
            rs2_data_EX    <= 32'b0;
            imm_EX         <= 32'b0;
            rd_EX_r        <= 5'b0;
            rs1_EX_r       <= 5'b0;
            rs2_EX_r       <= 5'b0;
            funct3_EX      <= 3'b0;
            alu_src_EX     <= 1'b0;
            ASel_EX        <= 1'b0;
            alu_op_EX      <= 4'b0;
            reg_write_en_EX<= 1'b0;
            mem_write_EX   <= 1'b0;
            mem_read_EX    <= 1'b0;
            mem_to_reg_EX  <= 1'b0;
            is_link_EX     <= 1'b0;
        end else if (ID_EX_flush) begin
            // NOP bubble
            pc_EX          <= 32'b0;
            pc_plus4_EX    <= 32'b0;
            rs1_data_EX    <= 32'b0;
            rs2_data_EX    <= 32'b0;
            imm_EX         <= 32'b0;
            rd_EX_r        <= 5'b0;
            rs1_EX_r       <= 5'b0;
            rs2_EX_r       <= 5'b0;
            funct3_EX      <= 3'b0;
            alu_src_EX     <= 1'b0;
            ASel_EX        <= 1'b0;
            alu_op_EX      <= 4'b0;
            reg_write_en_EX<= 1'b0;
            mem_write_EX   <= 1'b0;
            mem_read_EX    <= 1'b0;
            mem_to_reg_EX  <= 1'b0;
            is_link_EX     <= 1'b0;
        end else begin
            pc_EX          <= pc_ID;
            pc_plus4_EX    <= pc_ID + 32'd4;
            rs1_data_EX    <= reg_data1;
            rs2_data_EX    <= reg_data2;
            imm_EX         <= imm_ID;
            rd_EX_r        <= rd_ID;
            rs1_EX_r       <= rs1_ID;
            rs2_EX_r       <= rs2_ID;
            funct3_EX      <= funct3_ID;
            alu_src_EX     <= alu_src_ID;
            ASel_EX        <= ASel_ID;
            alu_op_EX      <= alu_op_ID;
            reg_write_en_EX<= reg_write_en_ID;
            mem_write_EX   <= mem_write_ID;
            mem_read_EX    <= mem_read_ID;
            mem_to_reg_EX  <= mem_to_reg_ID;
            is_link_EX     <= is_link_ID;
        end
    end

// =============================================================================
// -------------------------  EX STAGE  ----------------------------------------
// =============================================================================

    // ---- Forwarding Unit ----
    wire [1:0] ForwardA, ForwardB;
    wire [31:0] EX_MEM_alu_result; // from EX/MEM reg (defined below)
    // MEM/WB write data — connects to WB stage output (write_data_WB defined later in file)
    // NOTE: In Verilog 2001 this forward reference is valid for wires
    wire [31:0] MEM_WB_write_data;
    assign MEM_WB_write_data = write_data_WB;  // FIX: was undriven → caused X in forwarding mux

    fwd_unit u_fwd (
        .EX_MEM_reg_write (EX_MEM_reg_write),
        .EX_MEM_rd        (EX_MEM_rd),
        .MEM_WB_reg_write (MEM_WB_reg_write_fwd),
        .MEM_WB_rd        (MEM_WB_rd_fwd),
        .ID_EX_rs1        (ID_EX_rs1),
        .ID_EX_rs2        (ID_EX_rs2),
        .ForwardA         (ForwardA),
        .ForwardB         (ForwardB)
    );

    // ---- ALU Operand A Mux ----
    // ForwardA: 00=reg, 10=EX/MEM, 01=MEM/WB
    // ASel: 0=rs1(forwarded), 1=PC
    wire [31:0] fwd_rs1;
    assign fwd_rs1 = (ForwardA == 2'b10) ? EX_MEM_alu_result :
                     (ForwardA == 2'b01) ? MEM_WB_write_data  :
                     rs1_data_EX;

    wire [31:0] alu_op1;
    assign alu_op1 = ASel_EX ? pc_EX : fwd_rs1;

    // ---- ALU Operand B Mux ----
    // ForwardB: 00=reg, 10=EX/MEM, 01=MEM/WB
    // alu_src: 0=rs2(forwarded), 1=imm
    wire [31:0] fwd_rs2;
    assign fwd_rs2 = (ForwardB == 2'b10) ? EX_MEM_alu_result :
                     (ForwardB == 2'b01) ? MEM_WB_write_data  :
                     rs2_data_EX;

    wire [31:0] alu_op2;
    assign alu_op2 = alu_src_EX ? imm_EX : fwd_rs2;

    // ---- ALU ----
    wire [31:0] alu_result_EX;
    alu u_alu (
        .op1    (alu_op1),
        .op2    (alu_op2),
        .alu_op (alu_op_EX),
        .res    (alu_result_EX)
    );
    assign dbg_alu_result = alu_result_EX;

    // ---- Byte Enable Generation for Stores ----
    // Based on funct3 and the two LSBs of the address (alu_result_EX[1:0])
    wire [3:0] store_byte_en;
    wire [31:0] store_wdata;

    // Byte enable and write data for SB/SH/SW
    assign store_byte_en =
        (funct3_EX == 3'b000) ?                        // SB (byte)
            (4'b0001 << alu_result_EX[1:0]) :
        (funct3_EX == 3'b001) ?                        // SH (halfword)
            (alu_result_EX[1] ? 4'b1100 : 4'b0011) :
        4'b1111;                                        // SW (word, default)

    // Replicate write data for byte/halfword stores
    assign store_wdata =
        (funct3_EX == 3'b000) ?                        // SB: replicate byte
            {4{fwd_rs2[7:0]}} :
        (funct3_EX == 3'b001) ?                        // SH: replicate halfword
            {2{fwd_rs2[15:0]}} :
        fwd_rs2;                                        // SW: full word

// =============================================================================
// -------------------------  EX/MEM PIPELINE REGISTER  ------------------------
// =============================================================================

    reg [31:0] alu_result_MEM;
    reg [31:0] rs2_data_MEM;     // store write data (after forwarding)
    reg [3:0]  byte_en_MEM;      // byte enables for store
    reg [4:0]  rd_MEM_r;
    reg [2:0]  funct3_MEM;
    reg [31:0] pc_plus4_MEM;
    // Control
    reg        reg_write_en_MEM;
    reg        mem_write_MEM;
    reg        mem_read_MEM;
    reg        mem_to_reg_MEM;
    reg        is_link_MEM;

    // Expose for forwarding (EX/MEM → EX forwarding)
    assign EX_MEM_alu_result = alu_result_MEM;
    assign EX_MEM_reg_write  = reg_write_en_MEM;
    assign EX_MEM_rd         = rd_MEM_r;
    // Forward data for branches (EX/MEM → ID branch comparator)
    assign EX_MEM_fwd_data   = alu_result_MEM;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_result_MEM  <= 32'b0;
            rs2_data_MEM    <= 32'b0;
            byte_en_MEM     <= 4'b0;
            rd_MEM_r        <= 5'b0;
            funct3_MEM      <= 3'b0;
            pc_plus4_MEM    <= 32'b0;
            reg_write_en_MEM<= 1'b0;
            mem_write_MEM   <= 1'b0;
            mem_read_MEM    <= 1'b0;
            mem_to_reg_MEM  <= 1'b0;
            is_link_MEM     <= 1'b0;
        end else begin
            alu_result_MEM  <= alu_result_EX;
            rs2_data_MEM    <= store_wdata;
            byte_en_MEM     <= store_byte_en;
            rd_MEM_r        <= rd_EX_r;
            funct3_MEM      <= funct3_EX;
            pc_plus4_MEM    <= pc_plus4_EX;
            reg_write_en_MEM<= reg_write_en_EX;
            mem_write_MEM   <= mem_write_EX;
            mem_read_MEM    <= mem_read_EX;
            mem_to_reg_MEM  <= mem_to_reg_EX;
            is_link_MEM     <= is_link_EX;
        end
    end

// =============================================================================
// -------------------------  MEM STAGE  ----------------------------------------
// =============================================================================

    // Data memory interface signals
    assign dmem_addr    = alu_result_MEM;
    assign dmem_wdata   = rs2_data_MEM;
    assign dmem_byte_en = byte_en_MEM;
    assign dmem_we      = mem_write_MEM;
    assign dmem_re      = mem_read_MEM;
    // dmem_rdata comes from external data_mem

// =============================================================================
// -------------------------  MEM/WB PIPELINE REGISTER  ------------------------
// =============================================================================

    reg [31:0] alu_result_WB_r;
    reg [31:0] mem_rdata_WB;
    reg [4:0]  rd_WB_r;
    reg [2:0]  funct3_WB;
    reg [31:0] pc_plus4_WB;
    // Control
    reg        reg_write_en_WB_r;
    reg        mem_to_reg_WB;
    reg        is_link_WB;

    // Expose for MEM/WB → EX forwarding
    assign MEM_WB_reg_write_fwd = reg_write_en_WB_r;
    assign MEM_WB_rd_fwd        = rd_WB_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_result_WB_r  <= 32'b0;
            mem_rdata_WB     <= 32'b0;
            rd_WB_r          <= 5'b0;
            funct3_WB        <= 3'b0;
            pc_plus4_WB      <= 32'b0;
            reg_write_en_WB_r<= 1'b0;
            mem_to_reg_WB    <= 1'b0;
            is_link_WB       <= 1'b0;
        end else begin
            alu_result_WB_r  <= alu_result_MEM;
            mem_rdata_WB     <= dmem_rdata;    // Raw memory read data
            rd_WB_r          <= rd_MEM_r;
            funct3_WB        <= funct3_MEM;
            pc_plus4_WB      <= pc_plus4_MEM;
            reg_write_en_WB_r<= reg_write_en_MEM;
            mem_to_reg_WB    <= mem_to_reg_MEM;
            is_link_WB       <= is_link_MEM;
        end
    end

// =============================================================================
// -------------------------  WB STAGE  ----------------------------------------
// =============================================================================

    // ---- Load data sign/zero extension (based on funct3_WB) ----
    //   funct3: 000=LB, 001=LH, 010=LW, 100=LBU, 101=LHU
    wire [31:0] load_data_ext;
    wire [7:0]  load_byte;
    wire [15:0] load_half;
    wire [1:0]  byte_offset;

    // Select byte/half based on address offset stored in alu_result_WB_r[1:0]
    assign byte_offset = alu_result_WB_r[1:0];

    // Extract byte from correct byte lane
    assign load_byte =
        (byte_offset == 2'b00) ? mem_rdata_WB[7:0]   :
        (byte_offset == 2'b01) ? mem_rdata_WB[15:8]  :
        (byte_offset == 2'b10) ? mem_rdata_WB[23:16] :
                                 mem_rdata_WB[31:24];

    // Extract halfword from correct half lane
    assign load_half =
        alu_result_WB_r[1] ? mem_rdata_WB[31:16] : mem_rdata_WB[15:0];

    assign load_data_ext =
        (funct3_WB == 3'b000) ? {{24{load_byte[7]}},  load_byte}    : // LB  (signed)
        (funct3_WB == 3'b001) ? {{16{load_half[15]}}, load_half}    : // LH  (signed)
        (funct3_WB == 3'b010) ? mem_rdata_WB                        : // LW
        (funct3_WB == 3'b100) ? {24'b0, load_byte}                  : // LBU (unsigned)
        (funct3_WB == 3'b101) ? {16'b0, load_half}                  : // LHU (unsigned)
        mem_rdata_WB;                                                   // default

    // ---- WB Write-Back Mux ----
    // Priority: link address > memory data > ALU result
    wire [31:0] alu_or_mem;
    assign alu_or_mem  = mem_to_reg_WB ? load_data_ext : alu_result_WB_r;
    assign write_data_WB = is_link_WB ? pc_plus4_WB : alu_or_mem;

    // Connect to reg_file write ports (declared earlier at top of ID stage)
    assign reg_write_en_WB = reg_write_en_WB_r;
    assign rd_WB           = rd_WB_r;

    // ---- MEM/WB forward data for EX and branch forwarding ----
    assign MEM_WB_fwd_data = write_data_WB;

endmodule
