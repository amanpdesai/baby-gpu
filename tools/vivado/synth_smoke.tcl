if {[llength $argv] < 4} {
    puts "usage: synth_smoke.tcl <top> <part> <out_dir> <source>..."
    exit 2
}

set top [lindex $argv 0]
set part [lindex $argv 1]
set out_dir [lindex $argv 2]
set sources [lrange $argv 3 end]

file mkdir $out_dir

foreach source $sources {
    if {![file exists $source]} {
        puts "missing source: $source"
        exit 2
    }
}

foreach source $sources {
    read_verilog -sv $source
}
synth_design -top $top -part $part -mode out_of_context
report_utilization -file [file join $out_dir "${top}_utilization.rpt"]
report_timing_summary -file [file join $out_dir "${top}_timing_summary.rpt"]
write_checkpoint -force [file join $out_dir "${top}.dcp"]
