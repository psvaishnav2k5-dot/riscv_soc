create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty
# Constrain all inputs (Switches, Keys, RX)
set_input_delay -clock CLOCK_50 -max 3.0 [all_inputs]
set_input_delay -clock CLOCK_50 -min 1.0 [all_inputs]

# Constrain all outputs (LEDs, HEX, TX)
set_output_delay -clock CLOCK_50 -max 3.0 [all_outputs]
set_output_delay -clock CLOCK_50 -min 1.0 [all_outputs]
