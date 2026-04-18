# === PMOD1 — ADC data [0:7] ===
set_property PACKAGE_PIN H12 [get_ports {adc_data[0]}]
set_property PACKAGE_PIN E10 [get_ports {adc_data[1]}]
set_property PACKAGE_PIN D10 [get_ports {adc_data[2]}]
set_property PACKAGE_PIN C11 [get_ports {adc_data[3]}]
set_property PACKAGE_PIN B10 [get_ports {adc_data[4]}]
set_property PACKAGE_PIN E12 [get_ports {adc_data[5]}]
set_property PACKAGE_PIN D11 [get_ports {adc_data[6]}]
set_property PACKAGE_PIN B11 [get_ports {adc_data[7]}]

# === PMOD2 — ADC data [8] + ADC control ===
set_property PACKAGE_PIN J11 [get_ports {adc_data[8]}]
set_property PACKAGE_PIN K13 [get_ports adc_busy]
set_property PACKAGE_PIN H11 [get_ports adc_frstdata]
set_property PACKAGE_PIN F12 [get_ports adc_convst]
set_property PACKAGE_PIN J10 [get_ports adc_cs]
set_property PACKAGE_PIN K12 [get_ports adc_rd]
set_property PACKAGE_PIN G10 [get_ports adc_reset]

# === PMOD3 — SPI + trigger + haptic ===
set_property PACKAGE_PIN AE12 [get_ports spi_sclk]
set_property PACKAGE_PIN AG10 [get_ports spi_cs]
set_property PACKAGE_PIN AF11 [get_ports trigger_in]
set_property PACKAGE_PIN AH12 [get_ports spi_miso]
set_property PACKAGE_PIN AF12 [get_ports haptic_out]

# === Voltage standards ===
set_property IOSTANDARD LVCMOS33 [get_ports {adc_data[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports adc_busy]
set_property IOSTANDARD LVCMOS33 [get_ports adc_frstdata]
set_property IOSTANDARD LVCMOS33 [get_ports adc_convst]
set_property IOSTANDARD LVCMOS33 [get_ports adc_cs]
set_property IOSTANDARD LVCMOS33 [get_ports adc_rd]
set_property IOSTANDARD LVCMOS33 [get_ports adc_reset]
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs]
set_property IOSTANDARD LVCMOS33 [get_ports trigger_in]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports haptic_out]

# === Clocks ===
create_clock -period 4.0  -name clk      [get_ports clk]
create_clock -period 20.0 -name spi_sclk [get_ports spi_sclk]
set_clock_groups -asynchronous -group clk -group spi_sclk
