// video_package.svh - Common definitions for UPduino video
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`ifndef VIDEO_PACKAGE_SVH
`define VIDEO_PACKAGE_SVH

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

/* verilator lint_off UNUSED */

// "brief" package name (as Yosys doesn't support wildcard imports so lots of "v::")
package v;

`ifdef MODE_640x480                     // 25.175 MHz (requested), 25.125 MHz (achieved)
`elsif MODE_848x480                     // 33.750 MHz (requested), 33.750 MHz (achieved)
`elsif MODE_800x600                     // 40.000 MHz (requested), 39.750 MHz (achieved) [tight timing]
`else
`define MODE_640x480                    // default
`endif

`ifdef    MODE_640x480
// VGA mode 640x480 @ 60Hz (pixel clock 25.175Mhz)
localparam PIXEL_FREQ        = 25_175_000;  // pixel clock in Hz
localparam REFRESH_FREQ      = 16'h6000;    // vertical refresh Hz BCD
localparam VISIBLE_WIDTH     = 640;         // horizontal active pixels
localparam VISIBLE_HEIGHT    = 480;         // vertical active lines
localparam H_FRONT_PORCH     = 16;          // H pre-sync (front porch) pixels
localparam H_SYNC_PULSE      = 96;          // H sync pulse pixels
localparam H_BACK_PORCH      = 48;          // H post-sync (back porch) pixels
localparam V_FRONT_PORCH     = 10;          // V pre-sync (front porch) lines
localparam V_SYNC_PULSE      = 2;           // V sync pulse lines
localparam V_BACK_PORCH      = 33;          // V post-sync (back porch) lines
localparam H_SYNC_POLARITY   = 1'b0;        // H sync pulse active level
localparam V_SYNC_POLARITY   = 1'b0;        // V sync pulse active level

`elsif    MODE_848x480
// VGA mode 848x480 @ 60Hz (pixel clock 33.750Mhz)
localparam PIXEL_FREQ        = 33_750_000;  // pixel clock in Hz
localparam REFRESH_FREQ      = 16'h6000;    // vertical refresh Hz BCD
localparam VISIBLE_WIDTH     = 848;         // horizontal active pixels
localparam VISIBLE_HEIGHT    = 480;         // vertical active lines
localparam H_FRONT_PORCH     = 16;          // H pre-sync (front porch) pixels
localparam H_SYNC_PULSE      = 112;         // H sync pulse pixels
localparam H_BACK_PORCH      = 112;         // H post-sync (back porch) pixels
localparam V_FRONT_PORCH     = 6;           // V pre-sync (front porch) lines
localparam V_SYNC_PULSE      = 8;           // V sync pulse lines
localparam V_BACK_PORCH      = 23;          // V post-sync (back porch) lines
localparam H_SYNC_POLARITY   = 1'b1;        // H sync pulse active level
localparam V_SYNC_POLARITY   = 1'b1;        // V sync pulse active level

`elsif    MODE_800x600
// VGA mode 800x600 @ 60Hz (pixel clock 40.000Mhz)
localparam PIXEL_FREQ        = 40_000_000;  // pixel clock in Hz
localparam REFRESH_FREQ      = 16'h6000;    // vertical refresh Hz BCD
localparam VISIBLE_WIDTH     = 800;         // horizontal active pixels
localparam VISIBLE_HEIGHT    = 600;         // vertical active lines
localparam H_FRONT_PORCH     = 40;          // H pre-sync (front porch) pixels
localparam H_SYNC_PULSE      = 128;         // H sync pulse pixels
localparam H_BACK_PORCH      = 88;          // H post-sync (back porch) pixels
localparam V_FRONT_PORCH     = 1;           // V pre-sync (front porch) lines
localparam V_SYNC_PULSE      = 4;           // V sync pulse lines
localparam V_BACK_PORCH      = 23;          // V post-sync (back porch) lines
localparam H_SYNC_POLARITY   = 1'b1;        // H sync pulse active level
localparam V_SYNC_POLARITY   = 1'b1;        // V sync pulse active level
`endif

// Lattice/SiliconBlue PLL "magic numbers" to derive pixel clock from 12Mhz oscillator (from "icepll" utility)
`ifdef    MODE_640x480  // 25.175 MHz (requested), 25.125 MHz (achieved)
localparam PCLK_HZ     =    25_125_000;
localparam PLL_DIVR    =    4'b0000;        // DIVR =  0
localparam PLL_DIVF    =    7'b1000010;     // DIVF = 66
localparam PLL_DIVQ    =    3'b101;         // DIVQ =  5
`elsif    MODE_848x480  // 33.750 MHz (requested), 33.750 MHz (achieved)
localparam PCLK_HZ     =    33_750_000;
localparam PLL_DIVR    =    4'b0000;        // DIVR =  0
localparam PLL_DIVF    =    7'b0101100;     // DIVF = 44
localparam PLL_DIVQ    =    3'b100;         // DIVQ =  4
`elsif    MODE_800x600  // 40.000 MHz (requested), 39.750 MHz (achieved) [tight timing]
localparam PCLK_HZ     =    39_750_000;
localparam PLL_DIVR    =    4'b0000;        // DIVR =  0
localparam PLL_DIVF    =    7'b0110100;     // DIVF = 52
localparam PLL_DIVQ    =    3'b100;         // DIVQ =  4
`endif

// calculated video mode parameters
localparam TOTAL_WIDTH       = H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + VISIBLE_WIDTH;
localparam TOTAL_HEIGHT      = V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH + VISIBLE_HEIGHT;
localparam OFFSCREEN_WIDTH   = TOTAL_WIDTH - VISIBLE_WIDTH;
localparam OFFSCREEN_HEIGHT  = TOTAL_HEIGHT - VISIBLE_HEIGHT;

// tile related constants
localparam FONT_WIDTH        = 8;                               // 8 pixel wide tiles (byte wide font)
localparam FONT_HEIGHT       = 8;                               // can be 8 or 16 pixel high font
localparam CHARS_WIDE        = (VISIBLE_WIDTH/FONT_WIDTH);      // default tiled mode width
localparam CHARS_HIGH        = (VISIBLE_HEIGHT/FONT_HEIGHT);    // default tiled mode height

localparam DISPADDR_W       = 12;               // address bits for display mem
localparam DISPDATA_W       = 16;               // 16-bit
localparam FONTADDR_W       = $clog2(256*FONT_HEIGHT); // address bits for font mem
localparam FONTDATA_W       = 8;                // bits for font memory
localparam DISP_FORECOLOR   = 8;                // rightmost bit for forecolor
localparam DISP_BACKCOLOR   = 12;               // rightmost bit for backcolor
localparam COLOR_W          = 3;                // bits for color (R, G, B)

/* verilator lint_on UNUSED */

endpackage

// NOTE: These typedefs are needed outside of package for by Icarus Verilog (a limitation
// of its SystemVerilog support)
typedef logic [$clog2(v::TOTAL_WIDTH)-1:0]     hres_t;         // horizontal coordinate type
typedef logic [$clog2(v::TOTAL_HEIGHT)-1:0]    vres_t;         // vertical coordinate type
typedef logic [v::FONTADDR_W-1:0]              font_addr_t;    // font memory address type
typedef logic [v::FONTDATA_W-1:0]              font_data_t;    // font memory byte type
typedef logic [v::DISPADDR_W-1:0]              disp_addr_t;    // display memory address type
typedef logic [v::DISPDATA_W-1:0]              disp_data_t;    // disp memory word type
typedef logic [v::COLOR_W-1:0]                 color_t;        // color output type

`endif      // VIDEO_PACKAGE_SVH
