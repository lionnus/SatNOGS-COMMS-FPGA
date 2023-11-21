/* File: bpsk_modulator_tb.sv
 * Author: Lionnus Kesting
 * Date: July 5th, 2023
 *
 * Description: Testbench for a modulator complying to the CCSDS 131.0-B4 Protocol and implementing BPSK.
 *
 * License: This file is licensed under the GNU GPL version 3.
 *
 * Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
 */
 
`timescale 1ns/1ps 

module bpsk_modulator_tb();

    // Inputs DUT
    reg clk;
    reg rst_n;
    reg bit_i=0;
    reg valid_i=0;
    reg [31:0] cycles_per_bit;

    // Outputs DUT
    wire signed [12:0] i_data_o;
    wire signed [12:0] q_data_o;
    wire valid_o;

    // Declare expected output values
    localparam bh = 13'hFFF;
    localparam bl = 13'h1001;

    // Instantiate the DUT
    bpsk_modulator #(
      ) i_bpsk_modulator (
        .clk_i(clk),
        .rst_ni(rst_n),
        .bit_i(bit_i),
        .cycles_per_bit(cycles_per_bit),
        .valid_i(valid_i),
        .valid_o(valid_o),
        .i_data_o(i_data_o),
        .q_data_o(q_data_o)
    );

 // Create a clock signal
  initial begin
    clk = 1;
    forever #1 clk = ~clk;
  end

  // Create a reset signal
  initial begin
    rst_n = 0;
    #2 rst_n = 1;
  end


/// Test case 1: Encode a sample data sequence and check the output
// Input data
  reg [13:0] test1_data_i = 14'b10001111101001;
  parameter LEN_T1 = 14;
  reg [13:0] test2_data_i = 14'b01000101011101;
  parameter LEN_T2 = 14;
  // Expected output data
  reg [181:0] data1_exp_i = {bh, bl, bl, bl, bh, bh, bh, bh, bh, bl, bh, bl, bl, bh};
  reg [181:0] data1_exp_q = {14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0};
  reg [181:0] data2_exp_i = {bl, bh, bl, bl, bl, bh, bl, bh, bl, bh, bh, bh, bl, bh};
  reg [181:0] data2_exp_q = {14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0, 14'b0};

//Initial for data application
initial begin  
    /// Test case 1: Encode a sample data sequence over single cycle
  $display("    INFO: Test 1 vector expected for I is %b.",data1_exp_i);
  $display("    INFO: Test 1 vector expected for Q is %b.",data1_exp_q);
  
  #4; //wait till reset is non-active
  valid_i=1;
  cycles_per_bit=1;
  for (integer i=0; i<LEN_T1; i=i+1) begin
    bit_i = test1_data_i[LEN_T1-i-1];
    #(cycles_per_bit*2);
  end
  valid_i = 0;
  #5;
  /// Test case 2: Encode a sample data sequence over multiple cycles
  $display("    INFO: Test 2 vector expected for I is %b.",data2_exp_i);
  $display("    INFO: Test 2 vector expected for Q is %b.",data2_exp_q);
  valid_i=1;
  cycles_per_bit=6;
  for (integer i=0; i<LEN_T1; i=i+1) begin
    bit_i = test1_data_i[LEN_T1-i-1];
    #(cycles_per_bit*2);
  end
  valid_i = 0;
  #20;
  $finish;
end
//Initial for data acquisition
initial begin
// Test 1 Acquisition
  @(posedge valid_o); // wait for first valid output
  #1; //acquisition delay
  for (integer i=0; i<LEN_T1; i=i+1) begin
    if(i_data_o==data1_exp_i[13*(LEN_T1-i)-1 -: 13]&&q_data_o==data1_exp_q[13*(LEN_T1-i)-1 -: 13]) begin
        $display("    PASS: Test 1.%d passed.",i);
    end else begin
        $error("FAIL: Test 1.%d failed, output is I %b, Q %b, expected I %b, Q %b.",i,i_data_o, q_data_o, data1_exp_i[13*(LEN_T1-i)-1 -: 13], data1_exp_q[13*(LEN_T1-i)-1 -: 13]);
    end
    #(cycles_per_bit*2);
end
#2;
if (valid_o!=0) $error("FAIL: Test case 1, valid_o still asserted after 1 cycles after valid_i deassertion.");
else $display("     PASS: Test case 1,correct valid_o deassertion!");
$display("      INFO: Test case 1 completed"); 

//Test 2 Acquisition
@(posedge valid_o); // wait for first valid output
  #1; //acquisition delay
  for (integer i=0; i<LEN_T2; i=i+1) begin
    if(i_data_o==data2_exp_i[13*(LEN_T2-i)-1 -: 13]&&q_data_o==data2_exp_q[13*(LEN_T2-i)-1 -: 13]) begin
        $display("    PASS: Test 2.%d passed.",i);
    end else begin
        $error("FAIL: Test 2.%d failed, output is I %b, Q %b, expected I %b, Q %b.",i,i_data_o, q_data_o, data2_exp_i[13*(LEN_T2-i)-1 -: 13], data2_exp_q[13*(LEN_T2-i)-1 -: 13]);
    end
    #(cycles_per_bit*2);
end
#2;
if (valid_o!=0) $error("FAIL: Test case 2, valid_o still asserted after 1 cycles after valid_i deassertion.");
else $display("     PASS: Test case 2, correct valid_o deassertion!");
$display("      INFO: Test case 2 completed"); 
end

endmodule