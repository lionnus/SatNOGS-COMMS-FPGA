# Check vivado version
if {[version -short] ne "2020.2"} {
    error "ERROR: This project requires Vivado 2020.2!"
}

# Name of project
set project_name CCSDS_tx_chain

# Create new project.
create_project $project_name . -part xc7z020clg400-1
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
set_property platform.board_id pynq-z2 [current_project]
set_property target_language Verilog [current_project]

# Add synthesis source and constraint files.
add_files -scan_for_includes [glob ../sourcecode/*.sv]
add_files -fileset constrs_1 -norecurse ./constraints/pynq_z2.xdc
update_compile_order -fileset sources_1

# Add simulation source files.
set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse -scan_for_includes ../sourcecode/tb/${project_name}_tb.sv
update_compile_order -fileset sim_1

# Define default simulation run time.
set_property -name {xsim.simulate.runtime} -value {5us} -objects [get_filesets sim_1]
