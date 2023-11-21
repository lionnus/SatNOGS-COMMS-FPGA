/*
 * File: ccsds_modulator_tb.sv
 * Author: Lionnus Kesting
 * Date: April 27, 2023
 *
 * Description: Testbench for a modulator complying to the CCSDS 131.0-B4 Protocol.
 *
 * License: This file is licensed under the GNU GPL version 3.
 *
 * Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
 */
 
`timescale 1ns/1ps 

module ccsds_modulator_tb();

    // Inputs
    reg clk;
    reg rst_n;
    reg [1:0] bits_i;
    reg [31:0] cycles_per_sample=1;
    //reg tx_valid;
    //wire rx_ready;

    // Outputs
    wire signed [12:0] i_data_o;
    wire signed [12:0] q_data_o;
    //reg tx_ready=1;

    // Instantiate the DUT
    ccsds_modulator #(
      ) i_ccsds_modulator (
        .clk_i(clk),
        .rst_ni(rst_n),
        .bits_i(bits_i),
        .i_data_o(i_data_o),
        .q_data_o(q_data_o),
        .samples_per_symbol(cycles_per_sample)
    );

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


/// Test case 1: Encode a sample data sequence and check the output
// Input data
  reg [9:0] test1_data_i = 10'b0001111000;
  reg [19:0] test2_data_i = 20'b001101111111101100;
  // Expected output data
  logic [12:0] data_00_i = 13'b0111111111111;
  logic [12:0] data_00_q = 13'b0111111111111;
  logic [12:0] data_01_i = 13'b0111111111111;
  logic [12:0] data_01_q = 13'b1000000000001;
  logic [12:0] data_10_i = 13'b1000000000001;
  logic [12:0] data_10_q = 13'b0111111111111;
  logic [12:0] data_11_i = 13'b1000000000001;
  logic [12:0] data_11_q = 13'b1000000000001;
  reg [64:0] data_exp_i = {data_00_i, data_01_i, data_11_i, data_10_i, data_00_i};
  reg [64:0] data_exp_q = {data_00_q, data_01_q, data_11_q, data_10_q, data_00_q};

initial begin  
  $display("Test vector expected for I is %b.",data_exp_i);
  $display("Test vector expected for Q is %b.",data_exp_q);
  
  #10; //wait till reset is non-active
  
  for (integer i=0; i<5; i=i+1) begin
    bits_i = test1_data_i[2*i+:2];
    $display("Test %d, q input is %b, expected output is I %b, Q %b.",i,test1_data_i[2*i+:2], data_exp_i[13*i+:13],data_exp_q[13*i+:13]);
    #2;
    if(i_data_o==data_exp_i[13*i+:13]&&q_data_o==data_exp_q[13*i+:13]) begin
        $display("Test %d passed.",i);
    end else begin
        $display("Test %d failed, output is I %b, Q %b.",i,i_data_o, q_data_o);
    end
    end
    #2;
    
    // Testcase 2: Input data for multiple clockcycles
    rst_n=0;
    #2;
    rst_n=1;
    #10; //wait for some time
    
    //change cycles per sample to 2
    cycles_per_sample=2;
    data_exp_i = {data_00_i, data_01_i, data_11_i, data_10_i, data_00_i};
    data_exp_q = {data_00_q, data_01_q, data_11_q, data_10_q, data_00_q};
    
    for (integer i=0; i<5; i=i+1) begin
    bits_i = test2_data_i[2*i+:2];
    $display("Test %d, q input is %b, expected output is I %b, Q %b.",i,test2_data_i[2*i+:2], data_exp_i[13*i+:13],data_exp_q[13*i+:13]);
    #2;
    if(i_data_o==data_exp_i[13*i+:13]&&q_data_o==data_exp_q[13*i+:13]) begin
        $display("Test %d part 1 passed.",i+5);
    end else begin
        $display("Test %d part 1 failed, output is I %b, Q %b.",i+5,i_data_o, q_data_o);
    end
    #2;
    if(i_data_o==data_exp_i[13*i+:13]&&q_data_o==data_exp_q[13*i+:13]) begin
        $display("Test %d part 2 passed.",i+5);
    end else begin
        $display("Test %d part 2 failed, output is I %b, Q %b.",i+5,i_data_o, q_data_o);
    end
    end
    #10;
        // End simulation
        $finish;
    end

endmodule