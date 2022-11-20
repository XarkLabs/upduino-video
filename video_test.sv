// video_test.sv
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

`include "video_package.svh"

module video_test
(
    input  wire logic           eof_i,
    // output
    output      logic           wr_en_o,
    output      disp_addr_t     wr_addr_o,
    output      disp_data_t     wr_data_o,
    // standard signals
    input  wire logic           reset_i,
    input  wire logic           clk
);

`ifdef SYNTHESIS
localparam DELAY = 5 * 60;
`else
localparam DELAY = 2;       // fast in simulation
`endif


// frame counter (for delay)
logic               delay_flag;
logic [8:0]         frame_count;
always_ff @(posedge clk) begin
    if (reset_i) begin
        frame_count <= '0;
        delay_flag  <= 1'b0;
    end else begin
        delay_flag  <= 1'b0;
        if (eof_i) begin
            frame_count <= frame_count + 1'b1;
            if (frame_count == DELAY) begin
                delay_flag  <= 1'b1;
                frame_count <= '0;
            end
        end
    end
end

// simple test FSM
typedef enum logic [1:0] {
    TEST_IDLE       = 2'h0,
    TEST_PRINT      = 2'h1,
    TEST_LOOP       = 2'h2
} test_st;

localparam                  MSG_LEN = 20;
localparam                  MSG_BITS = $clog2(MSG_LEN);
logic [MSG_BITS:0]          cur_char;       // extra high-bit to detect underflow
logic [MSG_LEN*8-1:0]       message = "Hello Upduino VGA!  ";
disp_addr_t                 addr;
color_t                     fcolor;
color_t                     bcolor;

logic [1:0]                 test_state;

always_ff @(posedge clk) begin
    if (reset_i) begin
        wr_en_o     <= 1'b0;
        wr_addr_o   <= '0;
        test_state  <= TEST_IDLE;

        cur_char    <= '0;
        bcolor      <= '0;
        fcolor      <= '0;
        addr        <= '0;
    end else begin
        wr_en_o     <= 1'b0;
        wr_addr_o   <= addr;

        case (test_state)
            TEST_IDLE: begin
                if (delay_flag) begin
                    cur_char    <= MSG_LEN-1;
                    test_state  <= TEST_PRINT;
                end
            end
            TEST_PRINT: begin
                // if high bit not set (hasn't under-flowed)
                if (!cur_char[MSG_BITS]) begin
                    wr_en_o     <= 1'b1;
                    wr_data_o   <= { 4'(bcolor),                                // back color
                        (fcolor == bcolor) ? 4'(fcolor) + 4'h5 : 4'(fcolor),    // fore color (avoid fore == back)
                        message[cur_char*8+:8] };                              // character
                    cur_char    <= cur_char - 1'b1;
                    addr        <= addr + 1'b1;
                    fcolor      <= fcolor + 1;
                end else begin
                    test_state  <= TEST_LOOP;
                end
            end
            TEST_LOOP: begin
                bcolor      <= bcolor + 1;
                fcolor      <= bcolor + 3;
                test_state  <= TEST_IDLE;
            end
            default: begin
                test_state  <= TEST_IDLE;
            end
        endcase
    end
end

endmodule
`default_nettype wire               // restore default
