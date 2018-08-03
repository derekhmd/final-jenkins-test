Debugging & Testing with RTL Simulation
=======================================

Simulation of a single FireSim node using software RTL simulators like
Verilator, Synopsys VCS, or XSIM, is the most productive way to catch bugs
before generating an AGFI.

FireSim provides flows to do RTL simulation at three different levels of
the design/abstraction hierarchy. Ordered from least to most detailed, they are:

- **Target-Level**: This simulates just the RTL of the target-design (Rocket
  Chip). There are no host-level features being simulated. Supported
  simulators: VCS, Verilator.
- **MIDAS-Level**: This simulates the target-design after it's been transformed
  by MIDAS.  The target- and host-clock are decoupled. FPGA-hosted simulation
  models are present.  Abstract models for host-FPGA provided services, like
  DRAM, memory-mapped IO, and PCIS are used here. Supported simulators: VCS,
  Verilator.
- **FPGA-Level**: This is a complete simulation of the design that will passed
  to the FPGA tools, including clock-domain crossings, width adapters, PLLS,
  FPGA-periphery blocks like DRAM and PCI-E controllers. This leverages the
  simulation flow provided by AWS. Supported simulators: VCS, Vivado XSIM.


Generally, MIDAS-level simulations are only slightly slower than simulating at
target-RTL. Moving to FPGA-Level is very expensive. This illustrated in the
chart below.

====== ===== =======  ========= =======
Level  Waves VCS      Verilator XSIM
====== ===== =======  ========= =======
Target Off   4.8 kHz  6.2 kHz   N/A
Target On    0.8 kHz  4.8 kHz   N/A
MIDAS  Off   3.8 kHz  2.0 kHz   N/A
MIDAS  On    2.9 kHz  1.0 kHz   N/A
FPGA   On    2.3  Hz  N/A       0.56 Hz
====== ===== =======  ========= =======

Notes: Default configurations of a single-core Rocket Chip instance running
rv64ui-v-add.  Frequencies are given in target-Hz. Presently, the default
compiler flags passed to Verilator and VCS differ from level to level. Hence,
these numbers are only intended to ball park simulation speeds with FireSim's
out-of-the-box settings, not provide a scientific comparison between
simulators.

Target-Level Simulation
--------------------------

This is described in :ref:`target-level-simulation`, as part of the *Developing
New Devices* tutorial.

MIDAS-Level Simulation
------------------------

MIDAS-level simulations are run out of the ``firesim/sim`` directory. Currently, FireSim
lacks support for MIDAS-level simulation of the NIC since DMA\_PCIS is not yet
supported. So here we'll be setting ``DESIGN=FireSimNoNIC``. To compile a simulator,
type:

::

    [in firesim/sim]
    make <verilator|vcs>

To compile a simulator with full-visibility waveforms, type:

::

    make <verilator|vcs>-debug

As part of target-generation, Rocket Chip emits a make fragment with recipes
for running suites of assembly tests. MIDAS puts this in
``firesim/sim/generated-src/f1/<DESIGN>-<TARGET_CONFIG>-<PLATFORM_CONFIG>/firesim.d``.
Make sure your ``$RISCV`` environment variable is set by sourcing
``firesim/source-me*.sh`` or ``firesim/env.sh``, and type:

::

    make run-<asm|bmark>-tests EMUL=<vcs|verilator>


To run only a single test, the make target is the full path to the output.
Specifically:

::

    make EMUL=<vcs|verilator> $PWD/output/f1/<DESIGN>-<TARGET_CONFIG>-<PLATFORM_CONFIG>/<RISCV-TEST-NAME>.<vpd|out>

A ``.vpd`` target will use (and, if required, build) a simulator with waveform dumping enabled,
whereas a ``.out`` target will use the faster waveform-less simulator.


--------
Examples
--------

Run all RISCV-tools assembly and benchmark tests on a verilated simulator.

::

    [in firesim/sim]
    make DESIGN=FireSimNoNIC
    make DESIGN=FireSimNoNIC -j run-asm-tests
    make DESIGN=FireSimNoNIC -j run-bmark-tests


Run rv64ui-p-simple (a single assembly test) on a verilated simulator.

::

    make DESIGN=FireSimNoNIC
    make $(pwd)/output/f1/FireSimNoNIC-FireSimRocketChipConfig-FireSimConfig/rv64ui-p-simple.out

Run rv64ui-p-simple (a single assembly test) on a VCS simulator with waveform dumping.

::


    make DESIGN=FireSimNoNIC vcs-debug
    make EMUL=vcs $(pwd)/output/f1/FireSimNoNIC-FireSimRocketChipConfig-FireSimConfig/rv64ui-p-simple.vpd


FPGA-Level Simulation
----------------------------

Like MIDAS-level simulation, there is currently no support for DMA\_PCIS, so
we'll restrict ourselves to instances without a NIC by setting `DESIGN=FireSimNoNIC`.  As
with MIDAS-level simulations, FPGA-level simulations run out of
``firesim/sim``.

Since FPGA-level simulation is up to 1000x slower than MIDAS-level simulation,
FPGA-level simulation should only be used in two cases:

1. MIDAS-level simulation of the simulation is working, but running the
   simulator on the FPGA is not.
2. You've made changes to the AWS Shell/IP/cl\_firesim.sv in aws-fpga
   and want to test them.

FPGA-level simulation consists of two components:

1. A FireSim-f1 driver that talks to a simulated DUT instead of the FPGA
2. The DUT, a simulator compiled with either XSIM or VCS, that receives commands from the aforementioned
   FireSim-f1 driver

-----
Usage
-----

To run a simulation you need to make both the DUT and driver targets by typing:

::

    make xsim
    make xsim-dut <VCS=1> & # Launch the DUT
    make xsim SIM_BINARY=<PATH/TO/BINARY> # Launch the driver


Once both processes are running, you should see:

::

    opening driver to xsim
    opening xsim to driver

This indicates that the DUT and driver are successfully communicating.
Eventually, the DUT will print a commit trace Rocket Chip. There will
be a long pause (minutes, possibly an hour, depending on the size of the
binary) after the first 100 instructions, as the program is being loaded
into FPGA DRAM.

XSIM is used by default, and will work on EC2 instances with the FPGA developer
AMI.  If you have a license, setting ``VCS=1`` will use VCS to compile the DUT
(4x faster than XSIM). Berkeley users running on the Millennium machines should
be able to source ``firesim/scripts/setup-vcsmx-env.sh`` to setup their
environment for VCS-based FPGA-level simulation.

The waveforms are dumped in the FPGA build directories(
``firesim/platforms/f1/aws-fpga/hdk/cl/developer_designs/cl_<DESIGN>-<TARGET_CONFIG>-<PLATFORM_CONFIG>``).

For XSIM:

::

    <BUILD_DIR>/verif/sim/vivado/test_firesim_c/tb.wdb

And for VCS:

::

    <BUILD_DIR>/verif/sim/vcs/test_firesim_c/test_null.vpd


When finished, be sure to kill any lingering processes if you interrupted simulation prematurely.
