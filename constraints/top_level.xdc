## ============================================================
## Clock: 100MHz differential PL clock
## Note: P-side = D7, N-side = D6 (per device pin-pair database)
## ============================================================
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports sys_clk_p]

set_property PACKAGE_PIN D7 [get_ports sys_clk_p]
set_property PACKAGE_PIN D6 [get_ports sys_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_clk_n]

## ============================================================
## Reset: pushbutton PL_USER_PB0 (not used by top_level)
## ============================================================
# set_property PACKAGE_PIN AB6 [get_ports reset_btn]
# set_property IOSTANDARD LVCMOS12 [get_ports reset_btn]

## ============================================================
## Keep-alive output on PL_USER_LED[0]
## ============================================================
set_property PACKAGE_PIN AF5 [get_ports led]
set_property IOSTANDARD LVCMOS12 [get_ports led]

## ============================================================
## Bitstream settings (from the board's master XDC)
## ============================================================
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]


create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 2 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk]]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
set_property port_width 10 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {anomaly_count[0]} {anomaly_count[1]} {anomaly_count[2]} {anomaly_count[3]} {anomaly_count[4]} {anomaly_count[5]} {anomaly_count[6]} {anomaly_count[7]} {anomaly_count[8]} {anomaly_count[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
set_property port_width 28 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {out_data[0]} {out_data[1]} {out_data[2]} {out_data[3]} {out_data[4]} {out_data[5]} {out_data[6]} {out_data[7]} {out_data[8]} {out_data[9]} {out_data[10]} {out_data[11]} {out_data[12]} {out_data[13]} {out_data[14]} {out_data[15]} {out_data[16]} {out_data[17]} {out_data[18]} {out_data[19]} {out_data[20]} {out_data[21]} {out_data[22]} {out_data[23]} {out_data[24]} {out_data[25]} {out_data[26]} {out_data[27]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
set_property port_width 10 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {s_count[0]} {s_count[1]} {s_count[2]} {s_count[3]} {s_count[4]} {s_count[5]} {s_count[6]} {s_count[7]} {s_count[8]} {s_count[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
set_property port_width 8 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {run_count[0]} {run_count[1]} {run_count[2]} {run_count[3]} {run_count[4]} {run_count[5]} {run_count[6]} {run_count[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list out_anomaly]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list out_valid]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
