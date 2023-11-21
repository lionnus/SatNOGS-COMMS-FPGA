`timescale 1ns/1ps

module CCSDS_tx_ip_v1_0_tb;
  // Parameters for testbench
  parameter APPL_DEL = 0.05;

  // Parameters
  parameter CADU_WIDTH = 2; //Number of bytes in CADU
  parameter SPI_WIDTH = 8;
  // The master will start generating data from the value
    // The master will start generating data from the value
    parameter  SPI_RESPONSE_OKAY	= 32'h34;
    parameter  SPI_RESPONSE_START	= 32'h69;
    parameter  SPI_RESPONSE_FAIL	= 32'h46; //Currently not implemented
    parameter  SPI_RESPONSE_RST   	= 32'h22;
    // The master requires a target slave base address.
    // The master will initiate read and write transactions on the slave with base address specified here as a parameter.
    parameter AXI_QUAD_SPI_BASE_ADDR = 32'h44A00000;
    parameter SPICR_OFFSET_ADDR = 32'h60; // SPI Control Register
    parameter SPISR_OFFSET_ADDR = 32'h64; // SPI Status Register
    parameter IPIER_OFFSET_ADDR = 32'h28; // SPI IP Interrupt Enable Register
    parameter DGIER_OFFSET_ADDR = 32'h1C; // SPI Global Interrupt Enable
    parameter SPIDTR_OFFSET_ADDR = 32'h68; // SPI Data Transmit Register
    parameter SPIDRR_OFFSET_ADDR = 32'h6C; // SPI Data Receive Register
    // Values for SPI Control Register
    parameter SPICR_ENABLE = 32'h182; // SPI Enable
    parameter SPICR_DISABLE = 32'h180; // SPI Disable
    parameter SPICR_FIFO_RESET = 32'h1E2; // SPI Enable and TX and RX FIFO Reset
    parameter IPIER_DDR_NOT_EMPTY = 32'b100000000;
    parameter DGIER_ENABLE = 32'h80000000;

  // Inputs
  reg m00_axi_aclk=0;
  reg m00_axi_aresetn=0;
  wire [32-1:0] m00_axi_awaddr;
  wire [2:0] m00_axi_awprot;
  wire m00_axi_awvalid;
  reg m00_axi_awready=0;
  wire [32-1:0] m00_axi_wdata;
  wire [32/8-1:0] m00_axi_wstrb;
  wire m00_axi_wvalid;
  reg m00_axi_wready=0;
  reg [1:0] m00_axi_bresp=0;
  reg m00_axi_bvalid=0;
  wire m00_axi_bready;
  wire [32-1:0] m00_axi_araddr;
  wire[2:0] m00_axi_arprot;
  wire m00_axi_arvalid;
  reg m00_axi_arready=0;
  reg [32-1:0] m00_axi_rdata=0;
  reg [1:0] m00_axi_rresp=0;
  reg m00_axi_rvalid=0;
  wire m00_axi_rready;
  reg [3:0] debug_i =1;
  reg serializer_done_i=0;

  // Outputs
  wire data_o;
  wire [2:0] fsm_state_o;
  wire [CADU_WIDTH*8-1:0] frame;
  wire data_valid;
  
  // Testbench variables
  reg [31:0] data_acq;
  reg [31:0] data_exp;

  // Set parameter for FSM states
  parameter [2:0]   ENABLE_SPI  = 3'b000, 
                    ENABLE_INT  = 3'b001,
                    ENABLE_INT_GLOB=3'b010,
                    WAIT_FOR_SPI= 3'b011,
                    SPI_RECEIVE = 3'b100, 
                    SPI_CONFIRM = 3'b101, 
                    RESET_SPI   = 3'b110,
                    SEND_FRAME  = 3'b111;
  //Define tasks
  // Function to respond to read register request of AXI4-Lite Master
  // Respond to read request of address, and respond with the data
  task respond_read_axi4_lite_reg (input [31:0] address, input [31:0] data);
  begin
        //Assert ARReady to indicate that the address can be accepted
        #(APPL_DEL);
        m00_axi_arready=1;
        //Wait till ARVALID asserted
        // @(posedge m00_axi_arvalid);
        //Check if address is correct
        if (m00_axi_araddr == address) begin
            $display("      PASS: Responding to read request of address %x", address);
        end else $display("FAIL: Incorrect address %x, but continuing.", m00_axi_araddr);
        //Wait till next clock
        @(negedge m00_axi_arvalid);
        #(APPL_DEL);
        m00_axi_arready=0;
        @(posedge m00_axi_aclk);
        #(APPL_DEL);
        #2;
        //Put data and assert RVALID to indicate that the data is valid
        m00_axi_rdata <= data;
        m00_axi_rvalid <= 1;
        #1;
        // //Check if RREADY is asserted
        // if (m00_axi_rready) begin
        //     $display("      PASS: RREADY correctly asserted");
        // end else $display("FAIL: RREADY not asserted, but continuing");
        //Assign okay response to RRESP
        m00_axi_rresp <= 0;
        //Deassert RVALID
        @(negedge m00_axi_rready);
        #(APPL_DEL);
        m00_axi_rvalid <= 0;
        @(posedge m00_axi_aclk);
        end
    endtask

    task respond_write_axi4_lite_reg (input [31:0] address, input [31:0] data_exp);
    begin
        //Assert AWReady to indicate that the address has been accepted
        #4;
        #(APPL_DEL);
        m00_axi_awready=1;
        #1 //One cycle for the handshake
        m00_axi_awready=0;
        //Check if address is correct
        if (m00_axi_awaddr == address) begin
        $display("      PASS: Responding to read request of address %x", address);
        end else $display("FAIL: Incorrect address: %x, instead of: %x, but continuing.", m00_axi_awaddr, address);
        @(posedge m00_axi_aclk);
        #(APPL_DEL);
        //Check if WVALID is asserted
        if (m00_axi_wvalid) begin
            $display("      PASS: WREADY correctly asserted");
        end else $display("FAIL: WREADY not asserted, but continuing");
        //Put data and assert WVALID to indicate that the data is valid
        if (m00_axi_wdata == data_exp) begin
            $display("      PASS: Data written as expected, %x", data_exp);
        end else $display("FAIL: Data not as expected, got %x, got %x, but continuing.", m00_axi_wdata, data_exp);
        #1;
        m00_axi_wready <= 1;
        @(negedge m00_axi_wvalid);
        #(APPL_DEL);
        m00_axi_wready <= 0;
        @(posedge m00_axi_aclk);
        #(APPL_DEL);
        //Assign okay response to BRESP
        //Check if BREADY is asserted
        m00_axi_bvalid <= 1;
        m00_axi_bresp <= 2'b00;
        #1;
        if (m00_axi_bready) begin
            $display("      PASS: BREADY correctly asserted");
        end else $display("FAIL: BREADY not asserted, but continuing");
        @(negedge m00_axi_bready);
        #(APPL_DEL);
        m00_axi_bvalid <= 0;
        @(posedge m00_axi_aclk);
        end
    endtask

  // Instantiate the module
  CCSDS_tx_ip_v1_0 #
  (
    .CADU_WIDTH(CADU_WIDTH),
    .SPI_WIDTH(SPI_WIDTH)
  )
  dut
  (
    .fsm_state_o(fsm_state_o),
    .m00_axi_aclk(m00_axi_aclk),
    .m00_axi_aresetn(m00_axi_aresetn),
    .m00_axi_awaddr(m00_axi_awaddr),
    .m00_axi_awprot(m00_axi_awprot),
    .m00_axi_awvalid(m00_axi_awvalid),
    .m00_axi_awready(m00_axi_awready),
    .m00_axi_wdata(m00_axi_wdata),
    .m00_axi_wstrb(m00_axi_wstrb),
    .m00_axi_wvalid(m00_axi_wvalid),
    .m00_axi_wready(m00_axi_wready),
    .m00_axi_bresp(m00_axi_bresp),
    .m00_axi_bvalid(m00_axi_bvalid),
    .m00_axi_bready(m00_axi_bready),
    .m00_axi_araddr(m00_axi_araddr),
    .m00_axi_arprot(m00_axi_arprot),
    .m00_axi_arvalid(m00_axi_arvalid),
    .m00_axi_arready(m00_axi_arready),
    .m00_axi_rdata(m00_axi_rdata),
    .m00_axi_rresp(m00_axi_rresp),
    .m00_axi_rvalid(m00_axi_rvalid),
    .m00_axi_rready(m00_axi_rready),
    .serializer_done_i(serializer_done_i),
    .debug_i(debug_i),
//    .data_o(data_o),
//    .data_valid_o(data_valid),
    .frame_o(frame)
  );

  // Clock generation
  always begin
    #0.5 m00_axi_aclk = ~m00_axi_aclk;
  end

  // Stimulus
  initial begin
    // Initialize inputs
    m00_axi_aresetn = 0;
    #15 m00_axi_aresetn = 1;

    // Wait for the reset to complete
    @(posedge m00_axi_aclk);
    @(posedge m00_axi_aclk);
    @(posedge m00_axi_aclk);
    #(APPL_DEL);
    // Test 1: check if SPI Enable bit (bit 1 of SPICR) is set to 1
    $display("      INFO: Starting AXI4-Lite response to SPI Enable write.");
    respond_write_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPICR_OFFSET_ADDR, 32'h182);
    $display("      INFO: AXI4-Lite signaled SPI Enabled");
    #5;
    #(APPL_DEL);
    // Test 2; Check if interrupt is set correctly
    $display("      INFO: Starting AXI4-Lite response to SPI Enable write.");
    respond_write_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+IPIER_OFFSET_ADDR, IPIER_DDR_NOT_EMPTY);
    $display("      INFO: AXI4-Lite signaled SPI Enabled");
    #5;
    #(APPL_DEL);
    // Test 3: Check if global interrupt is set correctly
    $display("      INFO: Starting AXI4-Lite response to SPI Enable write.");
    respond_write_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+DGIER_OFFSET_ADDR, DGIER_ENABLE);
    $display("      INFO: AXI4-Lite signaled SPI Enabled");
    #5;
    #(APPL_DEL);
    // Test 4; Check if SPI Confirm is set correctly
    $display("      INFO: Starting AXI4-Lite response to SPI Enable write.");
    respond_write_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPIDTR_OFFSET_ADDR, SPI_RESPONSE_START);
    $display("      INFO: AXI4-Lite signaled SPI Enabled");
    #5;
    #(APPL_DEL);
    // Test 2: Check if SPI Status Register (SPISR) is correctly read-out, and if correctly acted upon when EMPTY
    $display("      INFO: Starting AXI4-Lite response to SPI Status register readout 1/2.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPISR_OFFSET_ADDR, 32'h1); // State register should have bit 0 as 1 to signal rx_empty==1, so SPI_CR==32'h1
    $display("      INFO: AXI4-Lite signaled SPISR[1]==1");
     if(fsm_state_o == WAIT_FOR_SPI) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, WAIT_FOR_SPI);
    #5;
    #(APPL_DEL);
    $display("      INFO: Starting AXI4-Lite response to SPI Status register readout 2/3.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPISR_OFFSET_ADDR, 32'h1); // State register should have bit 0 as 1 to signal rx_empty==1, so SPI_CR==32'h1
    $display("      INFO: AXI4-Lite signaled SPISR[1]==1");
     if(fsm_state_o == WAIT_FOR_SPI) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, WAIT_FOR_SPI);
    #5;
    #(APPL_DEL);

    // Test 3: Check if SPI Status Register (SPISR) is correctly read-out, and if correctly acted upon when NON-EMPTY
    $display("      INFO: Starting AXI4-Lite response to SPI Status register readout 3/3.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPISR_OFFSET_ADDR, 32'h0); // State register should have bit 1 as 0, so SPI_CR==32'h0
    $display("      INFO: AXI4-Lite signaled SPISR[1]==0");
     if(fsm_state_o == SPI_RECEIVE) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, SPI_RECEIVE);
    #5;
    #(APPL_DEL);
    // Test 4: Check if SPI Data Receive Register is correctly read out
    data_exp=64'h4F004F00;
    $display("      INFO: Starting AXI4-Lite response to SPI Data Receive register readout 1/2.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPIDRR_OFFSET_ADDR, 8'h4F); // State register should have bit 1 as 0, so SPI_CR==32'h0
    $display("      INFO: Read SPIDDR[31:0]==32'h4F4B4159");
     if(fsm_state_o == WAIT_FOR_SPI) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, WAIT_FOR_SPI);
    #5;
    #(APPL_DEL);
    $display("      INFO: Starting AXI4-Lite response to SPI Status register readout 3/3.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPISR_OFFSET_ADDR, 8'h0); // State register should have bit 1 as 0, so SPI_CR==32'h0
    $display("      INFO: AXI4-Lite signaled SPISR[1]==0");
     if(fsm_state_o == SPI_RECEIVE) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, WAIT_FOR_SPI);
    #5;
    #(APPL_DEL);
    $display("      INFO: Starting AXI4-Lite response to SPI Data Receive register readout 2/2.");
    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPIDRR_OFFSET_ADDR, 8'h4F); // State register should have bit 1 as 0, so SPI_CR==32'h0
    $display("      INFO: Read SPIDDR[31:0]==32'h4F4B4151");
     if(fsm_state_o == SPI_RECEIVE) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, SPI_RECEIVE);
    #5;
    #(APPL_DEL);
    
    // Test 5: Test if bits are correctly transmitted
    serializer_done_i =1;
     #32;
     serializer_done_i = 0;
     if(frame==data_exp) begin
        $display("      PASS: Output data to serializer is correct");
    end else $display("FAIL: Output data to serializer is incorrect, got %x, expected %x", frame, data_exp);

    // Test 6: Check if SPI Data Transmit Register is correctly written
   respond_write_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPIDTR_OFFSET_ADDR, SPI_RESPONSE_OKAY);
 
    // Test 7: Check if it correctly went back to WAIT_FOR_SPI state after transmission
     if(fsm_state_o == WAIT_FOR_SPI) begin
        $display("      PASS: FSM state is correct");
    end else $display("FAIL: FSM state is incorrect, got %b, expected %b", fsm_state_o, WAIT_FOR_SPI);
    #1;
//    $display("Starting AXI4-Lite read.");
//    respond_read_axi4_lite_reg(AXI_QUAD_SPI_BASE_ADDR+SPICR_OFFSET_ADDR, data_acq);
//    $display("AXI4-Lite read complete, output bits: %b", data_o);
    

    // Wait for simulation to complete
    #64;
    $display("INFO: Finishing simulation");
    $finish;
  end

endmodule
