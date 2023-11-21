`timescale 1 ns / 1 ps

module CCSDS_tx_ip_v1_0_M00_AXIS #
(
	parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
	parameter integer FIFO_DEPTH = 16  // Parameterized FIFO depth
)
(
	input wire [12:0] i_data_i, // In phase component
    input wire [12:0] q_data_i, // Quadrature phase component
	input wire valid_i, // Valid signal for IQ components
	input wire  M_AXIS_ACLK,
	input wire  M_AXIS_ARESETN,
	output wire  M_AXIS_TVALID,
	output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
	output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
	output wire  M_AXIS_TLAST,
	input wire  M_AXIS_TREADY
);

localparam WR_PTR_WIDTH = $clog2(FIFO_DEPTH);
localparam RD_PTR_WIDTH = $clog2(FIFO_DEPTH);

reg [12:0] fifo_mem [0:FIFO_DEPTH-1]; // FIFO memory
reg [WR_PTR_WIDTH-1:0] wr_ptr = 0; // Write pointer
reg [RD_PTR_WIDTH-1:0] rd_ptr = 0; // Read pointer
reg [C_M_AXIS_TDATA_WIDTH-1 : 0] stream_data_out = 0;
reg tx_done = 0;
wire tx_en;

// Reset and Write Pointer Logic
always @(posedge M_AXIS_ACLK or negedge M_AXIS_ARESETN)
begin
  if(!M_AXIS_ARESETN)
  begin
    wr_ptr <= 0;
    rd_ptr <= 0;
    stream_data_out <= 0;
    tx_done <= 0;
  end
  else if(valid_i && wr_ptr != FIFO_DEPTH-1)
  begin
    fifo_mem[wr_ptr] <= {2'b10, i_data_i, 1'b0, 2'b01, q_data_i, 1'b0}; // Write IQ components to FIFO
    wr_ptr <= wr_ptr + 1; // Increment the write pointer
  end
end

// Read Pointer Logic and tx_done signal
always @(posedge M_AXIS_ACLK)
begin
  if(!M_AXIS_ARESETN || wr_ptr == rd_ptr) // Reset or FIFO empty
    tx_done <= 1'b0;
  else if (tx_en && wr_ptr != rd_ptr) // Read from FIFO when tx_en is high and FIFO is not empty 
  begin
    stream_data_out <= fifo_mem[rd_ptr]; // Read from FIFO
    rd_ptr <= rd_ptr + 1; // Increment the read pointer
    tx_done <= (rd_ptr == wr_ptr) ? 1'b1 : 1'b0; // Mark tx_done when all data is read from FIFO
  end
end

// Control Logic
assign tx_en = M_AXIS_TREADY && (wr_ptr != rd_ptr);
assign M_AXIS_TVALID = tx_en;
assign M_AXIS_TDATA  = tx_en ? stream_data_out : 0;
assign M_AXIS_TSTRB  = tx_en ? {((C_M_AXIS_TDATA_WIDTH+7)/8){1'b1}} : 0;
assign M_AXIS_TLAST  = tx_done;

endmodule
