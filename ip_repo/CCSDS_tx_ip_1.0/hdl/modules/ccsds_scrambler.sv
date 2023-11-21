/*
* File: ccsds_scrambler.sv
* Author: Lionnus Kesting
* Date: April 16, 2023
*
* Description: Pseudo-randomizer/scrambler working on a continuous data stream according to the CCSDS 131.0-B3 standard. 
* Can be adjusted to work over multiple cycles to adjust data rate. 
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/

module ccsds_scrambler
(
    input        logic   data_i,
    output       logic   data_o,
    input        clk_i,
    input        rst_ni,
    input [31:0] cycles_per_bit
);
    reg  [7:0]    state_q, state_d;
    reg           data_o_q, data_o_d;
    reg  [7:0]    count_d, count_q;
    
    reg  [31:0]   cycle_counter;

    assign count_d = count_q + 1; // Update counter

    // Assign output to output FF
    assign data_o = data_o_q;

    always_comb begin
        // Update new state based on defined polynomial h(x) = x^8 + x^7 + x^5 + x^3 + x^0
        state_d[6:0] = state_q[7:1];
        state_d[7]   = state_q[0] ^ state_q[3] ^ state_q[5] ^ state_q[7];
        // XOR input data with output of pseudo-randomizer
        data_o_d     = data_i ^ state_q[0]; 
    end

    always_ff @(posedge clk_i)
    begin
        data_o_q <= data_o_d;
        if (!rst_ni) begin
            state_q      <= 8'b11111111;
            count_q      <= '0;
            cycle_counter <= 32'b0;
        end else if (cycle_counter < cycles_per_bit) begin
            state_q      <= state_q;
            count_q      <= count_d;
            cycle_counter <= cycle_counter + 1;
        else begin
            cycle_counter = 0;
            // Operates on blocks of 255 bits, reset the state with 'all ones' -> unclear if this is correct or if it should be all 0
            if (count_q < 255) begin 
                state_q      <= state_d;
                count_q      <= count_d;
            end else begin
                state_q      <= 8'b11111111;
                count_q      <= '0;
                cycle_counter <= cycle_counter + 1;
            end
        end 
            end
        end


endmodule
