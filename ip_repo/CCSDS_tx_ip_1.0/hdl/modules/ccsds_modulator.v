/*
 * File: ccsds_modulator.sv
 * Author: Lionnus Kesting
 * Date: July 5th, 2023
 *
 * Description: Modulator complying to the CCSDS 131.0-B4 Protocol, implementing BPSK Modulation.
 *
 * License: This file is licensed under the GNU GPL version 3.
 *
 * Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
 */
 
module ccsds_modulator # (
    parameter CLK_FREQ = 64, // Clock frequency (MHz)
    parameter SAMPLE_RATE = 1, // Sample rate as given for AT86RF215
    parameter MOD_TYPE = 0 // BPSK = 0
    )(
    input wire clk_i,
    input wire rst_ni,
    input wire bit_i,
    output reg [12:0] i_data_o,
    output reg [12:0] q_data_o,
    input wire [31:0] cycles_per_bit,
    input wire valid_i,
    output reg valid_o
);

reg [1:0] buffer_d, buffer_q;
reg [31:0] count=0;

// Assign output data
always @(*) begin
    buffer_d = bit_i;
    // Calculate I(/Q) values
    case(buffer_q)
            2'b00: begin
                i_data_o = -(2**12 - 1);
                q_data_o = 0;
            end
            2'b01: begin
                i_data_o = (2**12 - 1);
                q_data_o= 0;
            end
            default: begin
                i_data_o = 0;
                q_data_o = 0;
            end
        endcase
end

always @(posedge clk_i) begin
    if (!rst_ni) begin
        buffer_q <= 2'b11; // Make output zero
        count <= cycles_per_bit; // Reset the bit delay counter
        valid_o <= 0;
    end
    else begin
        if (count < cycles_per_bit-1) begin
            count <= count + 1;
        end else if (valid_i) begin
            buffer_q <= buffer_d;
            valid_o <= 1;
            count <= 0;
        end else begin
            buffer_q <= 0;
            count <= cycles_per_bit;
            valid_o <= 0;
        end
    end
end

endmodule
