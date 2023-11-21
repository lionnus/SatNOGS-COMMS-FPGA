create_bd_design "ccsds_tx_bd"
update_compile_order -fileset sources_1
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {spi ( Arduino SPI CNN1 ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_quad_spi_0/SPI_0]
add_files -scan_for_includes {../../ip_repo/CCSDS_serial_tx_ip_1.0/example_designs/bfm_design/CCSDS_serial_tx_ip_v1_0_tb.sv ../../ip_repo/CCSDS_serial_tx_ip_1.0/hdl/CCSDS_serial_tx_ip_v1_0_M00_AXI.v ../../ip_repo/CCSDS_serial_tx_ip_1.0/hdl/CCSDS_serial_tx_ip_v1_0.v}
update_compile_order -fileset sources_1
update_compile_order -fileset sources_1
create_bd_cell -type module -reference CCSDS_serial_tx_ip_v1_0 CCSDS_serial_tx_ip_v_0
connect_bd_intf_net [get_bd_intf_pins axi_quad_spi_0/AXI_LITE] [get_bd_intf_pins CCSDS_serial_tx_ip_v_0/m00_axi]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {New Clocking Wizard} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins axi_quad_spi_0/ext_spi_clk]
startgroup
set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {137.5} CONFIG.MMCM_DIVCLK_DIVIDE {4} CONFIG.MMCM_CLKFBOUT_MULT_F {39.875} CONFIG.MMCM_CLKOUT0_DIVIDE_F {7.250} CONFIG.CLKOUT1_JITTER {203.581} CONFIG.CLKOUT1_PHASE_ERROR {233.925}] [get_bd_cells clk_wiz]
endgroup
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {New Clocking Wizard} Freq {100} Ref_Clk0 {None} Ref_Clk1 {None} Ref_Clk2 {None}}  [get_bd_pins CCSDS_serial_tx_ip_v_0/m00_axi_aclk]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {sys_clock ( System Clock ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins clk_wiz/clk_in1]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins clk_wiz/reset]
endgroup
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {/reset_rtl (ACTIVE_LOW)}}  [get_bd_pins clk_wiz_1/reset]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {/reset_rtl (ACTIVE_LOW)}}  [get_bd_pins rst_clk_wiz_1_100M/ext_reset_in]
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {sys_clock ( System Clock ) } Manual_Source {Auto}}  [get_bd_pins clk_wiz_1/clk_in1]
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0
endgroup
set_property -dict [list CONFIG.C_NUM_OF_PROBES {19} CONFIG.C_SLOT_0_AXI_PROTOCOL {AXI4LITE}] [get_bd_cells ila_0]
connect_bd_net [get_bd_ports clk_wiz_1/clk_out1] [get_bd_pins ila_0/clk]
connect_bd_intf_net [get_bd_intf_pins ila_0/SLOT_0_AXI] [get_bd_intf_pins CCSDS_serial_tx_ip_v_0/m00_axi]

# Fix reset of clock wizard modules
startgroup
set_property -dict [list CONFIG.RESET_TYPE {ACTIVE_LOW} CONFIG.RESET_PORT {resetn}] [get_bd_cells clk_wiz_1] 
endgroup
startgroup
set_property -dict [list CONFIG.RESET_TYPE {ACTIVE_LOW} CONFIG.RESET_PORT {resetn}] [get_bd_cells clk_wiz]
connect_bd_net [get_bd_ports reset_rtl] [get_bd_pins clk_wiz_1/resetn]
connect_bd_net [get_bd_ports reset_rtl] [get_bd_pins clk_wiz/resetn]
# Make wrapper for bd
make_wrapper -files [get_files /CCSDS_tx_chain.srcs/sources_1/bd/ccsds_tx_bd/ccsds_tx_bd.bd] -top
add_files -norecurse /CCSDS_tx_chain.gen/sources_1/bd/ccsds_tx_bd/hdl/ccsds_tx_bd_wrapper.v
update_compile_order -fileset sources_1
