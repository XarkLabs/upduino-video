// video_tb.sv
//
// vim: set et ts=4 sw=4
//
// Simulation "testbench" for video design.  This "pretends" to be the FPGA
// hardware by generating a clock input and monitoring outputs.
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`include "video_package.svh"

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps

module video_tb();                // module definition

/* verilator lint_off UNUSED */

logic       clk;                  // simulated "external clock" for design
logic       reset;
logic       vga_hsync;
logic       vga_vsync;
logic       vga_dv_de;
logic       vga_red;
logic       vga_green;
logic       vga_blue;

// video control signals
localparam              H_REPEAT = 2;
localparam              V_REPEAT = 3;
localparam disp_addr_t  LINE_LEN = ((v::VISIBLE_WIDTH + v::FONT_WIDTH - 1) / H_REPEAT) / v::FONT_WIDTH;

logic                   end_of_frame;
logic                   display_wr_en;
disp_addr_t             display_wr_addr;
disp_data_t             display_wr_data;

/* verilator lint_on UNUSED */

// === instantiate main module (unit-under-test)
video_main main(
    // VGA signals
    .vga_hsync_o(vga_hsync),
    .vga_vsync_o(vga_vsync),
    .vga_dv_de_o(vga_dv_de),
    .vga_red_o(vga_red),
    .vga_green_o(vga_green),
    .vga_blue_o(vga_blue),
    // control signals
    .end_of_frame_o(end_of_frame),
    .pf_h_repeat_i($bits(main.pf_h_repeat_i)'(H_REPEAT-1)),
    .pf_v_repeat_i($bits(main.pf_v_repeat_i)'(V_REPEAT-1)),
    .pf_line_len_i(LINE_LEN),
    .display_wr_en_i(display_wr_en),
    .display_wr_addr_i(display_wr_addr),
    .display_wr_data_i(display_wr_data),

    .reset_i(reset),
    .clk(clk)
);

// === instantiate test/demo module
// simple test/demo to write message to display memory every 5 seconds
video_test video_test(
    .eof_i(end_of_frame),
    .wr_en_o(display_wr_en),
    .wr_addr_o(display_wr_addr),
    .wr_data_o(display_wr_data),
    .reset_i(reset),
    .clk(clk)
);

initial begin
    $timeformat(-9, 0, " ns", 9);
    $dumpfile("logs/video_isim.fst");
    $dumpvars(0, main);
    $display("Simulation started");

    reset = 1'b1;
    clk = 1'b0; // set initial value for clk
    #(1_000_000_000/v::PCLK_HZ * 3) reset = 1'b1;

    #(5*17ms);

    $display("Ending simulation at %0t", $realtime);
    $finish;
end

// toggle clock at video frequency
always begin
    #(1_000_000_000/v::PCLK_HZ) clk <= !clk;
end

endmodule

`default_nettype wire               // restore default
