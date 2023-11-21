/*
* File: ccsds_scrambler_tb.sv
* Author: Lionnus Kesting
* Date: April 16, 2023
*
* Description: Testbench for a pseudo-randomizer/scrambler according to the CCSDS 131.0-B3 standard.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/
`timescale 1ns/1ps 

module ccsds_scrambler_tb();

  // Define module inputs and outputs
  reg bit_in;
  logic enc_bits_out;
  reg clk, rst_n;

  // Instantiate the convolutional encoder module
  ccsds_scrambler i_ccsds_scrambler(   
    .data_i(bit_in), 
    .data_o(enc_bits_out),
    .clk_i(clk), 
    .rst_ni(rst_n));

  // Create a clock signal
  initial begin
    clk = 1;
    forever #1 clk = ~clk;
  end

  // Create a reset signal
  initial begin
    rst_n = 0;
    #10 rst_n = 1;
  end

// Test case 1: Encode a sample data sequence and check the output
// Input data
  reg [39:0] data_in = 40'b0;//40'b0000000010110111111111101100000010011010;
  // Expected output data
  reg [39:0] data_exp = 40'b1111111101001000000011101100000010011010;//{20'b1,20'b0};
  // Setup acquisition register
  reg [39:0] data_acq;
initial begin  
  #10; //wait till reset is non-active
  for (integer i=0; i<40; i=i+1) begin
    bit_in = data_in[i];
    #2;
    data_acq[39-i] = enc_bits_out;
  end
   if (data_exp!=data_acq) begin
    $display("Test 1 failed!");
   end else begin
    $display("Test 1 passed.");
  end
end
  
endmodule
