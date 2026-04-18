# ---- ADC eval board ----
set_property PACKAGE_PIN XX [get_ports {adc_data[0]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[1]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[2]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[3]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[4]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[5]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[6]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[7]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[8]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[9]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[10]}]
set_property PACKAGE_PIN XX [get_ports {adc_data[11]}]
set_property PACKAGE_PIN XX [get_ports adc_dco]

# ---- ESP32 ----
set_property PACKAGE_PIN XX [get_ports trigger_in]
set_property PACKAGE_PIN XX [get_ports esp32_ready]
set_property PACKAGE_PIN XX [get_ports capture_done]
set_property PACKAGE_PIN XX [get_ports data_out]

# ---- voltage standard for all pins ----
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports adc_dco]
set_property IOSTANDARD LVCMOS18 [get_ports trigger_in]
set_property IOSTANDARD LVCMOS18 [get_ports esp32_ready]
set_property IOSTANDARD LVCMOS18 [get_ports capture_done]
set_property IOSTANDARD LVCMOS18 [get_ports data_out]

# ---- clock constraint ----
create_clock -period 4.0 -name adc_dco [get_ports adc_dco]