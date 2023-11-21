/*
* File: CCSDS_tx_ip_M00_AXIS_tb.sv
* Author: Lionnus Kesting
* Date: July 8th, 2023
*
* Description: Testbench for the AXI4-Stream module to output one of the I or Q data streams to the filter/transceiver IP.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/

`timescale 1ns / 1ps

module CCSDS_tx_ip_MOO_AXIS_tb;

//   // Parameters
//   localparam CLK_PERIOD = 2;
//   localparam integer C_M_AXIS_TDATA_WIDTH = 32;
//   localparam integer C_M_START_COUNT = 32;

//   // Clock signal
//   reg M_AXIS_ACLK;
//   always begin
//     # (CLK_PERIOD / 2) M_AXIS_ACLK = ~M_AXIS_ACLK;
//   end

//   // Reset signal
//   reg M_AXIS_ARESETN;

//   // Inputs
//   reg [12:0] bit_i;
//   reg valid_i;

//   // Outputs
//   wire M_AXIS_TVALID;
//   wire [C_M_AXIS_TDATA_WIDTH-1:0] M_AXIS_TDATA;
//   wire [(C_M_AXIS_TDATA_WIDTH/8)-1:0] M_AXIS_TSTRB;
//   wire M_AXIS_TLAST;
//   reg M_AXIS_TREADY;

//   // DUT
//   CCSDS_tx_ip_v1_0_M00_AXIS #(
//     .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
//     .C_M_START_COUNT(C_M_START_COUNT)
//   ) DUT (
//     .bit_i(bit_i),
//     .valid_i(valid_i),
//     .M_AXIS_ACLK(M_AXIS_ACLK),
//     .M_AXIS_ARESETN(M_AXIS_ARESETN),
//     .M_AXIS_TVALID(M_AXIS_TVALID),
//     .M_AXIS_TDATA(M_AXIS_TDATA),
//     .M_AXIS_TSTRB(M_AXIS_TSTRB),
//     .M_AXIS_TLAST(M_AXIS_TLAST),
//     .M_AXIS_TREADY(M_AXIS_TREADY)
//   );

//   // Initialize
//   initial begin
//     // Reset
//     M_AXIS_ACLK = 0;
//     M_AXIS_ARESETN = 0;
//     M_AXIS_TREADY = 1;
//     valid_i = 0;
//     bit_i = 0;
//     # CLK_PERIOD;
//     M_AXIS_ARESETN = 1;
//     # CLK_PERIOD;

//     // Stimulate
//     repeat (32) begin
//       bit_i = $random;
//       valid_i = 1;
//       # CLK_PERIOD;
//     end
//     valid_i = 0;
//     // Hold state
//     # CLK_PERIOD;
//     $stop;
//   end
// endmodule`timescale 1ns / 1ps

// module tb;
    reg clk;
    reg rst_n;
    reg [12:0] i_data_i;
    reg [12:0] q_data_i;
    reg valid_i;
    wire M_AXIS_TVALID;
    wire [31:0] M_AXIS_TDATA;
    wire [3:0] M_AXIS_TSTRB;
    wire M_AXIS_TLAST;
    reg M_AXIS_TREADY;

    // Instantiate DUT
    CCSDS_tx_ip_v1_0_M00_AXIS dut (
        .M_AXIS_ACLK(clk),
        .M_AXIS_ARESETN(rst_n),
        .i_data_i(i_data_i),
        .q_data_i(q_data_i),
        .valid_i(valid_i),
        .M_AXIS_TVALID(M_AXIS_TVALID),
        .M_AXIS_TDATA(M_AXIS_TDATA),
        .M_AXIS_TSTRB(M_AXIS_TSTRB),
        .M_AXIS_TLAST(M_AXIS_TLAST),
        .M_AXIS_TREADY(M_AXIS_TREADY)
    );

    // Clock generation
    always #2 clk = ~clk;

    // Testbench logic
    initial begin
        // Initialize inputs
        clk = 0;
        i_data_i = 0;
        q_data_i = 0;
        valid_i = 0;
        M_AXIS_TREADY = 0;

        // Apply reset
        #2 rst_n = 0;
        #2 rst_n = 1;
        // Check if valid
        assert(M_AXIS_TVALID == 1);
        
        // Fill FIFO
        for (int i = 0; i < 5; i=i+1) begin
            #4 i_data_i = i; q_data_i = i; valid_i = 1;
//            #1 valid_i = 0;
            // Check the output after each frame
//             #10 assert(M_AXIS_TVALID == 1);
//             #10 assert(M_AXIS_TDATA == 0);
        end
        #4 valid_i=0;
        #4 M_AXIS_TREADY = 1;
        for (int i = 0; i < 5; i=i+1) begin
//            #10 valid_i = 0;
            // Check the output after each frame
             #4 assert(M_AXIS_TVALID == 1);
             assert(M_AXIS_TDATA == {2'b10, i, 1'b0, 2'b01, i, 1'b0});
        end

        // Check that TVALID is low after all frames are sent
        // #10 assert(M_AXIS_TVALID == 0);

        // Finish the simulation
        #10 $finish;
    end
endmodule