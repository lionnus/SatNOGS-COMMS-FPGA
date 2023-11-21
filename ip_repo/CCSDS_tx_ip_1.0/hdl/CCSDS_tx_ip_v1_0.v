
`timescale 1 ns / 1 ps

	module CCSDS_tx_ip_v1_0 #
	(
				// Users to add parameters here
		parameter CADU_WIDTH = 20, // Number of bytes of CADU, TF_WIDTH is CADU-4 bytes
    	parameter SPI_WIDTH = 8,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// The master will start generating data from the value
        parameter  SPI_RESPONSE_OKAY	= 32'h34,
		parameter  SPI_RESPONSE_START	= 32'h69,
		parameter  SPI_RESPONSE_FAIL	= 32'h46, //Currently not implemented
		parameter  SPI_RESPONSE_RST   	= 32'h22,
		// The master requires a target slave base address.
    // The master will initiate read and write transactions on the slave with base address specified here as a parameter.
		parameter AXI_QUAD_SPI_BASE_ADDR = 32'h44A00000,
		parameter SPICR_OFFSET_ADDR = 32'h60, // SPI Control Register
		parameter SPISR_OFFSET_ADDR = 32'h64, // SPI Status Register
		parameter IPIER_OFFSET_ADDR = 32'h28, // SPI IP Interrupt Enable Register
		parameter DGIER_OFFSET_ADDR = 32'h1C, // SPI Global Interrupt Enable
		parameter SPIDTR_OFFSET_ADDR = 32'h68, // SPI Data Transmit Register
		parameter SPIDRR_OFFSET_ADDR = 32'h6C, // SPI Data Receive Register
		// Values for SPI Control Register
		parameter SPICR_ENABLE = 32'h182, // SPI Enable
		parameter SPICR_DISABLE = 32'h180, // SPI Disable
		parameter SPICR_FIFO_RESET = 32'h1E2, // SPI Enable and TX and RX FIFO Reset
		parameter IPIER_DDR_NOT_EMPTY = 32'b100000000,
		parameter DGIER_ENABLE = 32'h80000000,

		// // Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 16,
		parameter integer C_M00_AXIS_START_COUNT	= 32

	)
	(
		// Users to add ports here
		input wire spi_rx_empty_interrupt_i,
		// Wires for serializer
		output wire [CADU_WIDTH*8-1:0] frame_o,
		output wire enable_serializer_o,
		input wire serializer_done_i,
		
		// Debug wires
		output 	wire [2:0] fsm_state_o, // State of the FSM
		input wire [3:0] debug_i,
		output wire ccsds_read_in,
		output wire count_debug,
		// Debug wires serializer
//		output  wire data_o, // Serialized output data
//		output  wire data_valid_o, // Data valid signal
		// Input wires for AXI4-Stream interface
		input wire [15:0] i_data_i,
		input wire i_data_valid_i,
		input wire [15:0] q_data_i,
		input wire q_data_valid_i,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Master Bus Interface M00_AXI
//		output wire  m00_axi_error,
//		output wire  m00_axi_rxn_done,
		input wire  m00_axi_aclk,
		input wire  m00_axi_aresetn,
		output wire [31: 0] m00_axi_awaddr,
		output wire [2 : 0] m00_axi_awprot,
		output wire  m00_axi_awvalid,
		input wire  m00_axi_awready,
		output wire [31 : 0] m00_axi_wdata,
		output wire [32/8-1 : 0] m00_axi_wstrb,
		output wire  m00_axi_wvalid,
		input wire  m00_axi_wready,
		input wire [1 : 0] m00_axi_bresp,
		input wire  m00_axi_bvalid,
		output wire  m00_axi_bready,
		output wire [31: 0] m00_axi_araddr,
		output wire [2 : 0] m00_axi_arprot,
		output wire  m00_axi_arvalid,
		input wire  m00_axi_arready,
		input wire [31 : 0] m00_axi_rdata,
		input wire [1 : 0] m00_axi_rresp,
		input wire  m00_axi_rvalid,
		output wire  m00_axi_rready,


		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready
		
	);
// Instantiation of Axi Bus Interface M00_AXI
	CCSDS_tx_ip_v1_0_M00_AXI # ( 
		.AXI_QUAD_SPI_BASE_ADDR(AXI_QUAD_SPI_BASE_ADDR),
		.CADU_WIDTH(CADU_WIDTH),
		.SPI_WIDTH(SPI_WIDTH),
		.SPI_RESPONSE_OKAY(SPI_RESPONSE_OKAY),
		.SPI_RESPONSE_FAIL(SPI_RESPONSE_FAIL),
		.SPICR_OFFSET_ADDR(SPICR_OFFSET_ADDR),
		.SPISR_OFFSET_ADDR(SPISR_OFFSET_ADDR),
		.SPIDTR_OFFSET_ADDR(SPIDTR_OFFSET_ADDR),
		.SPIDRR_OFFSET_ADDR(SPIDRR_OFFSET_ADDR)
	) CCSDS_tx_ip_v1_0_M00_AXI_inst (
//		.ERROR(m00_axi_error),
//		.RXN_DONE(m00_axi_rxn_done), //Use to check when to post next address
		.M_AXI_ACLK(m00_axi_aclk),
		.M_AXI_ARESETN(m00_axi_aresetn),
		.M_AXI_AWADDR(m00_axi_awaddr),
		.M_AXI_AWPROT(m00_axi_awprot),
		.M_AXI_AWVALID(m00_axi_awvalid),
		.M_AXI_AWREADY(m00_axi_awready),
		.M_AXI_WDATA(m00_axi_wdata),
		.M_AXI_WSTRB(m00_axi_wstrb),
		.M_AXI_WVALID(m00_axi_wvalid),
		.M_AXI_WREADY(m00_axi_wready),
		.M_AXI_BRESP(m00_axi_bresp),
		.M_AXI_BVALID(m00_axi_bvalid),
		.M_AXI_BREADY(m00_axi_bready),
		.M_AXI_ARADDR(m00_axi_araddr),
		.M_AXI_ARPROT(m00_axi_arprot),
		.M_AXI_ARVALID(m00_axi_arvalid),
		.M_AXI_ARREADY(m00_axi_arready),
		.M_AXI_RDATA(m00_axi_rdata),
		.M_AXI_RRESP(m00_axi_rresp),
		.M_AXI_RVALID(m00_axi_rvalid),
		.M_AXI_RREADY(m00_axi_rready),
		.data_o(data_o),
		.fsm_state_o(fsm_state_o),
		.frame_o(frame_o),
		.enable_serializer_o(enable_serializer_o),
		.serializer_busy_i(serializer_done_i),
		.debug_i(debug_i),
		.ccsds_read_in(ccsds_read_in),
		.spi_rx_empty_interrupt_i(spi_rx_empty_interrupt_i),
		.count_debug(count_debug)
	);

	//Instantiation of Axi Bus Interface M00_AXIS for I data
	CCSDS_tx_ip_v1_0_M00_AXIS # ( 
		.C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
	) CCSDS_tx_ip_v1_0_M00_AXIS_inst (
		.M_AXIS_ACLK(m00_axis_aclk),
		.M_AXIS_ARESETN(m00_axis_aresetn),
		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TDATA(m00_axis_tdata),
		.M_AXIS_TSTRB(m00_axis_tstrb),
		.M_AXIS_TLAST(m00_axis_tlast),
		.M_AXIS_TREADY(m00_axis_tready),
		.i_data_i(i_data_i),
		.i_valid_i(i_valid_i)
	);

// TODO: Instantiate the convolutional encoder module

// TODO: Implement framing

// TODO: Implement modulator

	endmodule
