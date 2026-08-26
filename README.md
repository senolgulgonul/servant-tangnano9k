# Servant on the Sipeed Tang Nano 9K

A port of [SERV](https://github.com/olofk/serv), the world's smallest RISC-V
CPU, and its reference SoC Servant, to the Sipeed Tang Nano 9K
(Gowin GW1NR-LV9QN88PC6/I5).

Servant has been ported to around twenty FPGA boards upstream, but none of them
are Gowin parts. This fills that gap.

Status: working. `blinky` blinks, and Zephyr boots and prints over the UART.

```
***** Booting Zephyr OS zephyr-v1.14.1-4-gc7c2d62513fe *****
Hello World! service
```

## What is here

```
servant/servant_tangnano9k.v            board top level
servant/servant_tangnano9k_clock_gen.v  optional rPLL, 27 -> 32.4 MHz
data/tangnano9k.cst                     physical constraints
build.tcl                               gw_sh build script
setup.ps1                               PowerShell bootstrap for Windows
patch/servant.core.diff                 fusesoc target, ready for upstream
doc/kurulum-tr.md                       step by step setup guide (Turkish)
doc/installation.md                     (English)
```

The layout mirrors upstream's, so the port drops straight into a fork of
olofk/serv.

## Design notes

**No PLL.** The core runs directly off the board's 27 MHz oscillator. The
consequence is the console baud rate: Servant's UART is bit-banged and
calibrated for 115200 baud at 32 MHz, so at 27 MHz it scales to
`115200 * 27/32 = 97200`. Set your terminal to 97200.

Exactly 32 MHz is not reachable from 27 MHz. 32/27 is already in lowest terms,
so the rPLL would need `IDIV_SEL = 26`, giving a 1 MHz phase detector frequency
against a 3 MHz legal minimum. The closest legal ratio is 6/5:

```
PFD = 27.0 / 5   =    5.4 MHz    (legal 3 to 400 MHz)
VCO = 32.4 * 32  = 1036.8 MHz    (legal 400 to 1200 MHz)
CLK = 27.0 * 6/5 =   32.4 MHz    -> 116640 baud, +1.25% error
```

`servant_tangnano9k_clock_gen.v` implements that if you want a rate closer to
standard. It is not wired in by default.

**One LED.** Servant drives a single output bit, so only LED0 on pin 10 is
used. LED4 and LED5 are on pins 15 and 16, which sit in Bank 3; the on-chip
PSRAM locks that bank to 1.8V, and constraining anything there as LVCMOS33 is
rejected with `CT1136`. Pin 4, the S1 button used for reset, is in the same
bank, so its constraint carries no `IO_TYPE` either.

**Memory inference.** The 8 kiB main RAM maps cleanly to four BSRAM blocks.
This was the main risk in the port: upstream needs a Quartus-specific
`servant_ram_quartus.sv` because byte-enable inference is fragile, but the
generic `servant_ram.v` works as-is on Gowin.

## Resource usage

GowinSynthesis, `blinky.hex` at `memsize=8192`, no PLL:

| | LUT4 | REG | ALU | BSRAM | SSRAM |
| --- | ---: | ---: | ---: | ---: | ---: |
| **Whole SoC** | **343** | **247** | **71** | **5** | **2** |
| SERV core (`serv_top`) | 260 | 151 | 4 | 0 | 2 |
| Timer | 3 | 65 | 62 | 0 | 0 |
| Main RAM, 8 kiB | 8 | 1 | 0 | 4 | 0 |
| Register file | 51 | 19 | 0 | 1 | 0 |

That is about 4% of the GW1NR-9's 8640 LUT4.

Three things worth noting:

The 64-bit `mtime` counter costs more than the CPU's entire control path:
65 registers and 62 ALU cells against the core's 151 registers and 4 ALU.

Gowin places the SERV register file in BSRAM. Yosys `synth_gowin` chose LUTRAM
for the same RTL, so the two tools disagree here.

Gowin's own synthesis is noticeably tighter than yosys on this design, 343
LUT4 against 722.

**Do not compare the 260 LUT4 core figure to upstream's 198 LUT on iCE40.**
That number is for the minimal configuration without CSR support; this build
has CSRs, which alone account for 29 LUT4 and 10 registers, and the LUT
architectures differ. A fair comparison means synthesising `serv_synth_wrapper`
standalone with upstream's minimal parameters.

## Build

### Gowin EDA, command line

```powershell
.\setup.ps1
```

Creates the working tree, clones olofk/serv, pins the memory image path, finds
`gw_sh.exe` and builds. `-Root` to change the location, `-NoBuild` to only lay
out the tree, `-Load` to program afterwards.

### Gowin EDA, GUI

See doc/installation.md (English) or doc/kurulum-tr.md (Turkish). The part is `GW1NR-LV9QN88PC6/I5` and the **device
version must be C**; leave it unset and the bitstream still builds and still
loads, but the board does nothing and nothing is reported.

### Programming

```
openFPGALoader -b tangnano9k impl/pnr/servant_tangnano9k.fs        # SRAM
openFPGALoader -b tangnano9k -f impl/pnr/servant_tangnano9k.fs     # flash
```

## Running Zephyr

Point the `memfile` parameter at one of the prebuilt images in `serv/sw`, using
an absolute path with forward slashes, and set `memsize` to match:

| Image | memsize | What it does |
| --- | --- | --- |
| `blinky.hex` | 8192 | Toggles the GPIO bit. No UART. |
| `zephyr_hello.hex` | 8192 | Boots Zephyr, prints hello. |
| `zephyr_hello_mt.hex` | 16384 | Multithreaded hello. |
| `zephyr_sync.hex` | 16384 | Two threads, semaphore handoff. |
| `zephyr_phil.hex` | 16384 | Dining philosophers. |

The console is transmit only: Servant's only port besides clock and reset is a
single output bit, so there is no shell and nothing to type.

A relative `memfile` path will not resolve, because GowinSynthesis runs from
`impl/gwsynthesis`. When that happens the RAM is silently all zeros and the LED
just stays dark. Gowin ignores `$display`, so the confirmation is not a
`Preloading` line but the *absence* of an `EX3988` warning.

## Upstream

`patch/servant.core.diff` adds a `tangnano9k` fileset and target to
olofk/serv's `servant.core`, using the edalize `gowin` flow. Applying that plus
copying `servant/servant_tangnano9k.v` and `data/tangnano9k.cst` into a fork is
the whole change.

## Licence

ISC, matching SERV. SERV itself is copyright Olof Kindgren and is not included
here; add it as a submodule or clone it alongside.
