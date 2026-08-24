# gw_sh build script for the Servant SoC on the Sipeed Tang Nano 9K.
#
# Version 0.3.0
#
# Usage, from the directory that holds this script:
#
#   & "C:\Gowin\Gowin_V1.9.11\IDE\bin\gw_sh.exe" build.tcl
#
# setup.ps1 creates the directory layout this expects:
#
#   <root>/build.tcl
#   <root>/blinky.hex
#   <root>/serv/          clone of github.com/olofk/serv
#   <root>/src/           servant_tangnano9k.v, tangnano9k.cst
#
# Paths are resolved against this script's own location, so the working
# directory does not matter.

set root [file dirname [file normalize [info script]]]

set_device GW1NR-LV9QN88PC6/I5 -device_version C

# SERV core
foreach f {
    serv_aligner.v serv_alu.v serv_bufreg.v serv_bufreg2.v
    serv_compdec.v serv_csr.v serv_ctrl.v serv_decode.v
    serv_immdec.v serv_mem_if.v serv_rf_if.v serv_rf_ram.v
    serv_rf_ram_if.v serv_rf_top.v serv_state.v serv_top.v
} { add_file -type verilog [file join $root serv rtl $f] }

# Servile, the bus and register file glue layer
foreach f {
    servile.v servile_arbiter.v servile_mux.v servile_rf_mem_if.v
} { add_file -type verilog [file join $root serv servile $f] }

# Servant SoC. Note that servant_ram_quartus.sv and serv_debug.v are
# deliberately excluded, and serv_synth_wrapper.v would clash with our top.
foreach f {
    servant.v servant_ram.v servant_timer.v servant_gpio.v servant_mux.v
} { add_file -type verilog [file join $root serv servant $f] }

# Board level
add_file -type verilog [file join $root src servant_tangnano9k.v]
add_file -type cst     [file join $root src tangnano9k.cst]

set_option -top_module servant_tangnano9k
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name servant_tangnano9k
set_option -gen_text_timing_rpt 1

run all
