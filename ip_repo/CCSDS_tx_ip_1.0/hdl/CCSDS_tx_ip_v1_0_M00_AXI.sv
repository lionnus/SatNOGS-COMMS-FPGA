/*
* File: CCSDS_tx_ip_v1_0_M00_AXI.v
* Author: Lionnus Kesting
* Date: June 16th, 2023
*
* Description: Control module communicating with the AXI Quad SPI IP Core. Takes in a CADU_WIDTH*8/SPI_WIDTH frame and publishes this on frame_o whilst asserting enable_serializer_o.
*
* License: This file is licensed under the GNU GPL version 3.
*
* Part of a semester project at ETH Zurich and Akademische Raumfahrt Initiative Schweiz (ARIS)
*/
`timescale 1 ns / 1 ps

module CCSDS_tx_ip_v1_0_M00_AXI #
	(
		// Users to add parameters here
		parameter CADU_WIDTH = 20, // Number of bytes in CADU, TF_WIDTH = CADU_WIDTH -4
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
		parameter DGIER_ENABLE = 32'h80000000
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Asserts when ERROR is detected
//		output reg  ERROR,
//		// Asserts when AXI transactions is complete
//		output wire  RXN_DONE,
		// AXI clock signal
		input wire  M_AXI_ACLK,
		// AXI active low reset signal
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address Channel ports. Write address (issued by master)
		output wire [31: 0] M_AXI_AWADDR,
		// Write channel Protection type.
    // This signal indicates the privilege and security level of the transaction,
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Write address valid. 
    // This signal indicates that the master signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data Channel ports. Write data (issued by master)
		output wire [31 : 0] M_AXI_WDATA,
		// Write strobes. 
    // This signal indicates which byte lanes hold valid data.
    // There is one write strobe bit for each eight bits of the write data bus.
		output wire [32/8-1 : 0] M_AXI_WSTRB,
		// Write valid. This signal indicates that valid write data and strobes are available.
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response Channel ports. 
    // This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Write response valid. 
    // This signal indicates that the channel is signaling a valid write response
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address Channel ports. Read address (issued by master)
		output wire [31: 0] M_AXI_ARADDR,
		// Protection type. 
    // This signal indicates the privilege and security level of the transaction, 
    // and whether the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Read address valid. 
    // This signal indicates that the channel is signaling valid read address and control information.
		output wire  M_AXI_ARVALID,
		// Read address ready. 
    // This signal indicates that the slave is ready to accept an address and associated control signals.
		input wire  M_AXI_ARREADY,
		// Master Interface Read Data Channel ports. Read data (issued by slave)
		input wire [31 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer.
		input wire [1 : 0] M_AXI_RRESP,
		// Read valid. This signal indicates that the channel is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can accept the read data and response information.
		output wire  M_AXI_RREADY,
		// Outupt of the serializer module
		output wire data_o,
		// Add some debugging outputs
		output wire [2:0] fsm_state_o,
		output wire [CADU_WIDTH*8-1:0] frame_o,
		output wire enable_serializer_o,
		input wire serializer_busy_i,
		input wire [3:0] debug_i,
		output wire ccsds_read_in,
		input wire spi_rx_empty_interrupt_i,
		output wire count_debug
	);
    
	// function called clogb2 that returns an integer which has the
	// value of the ceiling of the log base 2
	 function integer clogb2 (input integer bit_depth);
		 begin
		 for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
			 bit_depth = bit_depth >> 1;
		 end
	 endfunction

	 

	// Example State machine to initialize counter, initialize write transactions, 
	// initialize read transactions and sending of read data.
// create enum to initialize state variable in systemverilog
	typedef enum logic [2:0] {ENABLE_SPI, ENABLE_INT, ENABLE_INT_GLOB, WAIT_FOR_SPI, SPI_RECEIVE, SPI_CONFIRM, RESET_SPI, SEND_FRAME} state_fsm;
	// state variable
	state_fsm current_state;

	// AXI4LITE signals
	//write address valid
	reg  	axi_awvalid;
	//write data valid
	reg  	axi_wvalid;
	//read address valid
	reg  	axi_arvalid;
	//read data acceptance
	reg  	axi_rready;
	//write response acceptance
	reg  	axi_bready;
	//write address
	reg [31 : 0] 	axi_awaddr;
	//write data
	reg [31 : 0] 	axi_wdata;
	//read addresss
	reg [31 : 0] 	axi_araddr;
	//Asserts when there is a write response error
	wire  	write_resp_error;
	//Asserts when there is a read response error
	wire  	read_resp_error;
	//A pulse to initiate a write transaction
	reg  	start_single_write;
	//A pulse to initiate a read transaction
	reg  	start_single_read;
	//Asserts when a single beat write transaction is issued and remains asserted till the completion of write trasaction.
	reg  	write_issued;
	//Asserts when a single beat read transaction is issued and remains asserted till the completion of read trasaction.
	reg  	read_issued;
	//flag that marks the completion of write trasactions. The number of write transaction is user selected by the reg transaction_num.
	reg  	writes_done;
	//flag that marks the completion of read trasactions. The number of read transaction is user selected by the reg transaction_num.
	reg  	reads_done;
	//The error register is asserted when any of the write response error, read response error or the data mismatch flags are asserted.
	reg  	error_reg;
	//index counter to track the number of write transaction issued
	reg [16 : 0] 	write_index;
	//index counter to track the number of read transaction issued
	reg [16 : 0] 	read_index;
	// //This flag is asserted when there is a mismatch of the read data with the expected read data.
	 reg  	read_mismatch;
	//Flag is asserted when the write index reaches the last write transction number
	reg  	last_write;
	//Flag is asserted when the read index reaches the last read transction number
	reg  	last_read;

	// Registers for FSM
	reg [31: 0] 	fsm_araddr;
	reg [31: 0]	fsm_awaddr;
	// Serializer registers and wires
	reg [CADU_WIDTH*8-1:0] ccsds_tf_reg = 64'hABABABABABABABAB;
	reg [16:0] transaction_num = CADU_WIDTH*8/SPI_WIDTH;
	reg ccsds_data_read = 0; // Register to enable storing of data in the ccsds_tf_reg
	reg [16:0] count_tf = 0; // Register to keep track of how full ccsds_tf_reg is
	//  Define serializer registers and wires
	reg enable_serializer = 0;
	reg enable_serializer_prev = 0;
	reg serializer_busy_prev=0;
	wire serializer_busy_pulse;
	assign serializer_busy_pulse = !serializer_busy_i && serializer_busy_prev;
	assign ccsds_read_in = ccsds_data_read;
	assign count_debug = count_tf;


	// I/O Connections assignments

	//Adding the offset address to the base addr of the slave
	assign M_AXI_AWADDR	= AXI_QUAD_SPI_BASE_ADDR + axi_awaddr;
	//AXI 4 write data
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_AWPROT	= 3'b000;
	assign M_AXI_AWVALID	= axi_awvalid;
	//Write Data(W)
	assign M_AXI_WVALID	= axi_wvalid;
	//Set all byte strobes in this example
	assign M_AXI_WSTRB	= 4'b1111;
	//Write Response (B)
	assign M_AXI_BREADY	= axi_bready;
	//Read Address (AR)
	assign M_AXI_ARADDR	= AXI_QUAD_SPI_BASE_ADDR + axi_araddr;
	assign M_AXI_ARVALID	= axi_arvalid;
	assign M_AXI_ARPROT	= 3'b001;
	//Read and Read Response (R)
	assign M_AXI_RREADY	= axi_rready;
	//Example design I/O
//	assign RXN_DONE	= send_done;
    assign fsm_state_o = current_state;
    assign enable_serializer_o = enable_serializer&&~enable_serializer_prev;
    assign frame_o = ccsds_tf_reg;

	//--------------------
	//Write Address Channel
	//--------------------

	  always @(posedge M_AXI_ACLK)										      
	  begin                                                                        
	    //Only VALID signals must be deasserted during reset per AXI spec          
	    //Consider inverting then registering active-low reset for higher fmax     
	    if (M_AXI_ARESETN == 0 )                                                   
	      begin                                                                    
	        axi_awvalid <= 1'b0;                                                   
	      end                                                                      
	      //Signal a new address/data command is available by user logic           
	    else                                                                       
	      begin                                                                    
	        if (start_single_write)                                                
	          begin                                                                
	            axi_awvalid <= 1'b1;                                               
	          end                                                                  
	     //Address accepted by interconnect/slave (issue of M_AXI_AWREADY by slave)
	        else if (M_AXI_AWREADY && axi_awvalid)                                 
	          begin                                                           
	            axi_awvalid <= 1'b0;                                               
	          end                                                                  
	      end                                                                      
	  end                                                                          
	                                                                               

	//--------------------
	//Write Data Channel
	//--------------------

	//The write data channel is for transfering the actual data.
	//The data generation is speific to the example design, and 
	//so only the WVALID/WREADY handshake is shown here

	   always @(posedge M_AXI_ACLK)                                        
	   begin                                                                         
	     if (M_AXI_ARESETN == 0  )                                                    
	       begin                                                                     
	         axi_wvalid <= 1'b0;    
//	         $display("WVALID deasserted for wrong reason");                                                 
	       end                                                                       
	     //Signal a new address/data command is available by user logic              
	     else if (start_single_write)                                                
	       begin                                                                     
	         axi_wvalid <= 1'b1;                                                     
	       end                                                                       
	     //Data accepted by interconnect/slave (issue of M_AXI_WREADY by slave)      
	     else if (M_AXI_WREADY && axi_wvalid)                                        
	       begin              
//	           $display("WVALID deasserted");                                                       
	        axi_wvalid <= 1'b0;                                                      
	       end                                                                       
	   end                                                                           


	//----------------------------
	//Write Response (B) Channel
	//----------------------------

	  always @(posedge M_AXI_ACLK)                                    
	  begin                                                                
	    if (M_AXI_ARESETN == 0 )                                           
	      begin                                                            
	        axi_bready <= 1'b0;                                            
	      end                                                              
	    // accept/acknowledge bresp with axi_bready by the master          
	    // when M_AXI_BVALID is asserted by slave                          
	    else if (M_AXI_BVALID && ~axi_bready)                              
	      begin                                                            
	        axi_bready <= 1'b1;                                            
	      end                                                              
	    // deassert after one clock cycle                                  
	    else if (axi_bready)                                               
	      begin                                                            
	        axi_bready <= 1'b0;                                            
	      end                                                              
	    // retain the previous value                                       
	    else                                                               
	      axi_bready <= axi_bready;                                        
	  end                                                                  
	                                                                       
	//Flag write errors                                                    
	assign write_resp_error = (axi_bready & M_AXI_BVALID & M_AXI_BRESP[1]);


	//----------------------------
	//Read Address Channel
	//----------------------------                                                                 
	  // A new axi_arvalid is asserted when there is a valid read address              
	  // available by the master. start_single_read triggers a new read                
	  // transaction                                                                   
	  always @(posedge M_AXI_ACLK)                                                     
	  begin                                                                            
	    if (M_AXI_ARESETN == 0 )                                                       
	      begin                                                                        
	        axi_arvalid <= 1'b0;                                                       
	      end                                                                          
	    //Signal a new read address command is available by user logic                 
	    else if (start_single_read)                                                    
	      begin                                                                        
	        axi_arvalid <= 1'b1;                                                       
	      end                                                                          
	    //RAddress accepted by interconnect/slave (issue of M_AXI_ARREADY by slave)    
	    else if (M_AXI_ARREADY && axi_arvalid)                                         
	      begin                                                                        
	        axi_arvalid <= 1'b0;                                                       
	      end                                                                          
	    // retain the previous value                                                   
	  end                                                                              

	//--------------------------------
	//Read Data (and Response) Channel
	//--------------------------------

	//The Read Data channel returns the results of the read request 
	//The master will accept the read data by asserting axi_rready
	//when there is a valid read data available.
	//While not necessary per spec, it is advisable to reset READY signals in
	//case of differing reset latencies between master/slave.

	  always @(posedge M_AXI_ACLK)                                    
	  begin                                                                 
	    if (M_AXI_ARESETN == 0 )                                            
	      begin                                                             
	        axi_rready <= 1'b0;                                             
	      end                                                               
	    // accept/acknowledge rdata/rresp with axi_rready by the master     
	    // when M_AXI_RVALID is asserted by slave                           
	    else if (M_AXI_RVALID && ~axi_rready)                               
	      begin                                                             
	        axi_rready <= 1'b1;                                          
	      end                                                               
	    // deassert after one clock cycle                                   
	    else if (axi_rready)                                                
	      begin                                                             
	        axi_rready <= 1'b0;                                             
	      end                                                               
	    // retain the previous value                                        
	  end                                                                   
	                                                                        
	//Flag write errors                                                     
	assign read_resp_error = (axi_rready & M_AXI_RVALID & M_AXI_RRESP[1]);  


	//--------------------------------
	//User Logic
	//--------------------------------
          
	  //implement master command interface state machine                         
	  always @ ( posedge M_AXI_ACLK)                                                    
	  begin       
	  serializer_busy_prev <= serializer_busy_i;  
	  enable_serializer_prev  <= enable_serializer;                                                                    
	    if (M_AXI_ARESETN == 1'b0)                                                     
	      begin                                                                         
	      // reset condition                                                            
	      // All the signals are assigned default values under reset condition      
	        current_state  <= ENABLE_SPI;   
			transaction_num <= 1;                                         
	        start_single_write <= 1'b0;                                                 
	        write_issued  <= 1'b0;   
			write_index <= 0;                                                   
	        start_single_read  <= 1'b0;   
			read_index <= 0;                                              
	        read_issued   <= 1'b0;                                                      
//	        send_done  <= 1'b0;                                                      
//	        ERROR <= 1'b0;
			axi_araddr <= 0;
			axi_awaddr <= 0;
			ccsds_data_read <= 0;
			count_tf <= 0;
			serializer_busy_prev <= 0;
			enable_serializer_prev <= 0;
			enable_serializer <= 0;
	      end                                                                           
	    else                                                                            
	      begin                                                                         
	       // state transition                                                          
	        case (current_state)                                                       
	          ENABLE_SPI: 
			  // Sets the SPI Enable bit of the AXI QUAD SPI IP 
			  // SPI Enable bit is bit 1 of the SPICR register
			  if (writes_done)                                                        
	              begin                                                                 
	                current_state <= ENABLE_INT;                                   
	              end                                                                                                   
	            else                                                                    
	              begin                                                                 
	                current_state  <= ENABLE_SPI;      
//	                $display(" INFO DUT: ENABLE_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID, ~start_single_write, ~write_issued);                                                                 
	                  if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued)
	                    begin          
//	                    $display(" INFO DUT: Writing SPI ENABLE");
	                      start_single_write <= 1'b1;                                   
	                      write_issued  <= 1'b1;     
						  transaction_num <= 1;
						  axi_awaddr <= SPICR_OFFSET_ADDR;
						  axi_wdata <=  SPICR_ENABLE;                              
	                    end                                                             
	                  else if (axi_bready)                                        
	                    begin                                                           
	                      write_issued  <= 1'b0;                                        
	                    end                                                             
	                  else                                                              
	                    begin                                                           
	                      start_single_write <= 1'b0; //Negate to generate a pulse      
	                    end                                                             
	              end      
	              ENABLE_INT: 
			  // Sets the SPI Enable bit of the AXI QUAD SPI IP 
			  // SPI Enable bit is bit 1 of the SPICR register
			  if (writes_done)                                                        
	              begin                                                                 
	                current_state <= ENABLE_INT_GLOB;                                        
	              end                                                                                                   
	            else                                                                    
	              begin                                                                 
	                current_state  <= ENABLE_INT;      
//	                $display(" INFO DUT: ENABLE_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID, ~start_single_write, ~write_issued);                                                                 
	                  if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued)
	                    begin          
//	                    $display(" INFO DUT: WrIting SPI ENABLE");
	                      start_single_write <= 1'b1;                                   
	                      write_issued  <= 1'b1;     
						  transaction_num <= 1;
						  axi_awaddr <= IPIER_OFFSET_ADDR;
						  axi_wdata <=  IPIER_DDR_NOT_EMPTY;                              
	                    end                                                             
	                  else if (axi_bready)                                        
	                    begin                                                           
	                      write_issued  <= 1'b0;                                        
	                    end                                                             
	                  else                                                              
	                    begin                                                           
	                      start_single_write <= 1'b0; //Negate to generate a pulse      
	                    end                                                             
	              end     
	              ENABLE_INT_GLOB: 
			  // Sets the SPI Enable bit of the AXI QUAD SPI IP 
			  // SPI Enable bit is bit 1 of the SPICR register
			  if (writes_done)                                                        
	              begin                                                                 
	                current_state <= SPI_CONFIRM;    
	                axi_wdata <=  SPI_RESPONSE_START;                                        
	              end                                                                                                   
	            else                                                                    
	              begin                                                                 
	                current_state  <= ENABLE_INT_GLOB;      
//	                $display(" INFO DUT: ENABLE_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID, ~start_single_write, ~write_issued);                                                                 
	                  if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued )
	                    begin          
//	                    $display(" INFO DUT: WrIting SPI ENABLE");
	                      start_single_write <= 1'b1;                                   
	                      write_issued  <= 1'b1;     
						  transaction_num <= 1;
						  axi_awaddr <= DGIER_OFFSET_ADDR;
						  axi_wdata <=  DGIER_ENABLE;                              
	                    end                                                             
	                  else if (axi_bready)                                        
	                    begin                                                           
	                      write_issued  <= 1'b0;                                        
	                    end                                                             
	                  else                                                              
	                    begin                                                           
	                      start_single_write <= 1'b0; //Negate to generate a pulse      
	                    end                                                             
	              end                                                             
	          WAIT_FOR_SPI:                                                             
	          // This state is responsible to initiate 
	          // AXI transaction when rx_empty bit in SPI SR is set
				if (reads_done)                                                        
					begin           
//	                $display(" INFO DUT: Reads_done and last_read deasserted");       
					if (M_AXI_RDATA[0]==0) begin     //m00_axi_rdata[0] is the rx_empty bit of the SPI SR register                                             
							current_state <= SPI_RECEIVE;        
//							$display("   INFO DUT: rx_empty==0, so new data available");
					end else begin
						current_state <= WAIT_FOR_SPI;  
//						$display("   INFO DUT: rx_empty==1, will read SPI SR again.");
					end                            
					end                                                                  
				else                                                                   
				begin                                                                
					current_state  <= WAIT_FOR_SPI;      
//					$display(" INFO DUT: WAIT_FOR_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID,  ~start_single_write, ~write_issued);                                                                             												
					if (~axi_arvalid && ~M_AXI_RVALID && ~start_single_read && ~read_issued)
					begin                                                            
						start_single_read <= 1'b1;
						ccsds_data_read <= 0;
						transaction_num <= 1;
						axi_araddr <= SPISR_OFFSET_ADDR;                                  
						read_issued  <= 1'b1;                                      
					end                                                              
					else if (axi_rready)                                               
					begin                                                            
						read_issued  <= 1'b0;                                          
					end                                                              
					else                                                               
					begin                                                            
						start_single_read <= 1'b0; //Negate to generate a pulse        
					end                                                              
				end
                                                                                                                                                                                                                                                                                                                                                                             
	          SPI_RECEIVE:                                                                
			  // This state is responsible to initiate 
	          // AXI transaction to read out SPIDRR till the last
				if (reads_done)                                                        
					begin              
					if (count_tf<transaction_num) begin                                           
							current_state <= WAIT_FOR_SPI;        
//							$display("   INFO DUT: CCSDS TF not full yet, back to WAIT_FOR_SPI");
					end else begin
						current_state <= SEND_FRAME;  
						ccsds_data_read <= 0;
						count_tf <= 0;
//						$display("   INFO DUT: CCSDS TF is full, forward to SEND_FRAME.");
					end                            
					end                                                                  
				else                                                                   
				begin                                                                
					current_state  <= SPI_RECEIVE;      
//					$display(" INFO DUT: WAIT_FOR_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID,  ~start_single_write, ~write_issued);                                                                             												
					if (~axi_arvalid && ~M_AXI_RVALID && ~start_single_read && ~read_issued)
					begin                                                            
						start_single_read <= 1'b1;
						count_tf = count_tf + 1;
						ccsds_data_read <= 1;
						
						transaction_num <= CADU_WIDTH*8/SPI_WIDTH;
						axi_araddr <= SPIDRR_OFFSET_ADDR;                                  
						read_issued  <= 1'b1;                                      
					end                                                              
					else if (axi_rready)                                               
					begin                                                            
						read_issued  <= 1'b0;                                          
					end                                                              
					else                                                               
					begin                                                            
						start_single_read <= 1'b0; //Negate to generate a pulse        
					end                                                              
				end    
				                                                             
	           SEND_FRAME:                                                         
	             begin    
	                 if (serializer_busy_pulse) begin
							current_state <= RESET_SPI;
							enable_serializer<= 0;
						end    
						else if (!enable_serializer) begin
						  enable_serializer <= 1;
						end else begin
							current_state <= SEND_FRAME;
						end                                   
	             end                                                                   
				
				SPI_CONFIRM:                                                               
	            // This state is responsible to issue start_single_write pulse to       
	            // initiate a write transaction. Write transactions will be             
	            // issued until last_write signal is asserted.                          
	            // write controller   
				if (writes_done)                                                        
	              begin                                                                 
	                current_state <= WAIT_FOR_SPI;          
	              end                                                                   
	            else                                                                    
	              begin                                                                 
	                current_state  <= SPI_CONFIRM;                                                                       
	                  if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued)
	                    begin                                                           
	                      start_single_write <= 1'b1;                                   
	                      write_issued  <= 1'b1;     
						  axi_awaddr <= SPIDTR_OFFSET_ADDR;                                
	                    end                                                             
	                  else if (axi_bready)                                              
	                    begin                                                           
	                      write_issued  <= 1'b0;                                        
	                    end                                                             
	                  else                                                              
	                    begin                                                           
	                      start_single_write <= 1'b0; //Negate to generate a pulse      
	                    end                                                             
	              end     
	               RESET_SPI: 
			  // Sets the SPI Enable bit of the AXI QUAD SPI IP 
			  // SPI Enable bit is bit 1 of the SPICR register
			  if (writes_done)                                                        
	              begin                                                                 
	                current_state <= SPI_CONFIRM;    
	                axi_wdata <=  SPI_RESPONSE_RST;                                        
	              end                                                                                                   
	            else                                                                    
	              begin                                                                 
	                current_state  <= RESET_SPI;      
//	                $display(" INFO DUT: ENABLE_SPI signals: %d, %d, %d, %d, %d",~axi_awvalid, ~axi_wvalid, ~M_AXI_BVALID, ~start_single_write, ~write_issued);                                                                 
	                  if (~axi_awvalid && ~axi_wvalid && ~M_AXI_BVALID && ~start_single_write && ~write_issued )
	                    begin          
//	                    $display(" INFO DUT: WrIting SPI ENABLE");
	                      start_single_write <= 1'b1;                                   
	                      write_issued  <= 1'b1;     
						  transaction_num <= 1;
						  axi_awaddr <= SPICR_OFFSET_ADDR;
						  axi_wdata <=  SPICR_FIFO_RESET;                              
	                    end                                                             
	                  else if (axi_bready)                                        
	                    begin                                                           
	                      write_issued  <= 1'b0;                                        
	                    end                                                             
	                  else                                                              
	                    begin                                                           
	                      start_single_write <= 1'b0; //Negate to generate a pulse      
	                    end                                                             
	              end                                                             
	             default:                                                                
	             begin                                                                  
	               current_state  <= ENABLE_SPI;                                     
	             end                                                           
	                                                                                         
	        endcase                                                                     
	    end                                                                             
	  end //FSM                                                  
	                                                              
	                                                                                    
	  always @(posedge M_AXI_ACLK)                                                      
	  begin                                                                             
	    if (M_AXI_ARESETN == 0 )                                                         
	      writes_done <= 1'b0;                                                          
	                                                                                    
	      //The writes_done should be associated with a bready response                 
	    else if (M_AXI_BVALID && axi_bready)  begin
//	       $display(" INFO DUT: writes_done always block, asserting writes_done");                            
	      writes_done <= 1'b1;       
	      end                                                   
	    else                                                                            
	      writes_done <= 0;                                                   
	  end                                                                                                                               
	/*                                                                                  
	 Check for last read completion.                                                    
	                                                                                    
	 This logic is to qualify the last read count with the final read                   
	 response/data.                                                                     
	 */                                                                                 
	  always @(posedge M_AXI_ACLK)                                                      
	  begin                                                                             
	    if (M_AXI_ARESETN == 0 )                                                         
	      reads_done <= 1'b0;                                                           
	                                                                                    
	    //The reads_done should be associated with a read ready response                
	    else if (M_AXI_RVALID && axi_rready)                               
	      reads_done <= 1'b1;                                                           
	    else                                                                            
	      reads_done <= 0;                                                     
	    end                                                                             
                                                                               
	//Store data                                                                  
	  always @(posedge M_AXI_ACLK)                                                      
	  begin                                                                             
	    if (M_AXI_ARESETN == 0  ) begin                                                        
	       read_mismatch <= 1'b0;       
	       ccsds_tf_reg <= 0;    
	    end                                                                                                                
	    //The read data when available (on axi_rready) is stored in the CCSDS TF Register 
	    else if ((M_AXI_RVALID && axi_rready && ccsds_data_read)) begin
			ccsds_tf_reg[CADU_WIDTH*8-SPI_WIDTH*(count_tf-1)-1 -: SPI_WIDTH] <= M_AXI_RDATA;
			$display("       INFO: ccsds_tf_reg index: %d",(CADU_WIDTH*8-SPI_WIDTH*(count_tf-1)-1));
	       read_mismatch <= 1'b1;      
	      end                                                  
	    else                                                                            
	      read_mismatch <= read_mismatch;                                               
	  end                                                                               
	                                                                                    
	// Register and hold any read/write interface errors            
	  always @(posedge M_AXI_ACLK)                                                      
	  begin                                                                             
	    if (M_AXI_ARESETN == 0  )                                                         
	      error_reg <= 1'b0;                                                            
	                                                                                    
	    //Capture any error types                                       
		else if (write_resp_error || read_resp_error)
	      error_reg <= 1'b1;                                                            
	    else                                                                            
	      error_reg <= error_reg;                                                       
	  end                                                                               

	// User logic ends

	endmodule
