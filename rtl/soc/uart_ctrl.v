`timescale 1ns/1ps
//=============================================================================
// uart_ctrl.v - UART 8N1 Controller for RISC-V SoC (50 MHz clock)
// Verilog 2001
//
// Register Map (addr[3:0]):
//   0x00: TX_DATA[7:0]   - Write: load TX byte and start TX (if idle)
//                          Read:  last byte written to TX
//   0x04: RX_DATA[7:0]   - Read:  received byte (read clears rx_valid flag)
//   0x08: STATUS[1:0]    - bit0=tx_idle (1=ready), bit1=rx_valid
//   0x0C: BAUD_DIV[15:0] - Baud rate divisor R/W, default=434 (50MHz/115200)
//
// TX: IDLE -> START -> DATA(8 bits, LSB first) -> STOP -> IDLE
// RX: IDLE -> START(sample midpoint) -> DATA(8 bits) -> STOP -> IDLE
// uart_tx = 1 during IDLE/STOP, 0 during START, shift_reg[0] during DATA
//=============================================================================
module uart_ctrl (
    input  wire        clk,
    input  wire        rst,
    // Bus interface
    input  wire [3:0]  addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata,
    // UART signals
    output reg         uart_tx,
    input  wire        uart_rx
);

    //-------------------------------------------------------------------------
    // State machine encoding (2-bit localparams, Verilog 2001)
    //-------------------------------------------------------------------------
    localparam [1:0] IDLE  = 2'b00;
    localparam [1:0] START = 2'b01;
    localparam [1:0] DATA  = 2'b10;
    localparam [1:0] STOP  = 2'b11;

    //-------------------------------------------------------------------------
    // Registers
    //-------------------------------------------------------------------------
    reg [7:0]  tx_data_reg;
    reg [7:0]  rx_data_reg;
    reg        rx_valid;
    reg [15:0] baud_div_reg;

    // TX state machine
    reg [1:0]  tx_state;
    reg [7:0]  tx_shift;
    reg [15:0] tx_baud_cnt;
    reg [2:0]  tx_bit_cnt;

    // RX state machine
    reg [1:0]  rx_state;
    reg [7:0]  rx_shift;
    reg [15:0] rx_baud_cnt;
    reg [2:0]  rx_bit_cnt;

    // RX metastability synchronizer (2-FF chain)
    reg        rx_sync0;
    reg        rx_sync1;

    //-------------------------------------------------------------------------
    // TX idle flag (combinational)
    //-------------------------------------------------------------------------
    wire tx_idle;
    assign tx_idle = (tx_state == IDLE);

    //-------------------------------------------------------------------------
    // RX 2-FF metastability synchronizer
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= uart_rx;
            rx_sync1 <= rx_sync0;
        end
    end

    //-------------------------------------------------------------------------
    // TX State Machine
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state    <= IDLE;
            tx_shift    <= 8'b0;
            tx_baud_cnt <= 16'b0;
            tx_bit_cnt  <= 3'b0;
            uart_tx     <= 1'b1;
            tx_data_reg <= 8'b0;
        end else begin
            case (tx_state)
                IDLE: begin
                    uart_tx <= 1'b1;
                    // Detect bus write to TX_DATA register
                    if (we && (addr == 4'h0)) begin
                        tx_data_reg <= wdata[7:0];
                        tx_shift    <= wdata[7:0];
                        tx_baud_cnt <= 16'b0;
                        tx_state    <= START;
                    end
                end

                START: begin
                    uart_tx <= 1'b0;  // start bit
                    if (tx_baud_cnt >= baud_div_reg - 1) begin
                        tx_baud_cnt <= 16'b0;
                        tx_bit_cnt  <= 3'b0;
                        tx_state    <= DATA;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 16'd1;
                    end
                end

                DATA: begin
                    uart_tx <= tx_shift[0];  // LSB first
                    if (tx_baud_cnt >= baud_div_reg - 1) begin
                        tx_baud_cnt <= 16'b0;
                        tx_shift    <= {1'b0, tx_shift[7:1]};  // shift right
                        if (tx_bit_cnt == 3'd7) begin
                            tx_state <= STOP;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 3'd1;
                        end
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 16'd1;
                    end
                end

                STOP: begin
                    uart_tx <= 1'b1;  // stop bit
                    if (tx_baud_cnt >= baud_div_reg - 1) begin
                        tx_baud_cnt <= 16'b0;
                        tx_state    <= IDLE;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 16'd1;
                    end
                end

                default: begin
                    tx_state <= IDLE;
                    uart_tx  <= 1'b1;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // RX State Machine
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state    <= IDLE;
            rx_shift    <= 8'b0;
            rx_baud_cnt <= 16'b0;
            rx_bit_cnt  <= 3'b0;
            rx_data_reg <= 8'b0;
            rx_valid    <= 1'b0;
        end else begin
            // Clear rx_valid on bus read of RX_DATA
            if (re && (addr == 4'h4)) begin
                rx_valid <= 1'b0;
            end

            case (rx_state)
                IDLE: begin
                    // Detect falling edge (start bit) on synchronized RX
                    if (rx_sync1 == 1'b0) begin
                        // Sample at midpoint: wait baud_div/2 cycles
                        rx_baud_cnt <= 16'b0;
                        rx_state    <= START;
                    end
                end

                START: begin
                    // Wait for midpoint of start bit
                    if (rx_baud_cnt >= ((baud_div_reg >> 1) - 1)) begin
                        rx_baud_cnt <= 16'b0;
                        rx_bit_cnt  <= 3'b0;
                        rx_state    <= DATA;
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 16'd1;
                    end
                end

                DATA: begin
                    if (rx_baud_cnt >= baud_div_reg - 1) begin
                        rx_baud_cnt <= 16'b0;
                        rx_shift    <= {rx_sync1, rx_shift[7:1]};  // LSB first, shift in MSB side
                        if (rx_bit_cnt == 3'd7) begin
                            rx_state <= STOP;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 3'd1;
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 16'd1;
                    end
                end

                STOP: begin
                    if (rx_baud_cnt >= baud_div_reg - 1) begin
                        rx_baud_cnt <= 16'b0;
                        rx_data_reg <= rx_shift;
                        rx_valid    <= 1'b1;
                        rx_state    <= IDLE;
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 16'd1;
                    end
                end

                default: begin
                    rx_state <= IDLE;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Baud divider register write (sync) - default 434 = 50MHz/115200
    //-------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_div_reg <= 16'd434;
        end else if (we && (addr == 4'hC)) begin
            baud_div_reg <= wdata[15:0];
        end
    end

    //-------------------------------------------------------------------------
    // Combinational read
    //-------------------------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (re) begin
            case (addr)
                4'h0: rdata = {24'b0, tx_data_reg};
                4'h4: rdata = {24'b0, rx_data_reg};
                4'h8: rdata = {30'b0, rx_valid, tx_idle};
                4'hC: rdata = {16'b0, baud_div_reg};
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule
