// =============================================================================
//   __          __     __     __     __          __     __     __  
//  |  |        |__|   |  |   |__|   |  |        |__|   |  |   |__| 
//   | |_____    __     | |    __     | |_____    __     | |    __  
//   |  ___  \  |  |    | |   |  |    |  ___  \  |  |    | |   |  | 
//   | |___| |   | |    | |    | |    | |___| |   | |    | |    | | 
//  |________/  |___|  |___|  |___|  |________/  |___|  |___|  |___|
//
//  ------------------ TECH OTAKUS SAVE THE WORLD ------------------
//
//  Filename    : uart_tx.sv
//  Version     : 1.00
//  Author      : ( °- °)つロ
//  Date        : 2024-10-24
// -----------------------------------------------------------------
//  Description :
//                UART
// =============================================================================

module uart_tx # (
    parameter CLK_FREQ = 100,       // clk frequency: MHz
    parameter BIT_RATE = 115200     // uart frequency: Hz
)(
    input   logic       clk,
    input   logic       valid,
    input   logic [7:0] data,
    output  logic       ready,
    output  logic       uart_o
);

//******************************************************************************
// Parameter
//******************************************************************************

    localparam CYCLE = (CLK_FREQ * 1000 * 1000) / (BIT_RATE);

//******************************************************************************
// State Machine
//******************************************************************************

    enum logic [3:0] {
        IDLE  = 4'b0001,
        START = 4'b0010,
        DATA  = 4'b0100,
        STOP  = 4'b1000
    } state = IDLE;

//******************************************************************************
// logic
//******************************************************************************

    logic [$clog2(CYCLE)-1:0] cnt = '0;
    logic [2:0] bit_cnt = '0;

    logic [7:0] bits = '0;

//******************************************************************************
// ready
//******************************************************************************

    assign ready = (state==IDLE);

//******************************************************************************
// State Machine
//******************************************************************************

    always_ff @(posedge clk)
    begin
        case (state)
            IDLE:
                    if (valid)
                        state <= START;
                    else
                        state <= IDLE;

            START:
                    if (cnt==CYCLE-1)
                        state <= DATA;
                    else
                        state <= START;

            DATA:
                    if (cnt==CYCLE-1 && bit_cnt==7)
                        state <= STOP;
                    else
                        state <= DATA;

            STOP:
                    if (cnt==CYCLE-1)
                        state <= IDLE;
                    else
                        state <= STOP;

            default:
                    state <= IDLE;
        endcase
    end

//******************************************************************************
// cnt
//******************************************************************************

    always_ff @(posedge clk)
    begin
        if (state==START || state==DATA || state==STOP)
            cnt <= (cnt==CYCLE-1) ? '0 : cnt + 1;
        else
            cnt <= '0;
    end

    always_ff @(posedge clk)
    begin
        if (state==DATA)
            bit_cnt <= (cnt==CYCLE-1) ? bit_cnt + 1 : bit_cnt;
        else
            bit_cnt <= '0;
    end

//******************************************************************************
// bits
//******************************************************************************

    always_ff @(posedge clk)
    begin
        if (state==IDLE && valid)
            bits <= data;
    end

//******************************************************************************
// o
//******************************************************************************

    always_ff @(posedge clk)
    begin
        case (state)
            IDLE:    uart_o <= 1'b1;
            START:   uart_o <= 1'b0;
            DATA:    uart_o <= bits[bit_cnt];
            STOP:    uart_o <= 1'b1;
            default: uart_o <= 1'b1;
        endcase
    end

endmodule
