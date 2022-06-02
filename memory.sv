// memory.sv
//
// vim: set et ts=4 sw=4
//
// See top-level LICENSE file for license information. (Hint: MIT-0)
//

`default_nettype none             // mandatory for Verilog sanity
`timescale 1ns/1ps

module memory #(
    MEM_FILE = "",
    ADDR_W = 10,
    DATA_W = 8
) (
    input wire   logic              rd_en_i,
    input wire   logic [ADDR_W-1:0] rd_address_i,
    output       logic [DATA_W-1:0] rd_data_o,
    input wire   logic              rd_clk,
    input wire   logic              wr_en_i,
    input wire   logic [ADDR_W-1:0] wr_address_i,
    input wire   logic [DATA_W-1:0] wr_data_i,
    input wire   logic              wr_clk
);

// infer memory block
logic [DATA_W-1:0]  mem[0:2**ADDR_W-1];

initial begin
    if (MEM_FILE != "") begin
        $readmemb(MEM_FILE, mem, 0);
    end else begin
        // nice colorful display memory test pattern
        for (integer i = 0; i < 2**ADDR_W; i = i + 1) begin
            mem[i] = (DATA_W)'({(i[7:4] ^ 4'hF), i[7:4], i[7:0]} );
        end
    end
end

always_ff @(posedge rd_clk) begin
    if (rd_en_i) begin
        rd_data_o <= mem[rd_address_i];
    end
end

always_ff @(posedge wr_clk) begin
    if (wr_en_i) begin
        mem[wr_address_i] <= wr_data_i;
    end
end

endmodule
