/*
 * File: ccsds_modulator.sv
 * Author: Lionnus Kesting
 * Date: April 27, 2023
 *
 * Description: Modulator complying to the CCSDS 131.0-B4 Protocol. Currently, only (B/Q)PSK modulation is implemented for a 64 Mhz clock,\
 *              resulting in a 4 Msamples/s output as required by the AT86RF215. this uses double data rate.
 *
 * License: This file is licensed under the GNU GPL version 3.
 *
 * Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
 */

module ccsds_modulator # (
    parameter CLK_FREQ = 64, // Clock frequency (MHz)
    parameter SAMPLE_RATE = 1 // Sample rate as given for AT86RF215
    )(
    input                   clk_i,
    input                   rst_ni,
    input           [1:0]   bits_i,
    output  signed  [12:0]  i_data_o,
    output  signed  [12:0]  q_data_o,
    input           [31:0]  samples_per_symbol
);

reg [1:0] buffer_d, buffer_q;
reg [12:0] i_reg_d, i_reg_q, q_reg_d, q_reg_q;
reg [31:0] cycle_count_d, cycle_count_q;

// Assign outputs
assign i_data_o = i_reg_q;
assign q_data_o = q_reg_q;

always_comb begin
     // Accept new data after cycles per sample
     if(cycle_count_q<(samples_per_symbol-1)) begin
         buffer_d = buffer_q;
         cycle_count_d = cycle_count_q + 1;
     end
     // Else keep current buffer and ignore input
     else begin
         buffer_d = bits_i;
         cycle_count_d = 0;
     end
    // // Calculate I/Q values without time shift
    case(buffer_q)
            2'b00: begin
                i_reg_d = (2**12 - 1);// * cos(PI/4);
                q_reg_d = (2**12 - 1);// * sin(PI/4);
            end
            2'b01: begin
                i_reg_d = (2**12 - 1);// * cos(3*PI/4);
                q_reg_d = -(2**12 - 1);// * sin(3*PI/4);
            end
            2'b10: begin
                i_reg_d = -(2**12 - 1);// * cos(5*PI/4);
                q_reg_d = (2**12 - 1);// * sin(5*PI/4);
            end
            2'b11: begin
                i_reg_d = -(2**12 - 1);// * cos(7*PI/4);
                q_reg_d = -(2**12 - 1);// * sin(7*PI/4);
            end
        endcase
end

// Update all registers at clk, reset to zero at !rst_n
always @(posedge clk_i) begin
    if(!rst_ni) begin
        i_reg_q <= 0;
        q_reg_q <= 0;
        cycle_count_q <= 0;
        buffer_q <= 0;
    end
    else begin
        buffer_q <= buffer_d;
        i_reg_q <= i_reg_d;
        q_reg_q <= q_reg_d;
        cycle_count_q <= cycle_count_d;
    end
end

endmodule