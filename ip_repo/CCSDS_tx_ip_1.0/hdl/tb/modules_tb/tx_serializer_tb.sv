/*
* File: tx_serializer_tb.sv
* Author: Lionnus Kesting
* Date: May 28th, 2023
*
* Description: Testbench for a serializer that takes in CADU_WIDTH/AXI_DATA_WIDTH packages and sends them out bit-by-bit.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/
`timescale 1ns/1ps 

module tx_serializer_tb();

  // Define module inputs and outputs
  reg clk, rst_n;
  parameter CADU_WIDTH = 5; // Choose between 1 and (2^31)-1 AND as integer multiple of AXI_DATA_WIDTH
  parameter APPL_DEL = 0.05;
  parameter ACQ_DEL = 0.05;

  reg   [CADU_WIDTH*8-1:0] data;
  wire   bit_o;
  reg   valid_set=0;
  wire   valid_o;
  reg [31:0] cycles_per_bit = 1;
  

  // Instantiate the convolutional encoder module
   	tx_serializer #(
   	.CADU_WIDTH(CADU_WIDTH)
   	) i_tx_serializer(   
       .data_i(data), 
       .data_o(bit_o),
       .valid_o(valid_o),
       .valid_i(valid_set),
       .cycles_per_bit(cycles_per_bit),
       .clk_i(clk), 
       .rst_ni(rst_n));

  // Create a clock signal
  initial begin
    clk = 1;
    forever #0.5 clk = ~clk;
  end

  // Create a reset signal
  initial begin
    rst_n = 0;
    #5 rst_n = 1;
  end

// Input data
reg [39:0] data_test = 40'b1111111110101000000011101100000010011010; //{20'b1,20'b0};
// // Expected output data
// reg [39:0] data_exp = 40'b1111111101001000000011101100000010011010;
// Setup acquisition register
// reg [39:0] data_acq=0;
// reg bit_exp;

initial begin  
#10; //wait till reset is non-active

// Test case 1: Encode a sample data sequence and check the output
$display("-----------------------------\nTest 1 started\n-----------------------------\n");
@(posedge clk);
#APPL_DEL;
valid_set=1;
data = data_test;
@(posedge valid_o);
for (integer i=0; i<CADU_WIDTH*8; i=i+1) begin
  #ACQ_DEL;
  valid_set =0;
    if(valid_o==1) begin
      if(bit_o==data_test[CADU_WIDTH*8-1-i]) begin
        $display("[%t]:   PASS: bit %d correctly asserted.",$realtime,i);
      end
      else begin
        $display("[%t]: FAIL: bit %d not asserted correctly.",$realtime,i);
      end
      $display("[%t]:   PASS: valid correctly asserted.",$realtime);
    end 
    else begin
      $display("[%t]:   FAIL: valid not asserted.",$realtime);
    end
    @(posedge clk);
end
#APPL_DEL;
valid_set =0;
@(posedge clk);
#ACQ_DEL;
if(valid_o==0) $display("[%t]:   PASS: valid correclty deasserted.",$realtime);
else $display("[%t]: FAIL: valid not deasserted.",$realtime);

// Test case 2: Test second data sequence with cycles_per_bit!=1
#10;
// Input data
data_test = 40'b1111111110101000000011101100000010011010; //random sequence
cycles_per_bit = 3;

$display("-----------------------------\nTest 2 started\n-----------------------------\n");
@(posedge clk);
#APPL_DEL;
valid_set=1;
data = data_test;
@(posedge valid_o);
for (integer i=0; i<CADU_WIDTH*8; i=i+1) begin
    for(integer b=0; b<cycles_per_bit; b=b+1) begin
      #ACQ_DEL;
      valid_set=0;
        if(valid_o==1) begin
            if(bit_o==data_test[CADU_WIDTH*8-1-i]) begin
                $display("[%t]:   PASS: bit %d correctly asserted at %d/3.",$realtime,i,b);
            end
            else begin
                $display("[%t]: FAIL: bit %d not asserted correctly at %d/3.",$realtime,i,b);
            end
            $display("[%t]:   PASS: valid correctly asserted at %d.",$realtime,i);
            end 
        else begin
          $display("[%t]:   FAIL: valid not asserted at %d.",$realtime,i);
        end
        @(posedge clk);
    end
end
#APPL_DEL;
valid_set =0;
@(posedge clk);
#ACQ_DEL;
if(valid_o==0) $display("[%t]:   PASS: valid correclty deasserted.",$realtime);
else $display("[%t]: FAIL: valid not deasserted.",$realtime);
#10;
$finish;
end
  
endmodule
