// video_top.sv
//
// vim: set et ts=4 sw=4
//
// "Top" of the example design (above is the FPGA hardware)
//
// * setup clock
// * setup inputs
// * setup outputs
// * instantiate main module
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

`include "video_package.svh"

// To generate the needed video frequency either UPduino OSC jumper can be shorted
// with a blob of solder (for a more solid, permanent clock connection) or you
// can use a wire connecting 12M pin to gpio_20 (make sure you have real 12M pin
// and not mislabelled GND, as silkscreen is incorrect on some boards - check for
// continuity with GND).
//
//             PCF   Pin#  _____  Pin#   PCF
//                  /-----| USB |-----\
//            <GND> |  1   \___/   48 | spi_ssn   (16)
//            <VIO> |  2           47 | spi_sck   (15)
//            <RST> |  3           46 | spi_mosi  (17)
//           <DONE> |  4           45 | spi_miso  (14)
// <RGB2>   led_red |  5           44 | gpio_20   <----+ short OSC jumper
// <RGB0> led_green |  6     U     43 | gpio_10        | or use a
// <RGB1>  led_blue |  7     P     42 | <GND>          | wire for
//       <+5V/VUSB> |  8     d     41 | <12M>     >----+ 12 MHz clock
//          <+3.3V> |  9     u     40 | gpio_12
//            <GND> | 10     i     39 | gpio_21
//          gpio_23 | 11     n     38 | gpio_13
//          gpio_25 | 12     o     37 | gpio_19
//          gpio_26 | 13           36 | gpio_18
//          gpio_27 | 14     V     35 | gpio_11
//          gpio_32 | 15     3     34 | gpio_9
// <G0>     gpio_35 | 16     .     33 | gpio_6
//          gpio_31 | 17     x     32 | gpio_44   <G6>
// <G1>     gpio_37 | 18           31 | gpio_4
//          gpio_34 | 19           30 | gpio_3
//          gpio_43 | 20           29 | gpio_48   >----> VGA blue
//          gpio_36 | 21           28 | gpio_45   >----> VGA green
//          gpio_42 | 22           27 | gpio_47   >----> VGA red
//          gpio_38 | 23           26 | gpio_46   >----> VGA V sync
//          gpio_28 | 24           25 | gpio_2    >----> VGA H sync
//                  \-----------------/

module video_top (
    // output gpio
    output      logic   spi_ssn,     // SPI flash CS, hold high to prevent UART conflict
    input  wire logic   gpio_20,     // 12 MHz clock input (via OSC jumper or 12M pin wire)
    output      logic   gpio_48,     // VGA blue
    output      logic   gpio_45,     // VGA green
    output      logic   gpio_47,     // VGA red
    output      logic   gpio_46,     // VGA V sync
    output      logic   gpio_2       // VGA H sync
);

// assign output signals to FPGA pins
assign      spi_ssn     = 1'b1;         // deselect SPI flash (pins shared with UART)
always_comb gpio_48     = vga_blue;
always_comb gpio_45     = vga_green;
always_comb gpio_47     = vga_red;
always_comb gpio_46     = vga_vsync;
always_comb gpio_2      = vga_hsync;

// === clock setup
// PLL to derive proper video frequency from 12MHz oscillator
// clock input is gpio_20 (with OSC jumper shorted or a wire from 12M)
logic           clk;                // clock for design (output of PLL)
logic           clk_cpu;            // clock for design (output of PLL)
logic           pll_lock;           // indicates when PLL frequency has locked-on
logic           reset;              // reset signal

`ifndef SYNTHESIS   // simulation

// for simulation use 1:1 input clock (and testbench can simulate proper frequency)
assign pll_lock = 1'b1;
assign clk = gpio_20;
always_ff @(posedge clk) clk_cpu <= ~clk_cpu;

`else               // synthesis

`define USE_DUAL_PLL    // dual output PLL example (runs test module at 1/2 VGA clock speed)

