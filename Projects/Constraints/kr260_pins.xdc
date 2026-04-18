# === ADC Data Pins (PMOD1 & PMOD2) ===
set_property PACKAGE_PIN H12 [get_ports {adc_data[0]}]
set_property PACKAGE_PIN E10 [get_ports {adc_data[1]}]
set_property PACKAGE_PIN D10 [get_ports {adc_data[2]}]
set_property PACKAGE_PIN C11 [get_ports {adc_data[3]}]
set_property PACKAGE_PIN B10 [get_ports {adc_data[4]}]
set_property PACKAGE_PIN E12 [get_ports {adc_data[5]}]
set_property PACKAGE_PIN D11 [get_ports {adc_data[6]}]
set_property PACKAGE_PIN B11 [get_ports {adc_data[7]}]
set_property PACKAGE_PIN J11 [get_ports {adc_data[8]}]
set_property PACKAGE_PIN J10 [get_ports {adc_data[9]}]
set_property PACKAGE_PIN K13 [get_ports {adc_data[10]}]
set_property PACKAGE_PIN K12 [get_ports {adc_data[11]}]
set_property PACKAGE_PIN H11 [get_ports {adc_data[12]}]
set_property PACKAGE_PIN G10 [get_ports {adc_data[13]}]
set_property PACKAGE_PIN F12 [get_ports {adc_data[14]}]
set_property PACKAGE_PIN F11 [get_ports {adc_data[15]}]

# === SPI & Control Pins (PMOD3) ===
set_property PACKAGE_PIN AE12 [get_ports spi_sclk]
set_property PACKAGE_PIN AG10 [get_ports spi_cs]
set_property PACKAGE_PIN AF11 [get_ports trigger_in]
set_property PACKAGE_PIN AH12 [get_ports spi_miso]
set_property PACKAGE_PIN AF12 [get_ports haptic_out]
set_property PACKAGE_PIN AC12 [get_ports spi_mosi]
set_property PACKAGE_PIN AD12 [get_ports adc_dco] 

# === IO Standards ===
set_property IOSTANDARD LVCMOS33 [get_ports {adc_data[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports adc_dco]
set_property IOSTANDARD LVCMOS33 [get_ports spi_*]
set_property IOSTANDARD LVCMOS33 [get_ports trigger_in]
set_property IOSTANDARD LVCMOS33 [get_ports haptic_out]

# === Timing Constraints ===
# We don't PACKAGE_PIN clk because it's internal from the PS
# But we must tell Vivado it's a 250MHz clock (4ns period)
create_clock -period 4.000 -name clk [get_nets -hierarchical *pl_clk0*]
create_clock -period 20.000 -name spi_sclk [get_ports spi_sclk]

# This is vital: It tells Vivado these two clocks don't need to be aligned
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks spi_sclk]