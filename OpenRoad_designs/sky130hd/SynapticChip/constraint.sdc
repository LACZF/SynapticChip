set clk_name  core_clock
set clk_port_name clk
set clk_period 10.000
set clk_io_pct 0.2
set jtag_clk_name  jtag_clock
set jtag_clk_port_name jtag_tck_pin
set jtag_clk_period 200.000

set clk_port [get_ports $clk_port_name]
set jtag_clk_port [get_ports $jtag_clk_port_name]

create_clock -name $clk_name -period $clk_period -waveform {0.000 5.000} $clk_port
create_clock -name $jtag_clk_name -period $jtag_clk_period -waveform {0.000 100.000} $jtag_clk_port

# set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]

# set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
# set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
