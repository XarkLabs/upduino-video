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
    output      disp_addr_t  wr_addr_o,
    output      disp_data_t  wr_data_o,
    // standard signals
    input  wire logic           clk
);

initial begin
    bcolor       = 0;
    fcolor       = 1;
    frame_reset = '0;
    frame_count = '0;
    cur_char    = '0;
    addr        = '0;
    test_state  = TEST_IDLE;
end

// frame counter
logic               frame_reset;
logic [23:0]        frame_count;
always_ff @(posedge clk) begin
    if (eof_i) begin
        frame_count <= frame_count + 1'b1;
    end
    if (frame_reset) begin
        frame_count <= '0;
    end
end

// simple test FSM
typedef enum logic [1:0] {
    TEST_IDLE       = 2'h0,
    TEST_PRINT      = 2'h1
} test_st;

localparam                  MESSAGE_LEN = 20;
logic [MESSAGE_LEN*8:1]     message = "Hello Upduino VGA!  ";
logic signed [$clog2(MESSAGE_LEN):0] cur_char;
disp_addr_t              addr;
color_t                  fcolor;
color_t                  bcolor;

logic [1:0]                 test_state;

always_ff @(posedge clk) begin

    frame_reset <= 1'b0;
    wr_en_o     <= 1'b0;
    wr_addr_o   <= addr;

    case (test_state)
    TEST_IDLE: begin
        if (frame_count > (5 * 60)) begin
            frame_reset <= 1'b1;
            cur_char    <= MESSAGE_LEN-1;
            test_state  <= TEST_PRINT;
        end
    end
    TEST_PRINT: begin
        if (cur_char >= 0) begin
            wr_en_o     <= 1'b1;
            wr_data_o   <= { 4'(bcolor),                                // back color
                (fcolor == bcolor) ? 4'(fcolor) + 4'h5 : 4'(fcolor),    // fore color (avoid fore == back)
                 message[cur_char*8+1+:8] };                            // character
            cur_char    <= cur_char - 1'b1;
            addr        <= addr + 1'b1;
            fcolor      <= fcolor + 1;
        end else begin
            bcolor      <= bcolor + 1;
            fcolor      <= bcolor + 2;
            test_state  <= TEST_IDLE;
        end
    end
    default: begin
        test_state  <= TEST_IDLE;
    end

    endcase
end



endmodule
`default_nettype wire               // restore default
