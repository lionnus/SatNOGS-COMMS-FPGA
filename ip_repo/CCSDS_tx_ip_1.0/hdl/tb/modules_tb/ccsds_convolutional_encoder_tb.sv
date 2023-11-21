/*
 * File: ccsds_convolutional_encoder_tb.sv
 * Author: Lionnus Kesting
 * Date: April 15, 2023
 *
 * Description: Testbench for a convolutional encoder for the CCSDS 131.0-B4 Protocol.
 *
 * License: This file is licensed under the GNU GPL version 3.
 *
 * Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
 */
 
`timescale 1ns/1ps 

module ccsds_convolutional_encoder_tb();

  // Define module inputs and outputs
  reg bit_in = 0;
  logic enc_bit_out;
  reg [31:0] cycles_per_bit;
  reg clk, rst_n;
  localparam SEQ_LENGTH = 160;
  reg valid_i = 0;
  logic valid_o;
  logic [31:0] cycles_per_bit_o;

  // Instantiate the convolutional encoder module
  ccsds_convolutional_encoder i_ccsds_convolutional_encoder(   
    .data_i(bit_in), 
    .data_o(enc_bit_out),
    .valid_i(valid_i),
    .valid_o(valid_o),
    .clk_i(clk), 
    .rst_ni(rst_n),
    .cycles_per_bit_i(cycles_per_bit),
    .cycles_per_bit_o(cycles_per_bit_o));

  // Create a clock signal
  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  // Create a reset signal
  initial begin
    rst_n = 0;
    #10 rst_n = 1;
  end

reg [SEQ_LENGTH-1:0] data_app= 0;
reg [2*SEQ_LENGTH-1:0] data_exp=0;
localparam LEN_T1 = 7;
localparam LEN_T2 = 160;

initial begin
// Test case 1: Encode a SIMPLE data sequence, expected value calculated by hand
data_app = 7'b1110111; 
data_exp = 14'b10001111101001;
  cycles_per_bit <= 4;
  #11 // Wait till reset is non-active  
  @(posedge clk);
  valid_i <= 1;
  for (int i = 0; i < LEN_T1; i++) begin
    bit_in <= data_app[LEN_T1-i-1]; // Apply data_app bit, MSB till LSB
    #3;
    // Read out encoded bit and compare against the first output bit
    if (enc_bit_out !== data_exp[2*(LEN_T1-i)-1]) $error("FAIL: Test case 1.1: input %d failed, first value, value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T1-i)-1]);
    else $display("     PASS: Test case 1.1, first bit %d correct!", i);
    #(cycles_per_bit);
    if (enc_bit_out !== data_exp[2*(LEN_T1-i)-2]) $error("FAIL: Test case 1.1: input %d failed, second value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T1-i)-2]);
    else $display("     PASS: Test case 1.1, second bit %d correct!", i);
    #(cycles_per_bit-3);
  end
  valid_i <= 0;
  #3;
  if (valid_o!=0) $error("FAIL: valid_o still asserted after cycles_per_bit/2 cycles after valid_i deassertion.");
  else $display("     PASS: Test case 1.1,correct valid_o deassertion!");
  $display("Test case 1.1 completed");
  #2;
  // Test case 2: Encode a SIMPLE data sequence, multiple cycles per bit
data_app = 7'b1110111; 
data_exp = 14'b10001111101001;
  cycles_per_bit <= 6;
  #11 // Wait till reset is non-active  
  @(posedge clk);
  valid_i <= 1;
  for (int i = 0; i < LEN_T1; i++) begin
    bit_in <= data_app[LEN_T1-i-1]; // Apply data_app bit, MSB till LSB
    #3;
    // Read out encoded bit and compare against the first output bit
    if (enc_bit_out !== data_exp[2*(LEN_T1-i)-1]) $error("FAIL: Test case 1.2: input %d failed, first value, value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T1-i)-1]);
    else $display("     PASS: Test case 1.2, first bit %d correct!", i);
    #(cycles_per_bit);
    if (enc_bit_out !== data_exp[2*(LEN_T1-i)-2]) $error("FAIL: Test case 2: input %d failed, second value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T1-i)-2]);
    else $display("     PASS: Test case 1.2, second bit %d correct!", i);
    #(cycles_per_bit-3);
  end
  valid_i <= 0;
  #3;
  if (valid_o!=0) $error("FAIL: valid_o still asserted after 1 cycles after valid_i deassertion.");
  else $display("     PASS: Test case 1.2,correct valid_o deassertion!");
  $display("Test case 1.2 completed");
  #2;
// Test case 2: Encode a longer data sequence, expected value genrated in MATLAB
//  data_app = 128'h3FA598708734FE00BA349826400EDFE6;
//  data_exp = 256'h58C19230026A0FDF0A7FD293FB19CF95B7E505E3CE1A37919852558FA82B69FA;
  data_app = 160'h1ACFFC1D48454c4c4f2c4954532d534147452100; 
  data_exp = 320'h56081C971AA73D3E790D72AA1536B546B54BCDC0757ECD65DA2366C3CA535321D2D4E41A20D72925;
  cycles_per_bit <= 4;
  #5; // Wait for arbitrary period
  @(posedge clk);
  valid_i <= 1;
  for (int i = 0; i < LEN_T2; i++) begin
    bit_in <= data_app[LEN_T2-i-1]; // Apply data_app bit, MSB till LSB
    #3;
    // Read out encoded bit and compare against the first output bit
    if (enc_bit_out !== data_exp[2*(LEN_T2-i)-1]) $error("FAIL: Test case 2: input %d failed, first value, value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T2-i)-1]);
    else $display("     PASS: Test case 2, first bit %d correct!", i);
    #(cycles_per_bit);
    if (enc_bit_out !== data_exp[2*(LEN_T2-i)-2]) $error("FAIL: Test case 1: input %d failed, second value is %b, expected %b", i, enc_bit_out, data_exp[2*(LEN_T2-i)-2]);
    else $display("     PASS: Test case 2, second bit %d correct!", i);
    #(cycles_per_bit-3);
  end
  valid_i <= 0;
  #3;
  if (valid_o!=0) $error("FAIL: Test case 2, valid_o still asserted after cycles_per_bit/2 cycles after valid_i deassertion.");
  else $display("     PASS: Test case 2,correct valid_o deassertion!");
  $display("Test case 2 completed");
  #10;
$finish;
end



endmodule


