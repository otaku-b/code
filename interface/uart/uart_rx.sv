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
//  Filename    : uart_rx.sv
//  Version     : 1.00
//  Author      : ( °- °)つロ
//  Date        : 2024-10-24
// -----------------------------------------------------------------
//  Description :
//                UART
// =============================================================================

module uart_rx # (
    parameter CLK_FREQ = 100,       // clk frequency: MHz
    parameter BIT_RATE = 115200     // uart frequency: Hz
)(
    input   logic       clk,
    input   logic       uart_i,
    output  logic       valid,
    output  logic [7:0] data,
    output  logic       err
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

    (* ASYNC_REG = "TRUE" *) logic uart_i_1p;
    (* ASYNC_REG = "TRUE" *) logic uart_i_2p;
    (* ASYNC_REG = "TRUE" *) logic uart_i_3p;
    logic uart_i_fall;

    logic [$clog2(CYCLE)-1:0] cnt = '0;
    logic [2:0] bit_cnt = '0;

    logic [7:0] bits = '0;

//******************************************************************************
// sync
//******************************************************************************

    always_ff @(posedge clk)
    begin
        uart_i_1p <= uart_i;
        uart_i_2p <= uart_i_1p;
        uart_i_3p <= uart_i_2p;
    end

    assign uart_i_fall = ~uart_i_2p & uart_i_3p;

//******************************************************************************
// State Machine
//******************************************************************************

    always_ff @(posedge clk)
    begin
        case (state)
            IDLE:
                    if (uart_i_fall)
                        state <= START;
                    else
                        state <= IDLE;

            START:
                    if (cnt==CYCLE/2-1 && uart_i_2p) // debounce
                        state <= IDLE;

                    else if (cnt==CYCLE-1)
                        state <= DATA;

                    else
                        state <= START;

            DATA:
                    if (cnt==CYCLE-1 && bit_cnt==7)
                        state <= STOP;
                    else
                        state <= DATA;

            STOP:
                    if (cnt==CYCLE/2-1) // avoid missing the next Start Character '0'
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
        if ((state==DATA) && (cnt==CYCLE/2-1))
            bits[bit_cnt] <= uart_i_2p;
    end

//******************************************************************************
// o
//******************************************************************************

    always_ff @(posedge clk)
    begin
        if ((state==STOP) && (cnt==CYCLE/2-1) && uart_i_2p) // Stop Character '1'
            valid <= 1'b1;
        else
            valid <= 1'b0;
    end

    always_ff @(posedge clk)
    begin
        if ((state==STOP) && (cnt==CYCLE/2-1))
            data <= bits;
    end

//******************************************************************************
// error
//******************************************************************************

    always_ff @(posedge clk)
    begin
        if ((state==STOP) && (cnt==CYCLE/2-1) && ~uart_i_2p) // Stop Character != '1'
            err <= 1'b1;
        else
            err <= 1'b0;
    end

endmodule
