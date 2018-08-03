#!/usr/bin/env bash

# This script runs a RISC-V assembly test in RTL simulation at the three
# supported abstraction levels and captures the necessary portions of the log
# to calculate simulation rates
#
# Abstraction levels:
# Target -> Just the target RTL
# MIDAS  -> The target post-transformations, fpga-hosted models & widgets
# FPGA   -> The whole RTL design pre-synthesis
#
# This requires a VCS license.
# Berkeley users: If running on millenium machines, source scripts/setup_vcsmx_env.sh

# The ISA test to run
TEST=rv64ui-v-add
#TEST=rv64ui-p-simple

# The file into which we dump all the relevant pieces of simulation log. Some
# post-processing is still required.
REPORT_FILE=$(pwd)/runtime.rpt

MAKE_THREADS=4

cd $(dirname $0)/..
firesim_root=$(pwd)
test_path=$RISCV/riscv64-unknown-elf/share/riscv-tests/isa/$TEST

echo -e "FireSim RTL Simulation Execution Rates\n" > $REPORT_FILE
################################################################################
# TARGET level
################################################################################
export DESIGN=FireSimNoNIC
export TARGET_CONFIG=FireSimRocketChipConfig
export PLATFORM_CONFIG=FireSimConfig
export SIM_ARGS=+verbose

## Verilator
cd $firesim_root/target-design/firechip/verisim
sim=simulator-example-DefaultExampleConfig
make -j$MAKE_THREADS
make -j$MAKE_THREADS debug

/usr/bin/time -a -o nowaves.log ./$sim $SIM_ARGS $test_path &> nowaves.log
/usr/bin/time -a -o waves.log ./$sim-debug $SIM_ARGS -vtest.vcd $test_path &> waves.log

echo -e "\nTarget-level Verilator\n" >> $REPORT_FILE
tail nowaves.log >> $REPORT_FILE
echo -e "\nTarget-level Verilator -- Waves Enabled\n" >> $REPORT_FILE
tail waves.log >> $REPORT_FILE

## VCS
cd $firesim_root/target-design/firechip/vsim/
sim=simv-example-DefaultExampleConfig
make -j$MAKE_THREADS
make -j$MAKE_THREADS debug

./$sim $SIM_ARGS $test_path &> nowaves.log
./$sim-debug $SIM_ARGS $test_path &> waves.log

echo -e "\nTarget-level VCS\n" >> $REPORT_FILE
tail nowaves.log >> $REPORT_FILE
echo -e "\nTarget-level VCS -- Waves Enabled\n" >> $REPORT_FILE
tail waves.log >> $REPORT_FILE

#################################################################################
## MIDAS level
################################################################################
ml_output_dir=$firesim_root/sim/output/f1/$DESIGN-$TARGET_CONFIG-$PLATFORM_CONFIG
test_symlink=$ml_output_dir/$TEST

cd $firesim_root/sim
make -j$MAKE_THREADS verilator
make -j$MAKE_THREADS verilator-debug
make -j$MAKE_THREADS vcs
make -j$MAKE_THREADS vcs-debug
mkdir -p $ml_output_dir

# Symlink it twice so we have unique targets for vcs and verilator
ln -sf $test_path $ml_output_dir/$TEST
ln -sf $test_path $ml_output_dir/$TEST-vcs

echo -e "\nMIDAS-level Waves Off\n" >> $REPORT_FILE
make EMUL=vcs ${test_symlink}-vcs.out
make ${test_symlink}.out
grep -Eo "simulation speed = .*" $ml_output_dir/*out >> $REPORT_FILE

echo -e "\nMIDAS-level Waves On\n" >> $REPORT_FILE
make EMUL=vcs ${test_symlink}-vcs.vpd
make ${test_symlink}.vpd
grep -Eo "simulation speed = .*" $ml_output_dir/*out >> $REPORT_FILE

################################################################################
# FPGA level
################################################################################
# Unlike the other levels, the driver and dut communicate through pipes

cd $firesim_root/sim
echo -e "\nFPGA-level XSIM - Waves On\n" >> $REPORT_FILE
make xsim
make xsim-dut | tee dut.out &
# Wait for the dut to come up; Compilation time is long.
while [[ $(grep driver_to_xsim dut.out) == '' ]]; do sleep 1; done
make run-xsim SIM_BINARY=$test_path &> driver.out
# These are too slow for the reported simulation rate to be non-zero; so tail
tail driver.out >> $REPORT_FILE

echo -e "\nFPGA-level VCS - Waves On\n" >> $REPORT_FILE
make xsim
make xsim-dut VCS=1 | tee vcs-dut.out &
# Wait for the dut to come up; Compilation time is long.
while [[ $(grep driver_to_xsim vcs-dut.out) == '' ]]; do sleep 1; done
make run-xsim SIM_BINARY=$test_path &> vcs-driver.out
# These are too slow for the reported simulation rate to be non-zero; so tail
tail vcs-driver.out >> $REPORT_FILE
