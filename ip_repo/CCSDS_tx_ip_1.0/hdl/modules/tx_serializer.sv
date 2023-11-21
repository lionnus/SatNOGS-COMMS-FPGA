/*
* File: tx_serializer.sv
* Author: Lionnus Kesting
* Date: May 4, 2023
*
* Description: Takes in CCSDS frame and serializes it when valid_i is high. When valid_o is high, the data_o is valid and can be read.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/
`timescale 1ns/1ps 

module tx_serializer #(
    parameter CADU_WIDTH = 20 // Amount of bits that need to be sent
    )
    (
    input   wire clk_i,
    input   wire rst_ni,
    input   wire [CADU_WIDTH*8-1:0] data_i,
    output  reg data_o,
    output  reg valid_o,
    input   wire valid_i,
    input   wire [31:0] cycles_per_bit //amount of cycles for which output should not change
);

reg [31:0] count_frame=0; //counts till CADU_WIDTH
reg [31:0] count_cycles_bit=0; //counts till cycles_per_bit
reg [CADU_WIDTH*8-1:0] frame_reg=0;
reg delay = 0;

localparam GET_SAMPLE = 0, SEND_SAMPLE = 1;
reg state = GET_SAMPLE;

always @(posedge clk_i) begin
    if (!rst_ni) begin
        count_frame <= 0;
        count_cycles_bit <= 0;
        frame_reg <= 0;
        data_o <= 0;
        valid_o <= 0;
        delay <= 0;
        state <= GET_SAMPLE;
    end
    else begin
        case(state)
            GET_SAMPLE:
            begin
                if(valid_i) begin
                    frame_reg <= data_i;
                    state <= SEND_SAMPLE;
                    data_o <= frame_reg[CADU_WIDTH*8-count_frame-1];
                    valid_o <= 1;
                    count_cycles_bit <= count_cycles_bit + 1;
                end
             end
            SEND_SAMPLE:
                begin
                    if (count_frame < CADU_WIDTH*8) begin
                            data_o <= frame_reg[CADU_WIDTH*8-count_frame-1];
                            valid_o <= 1;
                        if (count_cycles_bit >= cycles_per_bit -1) begin
                            count_frame <= count_frame + 1;
                            count_cycles_bit <= 0;
                        end else begin
                            count_cycles_bit <= count_cycles_bit + 1;
                        end
                    end else begin
                        count_frame <= 0;
                        count_cycles_bit <= 0;
                        valid_o <= 0;
                        data_o <= 0;
                        state <= GET_SAMPLE;
                    end
                end
            default:
                begin
                    count_frame <= 0;
                    count_cycles_bit <= 0;
                    valid_o <= 0;
                    state <= GET_SAMPLE;
                end
        endcase
end
end

endmodule