/* verilator lint_off PINMISSING */
`ifdef USE_DUAL_PLL     // dual output PLL (one clock half speed, but in phase)

initial begin
    $display("NOTE: Using dual PLL");
end

SB_PLL40_2F_CORE #(
    .DIVR(v::PLL_DIVR),         // DIVR from video_package.svh
    .DIVF(v::PLL_DIVF),         // DIVF from video_package.svh
    .DIVQ(v::PLL_DIVQ),         // DIVQ from video_package.svh
    .FEEDBACK_PATH("SIMPLE"),
    .FILTER_RANGE(3'b001),
    .PLLOUT_SELECT_PORTA("GENCLK_HALF"),
    .PLLOUT_SELECT_PORTB("GENCLK")
) pll_inst (
    .LOCK(pll_lock),            // signal indicates PLL lock (useful as a reset)
    .RESETB(1'b1),
    .BYPASS(1'b0),
    .REFERENCECLK(gpio_20),     // input reference clock
    .PLLOUTGLOBALA(clk_cpu),    // PLL output half speed clock (via global buffer)
    .PLLOUTGLOBALB(clk)         // PLL output clock (via global buffer)
);

`else   // single output PLL

initial begin
    $display("NOTE: Using single PLL");
end

SB_PLL40_CORE #(
    .DIVR(v::PLL_DIVR),         // DIVR from video_package.svh
    .DIVF(v::PLL_DIVF),         // DIVF from video_package.svh
    .DIVQ(v::PLL_DIVQ),         // DIVQ from video_package.svh
    .FEEDBACK_PATH("SIMPLE"),
    .FILTER_RANGE(3'b001),
    .PLLOUT_SELECT("GENCLK")
)
pll_inst (
    .LOCK(pll_lock),            // signal indicates PLL lock (useful as a reset)
    .RESETB(1'b1),
    .BYPASS(1'b0),
    .REFERENCECLK(gpio_20),     // input reference clock
    .PLLOUTGLOBAL(clk)          // PLL output clock (via global buffer)
);

assign clk_cpu = clk;           // use same clock for cpu_clk

`endif
/* verilator lint_on PINMISSING */

`endif

// suppress unused warning (using signal name starting with "unused")
logic   unused_signals;

// video display VGA output signals
logic                   vga_hsync;
logic                   vga_vsync;
logic                   vga_dv_de;
logic                   vga_red;
logic                   vga_green;
logic                   vga_blue;

assign unused_signals = &{ 1'b0, vga_dv_de };

// reset control (hold reset until PLL locked)
initial reset = 1'b1;   // start in reset
always_ff @(posedge clk) begin
    if (!pll_lock) begin
        reset       <= 1'b1;
    end else begin
        reset       <= 1'b0;
    end
end

// video control signals
localparam              H_REPEAT = 2;
localparam              V_REPEAT = 3;
localparam              LINE_LEN = ((v::VISIBLE_WIDTH + v::FONT_WIDTH - 1) / H_REPEAT) / v::FONT_WIDTH;

logic                   end_of_frame;
logic                   display_wr_en;
disp_addr_t             display_wr_addr;
disp_data_t             display_wr_data;

// === instantiate main module
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
    .pf_h_repeat_i(3'(H_REPEAT-1)),
    .pf_v_repeat_i(3'(V_REPEAT-1)),
    .pf_line_len_i(LINE_LEN),
    .display_wr_en_i(display_wr_en),
    .display_wr_addr_i(display_wr_addr),
    .display_wr_data_i(display_wr_data),

    .reset_i(reset),
    .clk(clk)
);

// === instantiate test/demo module to write to display memory
video_test video_test(
    .eof_i(end_of_frame),
    .wr_en_o(display_wr_en),
    .wr_addr_o(display_wr_addr),
    .wr_data_o(display_wr_data),

    .reset_i(reset),
    .clk(clk_cpu)
);

endmodule
`default_nettype wire               // restore default
