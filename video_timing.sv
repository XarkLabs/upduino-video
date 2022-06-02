// video_timing.sv
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//
// Thanks to the following inspirational and education projects:
//
// Dan "drr" Rodrigues for the amazing icestation-32 project:
//     https://github.com/dan-rodrigues/icestation-32
// Sylvain "tnt" Munaut for many amazing iCE40 projects and streams (e.g., 1920x1080 HDMI):
//     https://github.com/smunaut/ice40-playground
// Will "Flux" Green and his excellent FPGA video and overall educational site
//     https://projectf.io/
//
// Learning from both of these projects (and others) helped me significantly improve this design
`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

`include "video_package.svh"

module video_timing (
    // video registers and control
    output      hres_t          h_count_o,              // horizontal video counter
    output      logic           v_visible_o,            // visible vertical line
    output      logic           visible_o,              // pixel is visible
    output      logic           end_of_line_o,          // strobe for end of line (h_count resets)
    output      logic           end_of_frame_o,         // strobe for end of frame (v_count resets)
    output      logic           vsync_o,                // vertical sync output (polarity depends on video mode)
    output      logic           hsync_o,                // horizontal sync output (polarity depends on video mode)
    input  wire logic           clk                     // clock (video pixel clock)
);

// NOTE: Both H & V states so both can start at 0
typedef enum logic [1:0] {
    H_STATE_PRE_SYNC  = 2'b00,    // aka front porch
    H_STATE_SYNC      = 2'b01,
    H_STATE_POST_SYNC = 2'b10,    // aka back porch
    H_STATE_VISIBLE   = 2'b11
} horizontal_st;

typedef enum logic [1:0] {
    V_STATE_VISIBLE   = 2'b00,
    V_STATE_PRE_SYNC  = 2'b01,    // aka front porch
    V_STATE_SYNC      = 2'b10,
    V_STATE_POST_SYNC = 2'b11     // aka back porch
} vertical_st;

// sync generation signals (and combinatorial logic "next" versions)
logic [1:0]     h_state, h_state_next;
hres_t          h_count, h_count_next;
hres_t          h_count_match_value;

logic [1:0]     v_state, v_state_next;
vres_t          v_count, v_count_next;
vres_t          v_count_match_value;

logic           hsync, hsync_next;
logic           vsync, vsync_next;
logic           dv_de, dv_de_next;

logic           end_of_line, end_of_line_next;
logic           end_of_frame, end_of_frame_next;

// outputs
always_comb     h_count_o        = h_count;
always_comb     v_visible_o      = (v_state == V_STATE_VISIBLE);
always_comb     visible_o        = dv_de;
always_comb     end_of_line_o    = end_of_line;
always_comb     end_of_frame_o   = end_of_frame;
always_comb     hsync_o          = hsync;
always_comb     vsync_o          = vsync;

// video sync generation via state machine (Thanks tnt & drr - a much more efficient method!)
always_comb     end_of_line_next = (h_state == H_STATE_VISIBLE) && (h_state_next == H_STATE_PRE_SYNC);
always_comb     end_of_frame_next= (v_state == V_STATE_POST_SYNC) && (v_state_next == V_STATE_VISIBLE);
always_comb     hsync_next       = (h_state == H_STATE_SYNC) ? v::H_SYNC_POLARITY : ~v::H_SYNC_POLARITY;
always_comb     vsync_next       = (v_state == V_STATE_SYNC) ? v::V_SYNC_POLARITY : ~v::V_SYNC_POLARITY;
always_comb     dv_de_next       = (v_state == V_STATE_VISIBLE) && (h_state_next == H_STATE_VISIBLE);

// combinational block for video counters
always_comb begin
    h_count_next = h_count + 1'b1;
    v_count_next = v_count;

    if (end_of_line_next) begin
        h_count_next = '0;

        if (end_of_frame_next) begin
            v_count_next = '0;
        end else begin
            v_count_next = v_count + 1'b1;
        end
    end
end

// combinational block for horizontal video state
always_comb h_state_next    = (h_count == h_count_match_value) ? h_state + 1'b1 : h_state;

always_comb begin
    // scanning horizontally left to right, offscreen pixels are on left before visible pixels
    case (h_state)
        H_STATE_PRE_SYNC:
            h_count_match_value = v::H_FRONT_PORCH - 1;
        H_STATE_SYNC:
            h_count_match_value = v::H_FRONT_PORCH + v::H_SYNC_PULSE - 1;
        H_STATE_POST_SYNC:
            h_count_match_value = v::H_FRONT_PORCH + v::H_SYNC_PULSE + v::H_BACK_PORCH - 1;
        H_STATE_VISIBLE:
            h_count_match_value = v::TOTAL_WIDTH - 1;
    endcase
end

// combinational block for vertical video state
always_comb v_state_next    = end_of_line_next && (v_count == v_count_match_value) ? v_state + 1'b1 : v_state;

always_comb begin
    // scanning vertically top to bottom, offscreen lines are on bottom after visible lines
    case (v_state)
        V_STATE_VISIBLE:
            v_count_match_value = v::VISIBLE_HEIGHT - 1;
        V_STATE_PRE_SYNC:
            v_count_match_value = v::VISIBLE_HEIGHT + v::V_FRONT_PORCH - 1;
        V_STATE_SYNC:
            v_count_match_value = v::VISIBLE_HEIGHT + v::V_FRONT_PORCH + v::V_SYNC_PULSE - 1;
        V_STATE_POST_SYNC:
            v_count_match_value = v::TOTAL_HEIGHT - 1;
    endcase
end

// set initial signal values
initial begin
    h_state             = H_STATE_PRE_SYNC;
    v_state             = V_STATE_VISIBLE;
    h_count             = '0;
    v_count             = '0;

    end_of_line         = 1'b0;
    end_of_frame        = 1'b0;

    hsync               = ~v::H_SYNC_POLARITY;
    vsync               = ~v::V_SYNC_POLARITY;
    dv_de               = 1'b0;
end

// video pixel generation
always_ff @(posedge clk) begin
    // update registered signals from combinatorial "next" versions
    end_of_line         <= end_of_line_next;
    end_of_frame        <= end_of_frame_next;

    h_state             <= h_state_next;
    v_state             <= v_state_next;
    h_count             <= h_count_next;
    v_count             <= v_count_next;

    // set other video output signals
    hsync               <= hsync_next;
    vsync               <= vsync_next;
    dv_de               <= dv_de_next;
end

endmodule
`default_nettype wire               // restore default
