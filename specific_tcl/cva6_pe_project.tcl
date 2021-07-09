  # constants
  global DMEM_BASE
  global DMEM_LENGTH
  global IMEM_BASE
  global IMEM_LENGTH
  global DEBUG_BASE
  global DEBUG_LENGTH

  set DEBUG_BASE 0x00000000
  set DEBUG_LENGTH 0x0000000000001000
  set IMEM_BASE	0x0000000000001000
  set IMEM_LENGTH	$lmem
  set DMEM_BASE	$IMEM_LENGTH
  set DMEM_LENGTH	$lmem

  # Create instance: cva6_0, and set properties
  set cva6_0 [ create_bd_cell -type ip -vlnv [dict get $cpu_vlnv $project_name] cva6_0 ]
  set cpu_clk [get_bd_pins cva6_0/clk]

  # Create interface connections
  #TODO this core has a single axi interface for both memories and peripherals
  set cva6_mem_splitter [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 cva6_mem_splitter ]
  set_property CONFIG.NUM_MI 2 [get_bd_cells /cva6_mem_splitter]
  set_property CONFIG.NUM_SI 1 [get_bd_cells /cva6_mem_splitter]

  # Axi masters
  connect_bd_intf_net [get_bd_intf_pins cva6_0/io_axi_mem] -boundary_type upper [get_bd_intf_pins cva6_mem_splitter/S00_AXI]

  # Axi slaves
  connect_bd_intf_net -boundary_type upper [get_bd_intf_pins cva6_mem_splitter/M01_AXI] [get_bd_intf_pins axi_mem_intercon_1/S00_AXI]
  # Connect clocks
  connect_bd_net [get_bd_ports CLK] [get_bd_pins cva6_mem_splitter/ACLK] [get_bd_pins cva6_mem_splitter/S00_ACLK] [get_bd_pins cva6_mem_splitter/M00_ACLK] [get_bd_pins cva6_mem_splitter/M01_ACLK]
  connect_bd_net [get_bd_pins rst_CLK_100M/interconnect_aresetn] [get_bd_pins cva6_mem_splitter/ARESETN]
  connect_bd_net [get_bd_pins rst_CLK_100M/peripheral_aresetn] [get_bd_pins cva6_mem_splitter/S00_ARESETN] [get_bd_pins cva6_mem_splitter/M00_ARESETN] [get_bd_pins cva6_mem_splitter/M01_ARESETN]

  # imem connection is done via the iaxi variable
  set iaxi [get_bd_intf_pins cva6_mem_splitter/M00_AXI]
  # This port is used to determine the address and data widths
  set axi_mem_port [get_bd_intf_pins cva6_0/io_axi_mem]

  # Create port connections
  connect_bd_net [get_bd_pins RVController_0/rv_rstn] [get_bd_pins cva6_0/rst_n]

  set boot_addr_constant [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 boot_addr_constant]
  set mhartid_constant [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 mhartid_constant]

  set_property -dict [list CONFIG.CONST_WIDTH {64}] [get_bd_cells boot_addr_constant]
  set_property -dict [list CONFIG.CONST_VAL $IMEM_BASE] [get_bd_cells boot_addr_constant]

  set_property -dict [list CONFIG.CONST_WIDTH {64}] [get_bd_cells mhartid_constant]
  set_property -dict [list CONFIG.CONST_VAL {0x000000000000108B}] [get_bd_cells mhartid_constant]

  connect_bd_net [get_bd_pins boot_addr_constant/dout] [get_bd_pins cva6_0/boot_addr_i]
  connect_bd_net [get_bd_pins mhartid_constant/dout] [get_bd_pins cva6_0/hart_id_i]

#TODO handle unconnected pins:
# /cva6_0/irq_i[1:0]
# /cva6_timer_0/axi_timer_awatop
# /cva6_dm_0/axi_dm_slave_awatop
# /cva6_dm_0/axi_dm_master_awatop (output)
# /cva6_0/io_axi_mem_awatop (output)
# /RVController_0/reqRDY_req_rdy
# /RVController_0/resRDY_res_rdy

# Add debug module
if 0 {
  # Insert JTAG interface port and connect it to the core
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:jtag_rtl:2.0 CoreJTAG
  connect_bd_intf_net [get_bd_intf_ports CoreJTAG] [get_bd_intf_pins cva6_0/jtag]

  create_bd_port -dir I -type rst JTAG_RST
  set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports JTAG_RST]
  connect_bd_net [get_bd_ports JTAG_RST] [get_bd_pins cva6_0/jtag_trst_n]
} else {
  set tapasco_toolflow $::env(TAPASCO_HOME_TOOLFLOW)
  set_property ip_repo_paths [concat [get_property ip_repo_paths [current_project]] $tapasco_toolflow/vivado/common/ip/DMI/] [current_project]
  update_ip_catalog

  create_bd_intf_port -mode Slave -vlnv esa.informatik.tu-darmstadt.de:user:DMI_rtl:1.0 DMI
  connect_bd_intf_net [get_bd_intf_ports DMI] [get_bd_intf_pins cva6_0/DMI]
}

proc create_specific_addr_segs {} {
  variable lmem
  variable DMEM_BASE
  variable DMEM_LENGTH
  variable IMEM_BASE
  variable IMEM_LENGTH
  variable DEBUG_BASE
  variable DEBUG_LENGTH
  

  # Create specific address segments
  create_bd_addr_seg -range 0x00010000 -offset 0x11000000 [get_bd_addr_spaces cva6_0/io_axi_mem] [get_bd_addr_segs RVController_0/saxi/reg0] SEG_RVController_0_reg0
  create_bd_addr_seg -range $DMEM_LENGTH -offset $DMEM_BASE [get_bd_addr_spaces cva6_0/io_axi_mem] [get_bd_addr_segs rv_dmem_ctrl/S_AXI/Mem0] SEG_rv_dmem_ctrl_Mem0
  create_bd_addr_seg -range $IMEM_LENGTH -offset $IMEM_BASE [get_bd_addr_spaces cva6_0/io_axi_mem] [get_bd_addr_segs rv_imem_ctrl/S_AXI/Mem0] SEG_rv_imem_ctrl_Mem0
}

proc get_external_mem_addr_space {} {
  return [get_bd_addr_spaces cva6_0/io_axi_mem]
}

