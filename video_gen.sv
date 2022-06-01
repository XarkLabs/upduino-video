// video_gen.sv
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`default_nettype none               // mandatory for Verilog sanity
`timescale 1ns/1ps                  // mandatory to shut up Icarus Verilog

`include "video_package.svh"

module video_gen
(
    // video control signals
    input  wire hres_t           h_count_i,                      // horizontal pixel counter
    input  wire logic               v_visible_i,                    // true if scanline is in visible range
    input  wire logic               end_of_line_i,                  // true on last cycle of line
    input  wire logic               end_of_frame_i,                 // true on last cycle end of frame
    // video memories
    output      logic               dispmem_sel_o,                  // display mem read select
    output      disp_addr_t      dispmem_addr_o,                 // display mem word address out (16x64K)
    input  wire disp_data_t      dispmem_data_i,                 // display mem word data in
    output      logic               fontmem_sel_o,                  // font mem read select
    output      font_addr_t      fontmem_addr_o,                 // font mem word address out (16x5K)
    input  wire font_data_t      fontmem_data_i,                 // font mem word data in
    // video generation control signals
    input  wire logic  [2:0]        pf_h_repeat_i,                  // horizontal pixel repeat (1x to 8x)
    input  wire logic  [2:0]        pf_v_repeat_i,                  // vertical pixel repeat (1x to 8x)
    input  wire disp_addr_t      pf_line_len_i,                  // display mem word address out (16x64K)
    output      color_t          pf_color_index_o,               // output pixel color value
    // standard signals
    input  wire logic clk                                           // pixel clock
);

localparam H_MEM_BEGIN      = v::OFFSCREEN_WIDTH-64;                // memory prefetch starts early
localparam H_MEM_END        = v::TOTAL_WIDTH-8;                     // memory fetch can end at last font char

localparam H_SCANOUT_BEGIN  = v::OFFSCREEN_WIDTH-2;                 // h count for start line scanout
localparam H_SCANOUT_END    = H_SCANOUT_BEGIN + v::VISIBLE_WIDTH;

// display line fetch FSM
typedef enum logic [2:0] {
    FETCH_IDLE          =   3'h0,
    FETCH_ADDR_DISP     =   3'h1,       // output display mem address
    FETCH_WAIT_DISP     =   3'h2,       // wait for display data memory
    FETCH_READ_DISP     =   3'h3,       // read font attributes+character from display mem
    FETCH_ADDR_TILE     =   3'h4,       // output font mem address
    FETCH_WAIT_TILE     =   3'h5,       // wait for font data memory
    FETCH_READ_TILE     =   3'h6        // read font data
} video_fetch_st;

logic  [2:0]    pf_h_count;                         // current horizontal repeat countdown (1x to 8x)
logic  [2:0]    pf_v_count;                         // current vertical repeat countdown (1x to 8x)

logic  [$clog2(v::TILE_WIDTH)-1:0]   pf_tile_x;      // current column of tile cell
logic  [$clog2(v::TILE_HEIGHT)-1:0]  pf_tile_y;      // current line of tile cell

// fetch fsm outputs
// scanline generation (registered signals and "_next" combinatorally set signals)
logic [2:0]     pf_state, pf_state_next;            // playfield FSM fetch state

logic           dispmem_sel, dispmem_sel_next;      // display mem select output
always_comb     dispmem_sel_o = dispmem_sel;        // output to display mem select
disp_addr_t  pf_disp_addr, pf_disp_addr_next;    // address to fetch display data
always_comb     dispmem_addr_o  = pf_disp_addr;     // output display mem addr

logic           fontmem_sel, fontmem_sel_next;      // font mem select output
always_comb     fontmem_sel_o = fontmem_sel;        // output to font mem select
font_addr_t  pf_font_addr, pf_font_addr_next;    // font mem fetch display address
always_comb     fontmem_addr_o  = pf_font_addr;     // output font mem addr

disp_addr_t  pf_line_start;                      // display mem address of current line

logic           pf_initial_buf, pf_initial_buf_next;// true on first buffer per scanline
logic           pf_words_ready, pf_words_ready_next;// true if data_words full (8-pixels)
disp_data_t  pf_disp_word, pf_disp_word_next;    // tile attributes and tile index
font_data_t  pf_font_byte, pf_font_byte_next;    // 1st fetched display data word buffer

logic           pf_pixels_buf_full;                 // true when pf_pixels needs filling
logic [8*v::COLOR_W-1:0] pf_pixels_buf;             // 8 pixel buffer waiting for scan out
logic [8*v::COLOR_W-1:0] pf_pixels;                 // 8 pixels currently shifting to scan out

logic           scanout;                            // scanout active
logic           scanout_start;                      // scanout start strobe
logic           scanout_end;                        // scanout stop strobe
always_comb     scanout_start   = (h_count_i == H_SCANOUT_BEGIN) ? mem_fetch : 1'b0;
always_comb     scanout_end     = (h_count_i == H_SCANOUT_END)   ? 1'b1      : 1'b0;

logic           mem_fetch_h_start;
logic           mem_fetch_h_end;
logic           mem_fetch;                          // true when fetching display data
logic           mem_fetch_next;
always_comb     mem_fetch_h_start = ($bits(h_count_i)'(H_MEM_BEGIN) == h_count_i);
always_comb     mem_fetch_h_end = ($bits(h_count_i)'(H_MEM_END) == h_count_i);
always_comb     mem_fetch_next = (!mem_fetch ? mem_fetch_h_start : !mem_fetch_h_end) && v_visible_i;

// fetch FSM combinational logic
always_comb begin
    // set default outputs
    pf_initial_buf_next = pf_initial_buf;
    pf_state_next       = pf_state;
    pf_disp_addr_next   = pf_disp_addr;
    pf_font_addr_next   = pf_font_addr;

    pf_font_byte_next   = pf_font_byte;
    pf_disp_word_next   = pf_disp_word;

    pf_words_ready_next = 1'b0;
    dispmem_sel_next    = 1'b0;
    fontmem_sel_next    = 1'b0;

    case (pf_state)
        FETCH_IDLE: begin
            if (mem_fetch) begin                        // wait until mem_fetch_active
                pf_state_next   = FETCH_ADDR_DISP;
            end
        end
        FETCH_ADDR_DISP: begin
            if (!mem_fetch) begin                       // stop if no longer fetching data for line
                pf_state_next   = FETCH_IDLE;
            end else begin
                if (!pf_pixels_buf_full) begin              // if room in buffer
                    dispmem_sel_next   = 1'b1;              // select display memory
                    pf_state_next   = FETCH_WAIT_DISP;
                end
            end
        end
        FETCH_WAIT_DISP: begin
            pf_words_ready_next = !pf_initial_buf;          // set buffer ready
            pf_initial_buf_next = 1'b0;
            pf_state_next       = FETCH_READ_DISP;
        end
        FETCH_READ_DISP: begin
            pf_disp_word_next   = dispmem_data_i;           // save attribute+tile
            pf_disp_addr_next   = pf_disp_addr + 1'b1;           // increment display address
            pf_state_next       = FETCH_ADDR_TILE;          // read tile bitmap words
        end
        FETCH_ADDR_TILE: begin
            fontmem_sel_next    = 1'b1;                     // select font memory
            pf_font_addr_next   = { pf_disp_word[7:0], pf_tile_y[2:0] };
            pf_state_next       = FETCH_WAIT_TILE;
        end
        FETCH_WAIT_TILE: begin
            pf_state_next       = FETCH_READ_TILE;
        end
        FETCH_READ_TILE: begin
            pf_font_byte_next   = fontmem_data_i;           // read font data
            pf_state_next       = FETCH_ADDR_DISP;
        end
        default: begin
            pf_state_next       = FETCH_IDLE;
        end
    endcase
end

assign  pf_color_index_o    = pf_pixels[7*v::COLOR_W+:v::COLOR_W];

initial begin
    dispmem_sel_o       = 1'b0;
    dispmem_addr_o      = '0;
    fontmem_sel_o       = 1'b0;
    fontmem_addr_o      = '0;

    scanout             = 1'b0;
    mem_fetch           = 1'b0;

    pf_state            = FETCH_IDLE;
    pf_disp_addr        = '0;              // current display address during scan
    pf_disp_word        = '0;              // word with tile attributes and index
    pf_font_byte        = '0;              // buffers for unexpanded display data

    pf_initial_buf      = 1'b0;
    pf_words_ready      = 1'b0;

    dispmem_sel         = 1'b0;
    fontmem_sel         = 1'b0;

    pf_pixels_buf_full  = 1'b0;             // flag when pf_pixels_buf is empty (continue fetching)
    pf_pixels_buf       = '0;               // next 8 pixels to scan out
    pf_pixels           = '0;               // 8 pixels currently scanning out
end

always_ff @(posedge clk) begin
    // fetch FSM clocked process
    // register fetch combinitorial signals
    pf_state        <= pf_state_next;
    mem_fetch       <= mem_fetch_next;

    dispmem_sel     <= dispmem_sel_next;
    pf_disp_addr    <= pf_disp_addr_next;
    fontmem_sel     <= fontmem_sel_next;
    pf_font_addr    <= pf_font_addr_next;
    pf_disp_word    <= pf_disp_word_next;
    pf_font_byte    <= pf_font_byte_next;
    pf_initial_buf  <= pf_initial_buf_next;
    pf_words_ready  <= pf_words_ready_next;


    // have display words been fetched?
    if (pf_words_ready) begin
        pf_pixels_buf_full <= 1'b1;     // mark buffer full

        // expand font byte into 8 pixels of forecolor/backcolor (with v::COLOR_B bits per pixel)
        pf_pixels_buf  <= {
            pf_font_byte[7] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[6] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[5] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[4] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[3] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[2] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[1] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W],
            pf_font_byte[0] ? pf_disp_word[v::DISP_FORECOLOR+:v::COLOR_W] : pf_disp_word[v::DISP_BACKCOLOR+:v::COLOR_W] };
    end

    if (scanout) begin
        // shift-in next pixel
        if (pf_h_count != '0) begin
            pf_h_count              <= pf_h_count - 1'b1;
        end else begin
            pf_h_count              <= pf_h_repeat_i;
            pf_tile_x               <= pf_tile_x + 1'b1;

            if (pf_tile_x == $bits(pf_tile_x)'(v::TILE_WIDTH-1)) begin        // if last column of font tile
                pf_pixels_buf_full <= 1'b0;
                pf_pixels   <= pf_pixels_buf;       // next 8 pixels from buffer
            end else begin
                pf_pixels   <= { pf_pixels[0+:7*v::COLOR_W], (v::COLOR_W)'(0) };     // shift pixels
            end
        end
    end

    // start of line display fetch
    if (mem_fetch_h_start) begin                // on line fetch start signal
        pf_initial_buf          <= 1'b1;
        pf_pixels_buf_full      <= 1'b0;
        pf_disp_addr            <= pf_line_start;   // set start address for this line

        pf_pixels[7*v::COLOR_W+:v::COLOR_W] <= '0;  // set default color (in case blanked)
    end

    // start of scanline scanout
    if (scanout_start) begin
        scanout             <= 1'b1;
        pf_tile_x           <= 3'h0;
        pf_h_count          <= pf_h_repeat_i;
        pf_pixels           <= pf_pixels_buf;       // get initial 8 pixels from buffer
        pf_pixels_buf_full  <= 1'b0;
    end

    // end of scanline scanout
    if (scanout_end) begin
        scanout                             <= 1'b0;
        pf_pixels[7*v::COLOR_W+:v::COLOR_W] <= '0;
    end

    // end of dislpay line
    if (end_of_line_i) begin
        scanout         <= 1'b0;                                        // force scanout off
        pf_disp_addr    <= pf_line_start;                               // addr back to line start (for tile lines, or v repeat)
        if (pf_v_count != '0) begin                                  // is line repeating?
            pf_v_count      <= pf_v_count - 1'b1;                       // keep decrementing
        end else begin
            pf_v_count      <= pf_v_repeat_i;                           // reset v repeat
            if (pf_tile_y == $bits(pf_tile_y)'(v::TILE_HEIGHT-1)) begin   // is bitmap mode or last line of tile cell?
                pf_tile_y       <= 3'h0;                                // reset tile cell line
                pf_line_start   <= pf_line_start + pf_line_len_i;       // calculate next line start address
            end else begin
                pf_tile_y       <= pf_tile_y + 1;                       // next line of tile cell
            end
        end
    end

    // end of frame, prepare for next frame
    if (end_of_frame_i) begin         // is last pixel of frame?
        pf_disp_addr    <= '0;              // set start of display data
        pf_line_start   <= '0;              // set line to start of display data

        pf_v_count      <= pf_v_repeat_i;   // reset initial v repeat
        pf_tile_y       <= '0;
    end
end

endmodule
`default_nettype wire               // restore default
