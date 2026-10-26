# SPDX-FileCopyrightText: 2026 ChipFoundry
# SPDX-License-Identifier: Apache-2.0
#
# Constraints for double_wide_openframe_project_wrapper (PnR and signoff).
#
# The wrapper contains only routing, the hardened user macro and the
# CF_gpio_config tie-offs. Pad-driven inputs use the characterized pad input
# transition from the Caravel signoff constraints (io_in).

set clk_port [get_ports {gpio_in[0]}]
create_clock $clk_port -name clk -period 25

set_max_fanout 16 [current_design]
set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]

set_input_transition -max 0.38 [all_inputs]
set_input_transition -min 0.05 [all_inputs]

# Constant-level tie-off sources from the padframe. They never toggle and
# only feed static pad configuration pins.
set_case_analysis 0 [get_ports {gpio_loopback_zero[*]}]
set_case_analysis 1 [get_ports {gpio_loopback_one[*]}]

# Reset inputs are asynchronous to the user clock (see user_proj_counter).
set_false_path -from [get_ports {gpio_in[1] porb_l porb_h por_l resetb_l resetb_h}]

set_output_delay [expr 25 * 0.2] -clock [get_clocks clk] [get_ports {gpio_out[*]}]
set_load 0.033442 [all_outputs]

set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

set_timing_derate -early 0.95
set_timing_derate -late 1.05

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
