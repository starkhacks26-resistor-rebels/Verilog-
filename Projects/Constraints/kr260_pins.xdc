# ADC eval board
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

# Rubik Pi SPI
set_property PACKAGE_PIN XX [get_ports spi_sclk]
set_property PACKAGE_PIN XX [get_ports spi_cs]
set_property PACKAGE_PIN XX [get_ports trigger_in]
set_property PACKAGE_PIN XX [get_ports spi_miso]

# Haptics
set_property PACKAGE_PIN XX [get_ports haptic_out]

# voltage standards
set_property IOSTANDARD LVCMOS18 [get_ports {adc_data[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports adc_dco]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs]
set_property IOSTANDARD LVCMOS33 [get_ports trigger_in]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports haptic_out]

# clock constraints
create_clock -period 4.0  -name clk     [get_ports clk]
create_clock -period 4.0  -name adc_dco [get_ports adc_dco]
create_clock -period 20.0 -name spi_sclk [get_ports spi_sclk]

# async clock groups
set_clock_groups -asynchronous -group clk -group spi_sclk -group adc_dco