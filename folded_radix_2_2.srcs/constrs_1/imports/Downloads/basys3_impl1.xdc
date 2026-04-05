## ============================================================
##  Basys3 XDC — Radix-2 Folded FFT (Implementation 1)
##  Board: Digilent Basys3  (XC7A35T-1CPG236C)
##  Design: top.v  (clk, btnC → seg[6:0], an[3:0])
## ============================================================

## ------------------------------------------------------------
## Clock — 100 MHz onboard oscillator, pin W5
## ------------------------------------------------------------
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.0 -name sys_clk -waveform {0 5} [get_ports clk]

## Clock uncertainty (jitter margin for 100 MHz)
set_clock_uncertainty 0.200 [get_clocks sys_clk]

## ------------------------------------------------------------
## Reset — Centre button (btnC)
## ------------------------------------------------------------
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## ------------------------------------------------------------
## 7-Segment Display — Cathodes (segments a–g, active LOW)
## seg[0]=a  seg[1]=b  seg[2]=c  seg[3]=d
## seg[4]=e  seg[5]=f  seg[6]=g
## ------------------------------------------------------------
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]

## ------------------------------------------------------------
## 7-Segment Display — Anodes (digit select, active LOW)
## an[0]=rightmost digit ... an[3]=leftmost digit
## ------------------------------------------------------------
set_property PACKAGE_PIN U2 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]

## ------------------------------------------------------------
## Switching Activity — fixes the "Junction temp exceeded" power
## report by giving Vivado realistic toggle rates instead of the
## default 12.5% which inflates DSP power to ~52W (impossible).
##
## Realistic rates for this design:
##   clk     : 50% toggle (by definition)
##   DSP paths: FFT runs once then idles → low average toggle
##   seg/an  : ~1 kHz refresh = 0.001% of 100 MHz → very low
##   btnC    : essentially static
## ------------------------------------------------------------

## Clock gets full 50% activity — this is always correct
set_switching_activity -static_probability 0.5 -toggle_rate 100.0 \
    [get_ports clk]

## Button/reset: static most of the time (pressed <0.1% of runtime)
set_switching_activity -static_probability 0.01 -toggle_rate 0.01 \
    [get_ports btnC]

## 7-seg segments: toggling at ~1 kHz on a 100 MHz clock
## toggle_rate = (transitions per clock) × 100
## 1 kHz / 100 MHz = 0.00001 transitions/clock → rate = 0.001
set_switching_activity -static_probability 0.5 -toggle_rate 0.001 \
    [get_ports {seg[*]}]
set_switching_activity -static_probability 0.75 -toggle_rate 0.001 \
    [get_ports {an[*]}]

## Internal DSP signals: FFT completes in ~12 clocks then holds output.
## At 100 MHz the FSM runs for ~12 ns then goes idle indefinitely.
## Effective average toggle rate ≈ 0.01% (12 active clocks vs billions idle).
## Setting 0.5% is a generous upper bound — keeps power estimate realistic.
set_switching_activity -static_probability 0.5 -toggle_rate 0.5 \
    [get_nets -hierarchical -filter {NAME =~ *bf_*}]

## Data memory (data_re, data_im): written during FFT, static after
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 \
    [get_nets -hierarchical -filter {NAME =~ *data_re*}]
set_switching_activity -static_probability 0.5 -toggle_rate 0.1 \
    [get_nets -hierarchical -filter {NAME =~ *data_im*}]

## ------------------------------------------------------------
## Timing — False paths on quasi-static signals
## ------------------------------------------------------------

## btnC is a slow asynchronous input — no meaningful timing path
set_false_path -from [get_ports btnC]

## seg and an outputs are driven by slow mux logic clocked at ~1kHz
## and the Double Dabble bin2bcd conversion is deeply combinatorial.
## The human eye integrates light at ~60Hz, so nanosecond timing 
## on display outputs is meaningless. We map them as false paths.
set_false_path -to [get_ports {seg[*]}]
set_false_path -to [get_ports {an[*]}]

## ------------------------------------------------------------
## Bitstream settings — required for Basys3 programming
## ------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ------------------------------------------------------------
## Optional: uncomment to set bitstream compression
## (reduces programming time slightly)
## ------------------------------------------------------------
## set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
