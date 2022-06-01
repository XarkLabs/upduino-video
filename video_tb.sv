// video_tb.sv
//
// vim: set et ts=4 sw=4
//
// Simulation "testbench" for video design.  This "pretends" to be the FPGA
// hardware by generating a clock input and monitoring the LED outputs.
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`include "video_package.svh"

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps

module video_tb();                // module definition

/* verilator lint_off UNUSED */

logic       clk;                  // simulated "external clock" for design
logic       vga_hsync;
logic       vga_vsync;
logic       vga_red;
logic       vga_green;
logic       vga_blue;

/* verilator lint_on UNUSED */

// instantiate the design to test (unit-under-test)
video_main uut(
    .vga_hsync_o(vga_hsync),
    .vga_vsync_o(vga_vsync),
    .vga_red_o(vga_red),
    .vga_green_o(vga_green),
    .vga_blue_o(vga_blue),
    .clk(clk)
);

initial begin
    $timeformat(-9, 0, " ns", 9);
    $dumpfile("logs/video_tb.fst");
    $dumpvars(0, uut);
    $display("Simulation started");

    clk = 1'b0; // set initial value for clk

    #(3*17ms);

    $display("Ending simulation at %0t", $realtime);
    $finish;
end

// toggle clock at video frequency
always begin
    #(1_000_000_000/v::PCLK_HZ) clk = !clk;
end

endmodule

`default_nettype wire               // restore default
