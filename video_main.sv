// example_main.sv
//
// vim: set et ts=4 sw=4
//
// Simple main module of for example design (above is either FPGA top or
// testbench).
//
// This module has the example LED control logic, counter and buttons
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//
`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

`include "video_package.svh"

module video_main #(
    parameter H_REPEAT = 2,     // 1x to 8x
    parameter V_REPEAT = 3      // 1x to 8x
) (
    // outputs
    output      logic           vga_hsync_o,        // VGA horizontal sync out
    output      logic           vga_vsync_o,        // VGA vertical sync out
    output      logic           vga_red_o,          // red LED output
    output      logic           vga_green_o,        // green LED output
    output      logic           vga_blue_o,         // blue LED output
    // inputs
    input  wire logic           clk                 // clock for module input
);

// simple test to write to display memory
video_test video_test(
    .eof_i(end_of_frame),
    .wr_en_o(display_wr_en),
    .wr_addr_o(display_wr_addr),
    .wr_data_o(display_wr_data),
    .clk(clk)
);

// video timing generation
hres_t       h_count;
logic           v_visible;
logic           visible;
logic           end_of_line;
logic           end_of_frame;

video_timing video_timing(
    .h_count_o(h_count),
    .v_visible_o(v_visible),
    .visible_o(visible),
    .end_of_line_o(end_of_line),
    .end_of_frame_o(end_of_frame),
    .vsync_o(vga_vsync_o),
    .hsync_o(vga_hsync_o),
    .clk(clk)
);

// video display parameters (hard-coded)
logic [2:0]             pf_h_repeat = 3'(H_REPEAT-1);
logic [2:0]             pf_v_repeat = 3'(V_REPEAT-1);
disp_addr_t          pf_line_len = ((v::VISIBLE_WIDTH + v::TILE_WIDTH - 1) / H_REPEAT) / v::TILE_WIDTH;

// video display generation
always_comb vga_red_o   = visible ? pf_color_out[v::COLOR_W-(1*v::COLOR_W/3)+:(v::COLOR_W/3)] : '0;
always_comb vga_green_o = visible ? pf_color_out[v::COLOR_W-(2*v::COLOR_W/3)+:(v::COLOR_W/3)] : '0;
always_comb vga_blue_o  = visible ? pf_color_out[v::COLOR_W-(3*v::COLOR_W/3)+:(v::COLOR_W/3)] : '0;

logic [v::COLOR_W-1:0]  pf_color_out;

video_gen video_gen(
    .h_count_i(h_count),
    .v_visible_i(v_visible),
    .end_of_line_i(end_of_line),
    .end_of_frame_i(end_of_frame),
    .dispmem_sel_o(display_rd_en),
    .dispmem_addr_o(display_rd_addr),
    .dispmem_data_i(display_rd_data),
    .fontmem_sel_o(font_rd_en),
    .fontmem_addr_o(font_rd_addr),
    .fontmem_data_i(font_rd_data),
    .pf_h_repeat_i(pf_h_repeat),
    .pf_v_repeat_i(pf_v_repeat),
    .pf_line_len_i(pf_line_len),
    .pf_color_index_o(pf_color_out),
    .clk(clk)
);

// display memory
logic           display_rd_en;
disp_addr_t  display_rd_addr;
disp_data_t  display_rd_data;

logic           display_wr_en;
disp_addr_t  display_wr_addr;
disp_data_t  display_wr_data;

memory #(
    .ADDR_W(v::DISPADDR_W),
    .DATA_W(v::DISPDATA_W)
) display (
    .rd_en_i(display_rd_en),
    .rd_address_i(display_rd_addr),
    .rd_data_o(display_rd_data),
    .rd_clk(clk),
    .wr_en_i(display_wr_en),
    .wr_address_i(display_wr_addr),
    .wr_data_i(display_wr_data),
    .wr_clk(clk)
);


// font memory (read only)
logic           font_rd_en;
font_addr_t  font_rd_addr;
font_data_t  font_rd_data;

memory #(
    .MEM_FILE("osifont_8x8.memb"),      // Ohio-Scientific Challenger font
//    .MEM_FILE("hexfont_8x8.memb"),    // hex number font (debug)
    .ADDR_W(v::FONTADDR_W),
    .DATA_W(v::FONTDATA_W)
) font (
    .rd_en_i(font_rd_en),
    .rd_address_i(font_rd_addr),
    .rd_data_o(font_rd_data),
    .rd_clk(clk),
    .wr_en_i(1'b0),
    .wr_address_i(v::FONTADDR_W'(0)),
    .wr_data_i(v::FONTDATA_W'(0)),
    .wr_clk(1'b0)
);

endmodule
`default_nettype wire               // restore default for other modules
