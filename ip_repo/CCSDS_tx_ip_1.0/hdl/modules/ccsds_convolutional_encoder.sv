/*
* File: ccsds_convolutional_encoder.sv
* Author: Lionnus Kesting
* Date: April 15, 2023
*
* Description: Convolutional encoder for the CCSDS 131.0-B4 Protocol.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/

module ccsds_convolutional_encoder #(
    parameter integer K = 7,
    parameter integer G1 = 7'o171,
    parameter integer G2 = 7'o133
    )(
    input   logic data_i,
    output  logic data_o,
    input   logic valid_i,
    output  logic valid_o,
    input   logic clk_i,
    input   logic rst_ni,
    input   logic [31:0] cycles_per_bit_i, // minimum of 2
    output  logic [31:0] cycles_per_bit_o
);

logic [K-1:0] state_d, state_q = '0;
logic [31:0] count = 0; // Counter to delay the input and output change
logic C1, C2;

// Assign output bit, taking into account cycles_per_bit
assign data_o = (count < cycles_per_bit_i>>1) ? C1 : C2;
assign cycles_per_bit_o = cycles_per_bit_i >>1;
// Compute the output bits and new state register values
always_comb begin
    C1 =   (state_q[0]&G1[0])^(state_q[1]&G1[1])^(state_q[2]&G1[2])^(state_q[3]&G1[3])^(state_q[4]&G1[4])^(state_q[5]&G1[5])^(state_q[6]&G1[6]);
    C2 = ~((state_q[0]&G2[0])^(state_q[1]&G2[1])^(state_q[2]&G2[2])^(state_q[3]&G2[3])^(state_q[4]&G2[4])^(state_q[5]&G2[5])^(state_q[6]&G2[6]));
    state_d[K-2:0] = state_q[K-1:1]; // Shift state register by one bit
    state_d[K-1]   = data_i;         // Add new input bit to state register
end

always_ff @(posedge clk_i) begin
    if (!rst_ni || !valid_i) begin
        state_q <= 'b10; // Reset the state register
        count <= cycles_per_bit_i; // Reset the bit delay counter
        valid_o <= 0;
    end
    else begin
        if (count < cycles_per_bit_i-1) begin
            count <= count +1;
        end else begin
            state_q <= state_d;
            valid_o <= 1;
            count <= 0;
            end
    end
end // always_ff
endmodule
