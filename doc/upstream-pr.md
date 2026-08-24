# Notes for the upstream pull request

## The change

Three files:

- `servant/servant_tangnano9k.v` (new)
- `data/tangnano9k.cst` (new)
- `servant.core` (patched, see `patch/servant.core.diff`)

That is the same shape as every other board target upstream.

## Flow choice

The target uses the edalize `gowin` flow, which drives the official toolchain
through `gw_sh`. Verified against the installed edalize: the flow exists, takes
`part` and `part_version` as flow options, and handles the `CST` file type.

The open source `apicula` flow was tried and does not currently work. Yosys
`synth_gowin` completes cleanly, but nextpnr-gowin fails at placement:

```
ERROR: Unable to place cell 'servant.ram.mem.0.3',
       no BELs remaining to implement cell type 'SPX9'
```

Yosys always emits the 9-bit BSRAM variant for this memory, and the chipdb in
the yowasp wheels has no `SPX9` BELs for GW1N-9C. Worth retrying against a
source build of apicula before claiming this is settled. It is a toolchain gap,
not an RTL problem.

## Points a reviewer may raise

**Why no PLL, when most targets have a clock_gen?** The board oscillator is
27 MHz and 32 MHz is unreachable from it with a legal phase detector frequency.
Running at 27 MHz directly keeps the target minimal; the console lands at
97200 baud. `servant_tangnano9k_clock_gen.v` is included for anyone who wants
32.4 MHz and 116640 baud instead. Happy to wire it in by default if preferred.

**Why only one LED?** Servant drives one output bit. Pins 15 and 16 are in the
PSRAM's 1.8V bank and reject LVCMOS33 constraints, so exposing six LEDs means
either dropping IO_TYPE across the board or hitting `CT1136`. One LED avoids
the question entirely.

**Does the RAM infer correctly?** Yes, four BSRAM blocks, verified in both
Gowin EDA and yosys. No Gowin-specific RAM file is needed, unlike Quartus.

## Testing done

- `blinky.hex`, LED0 blinks.
- `zephyr_hello.hex` at `memsize=8192`, boots and prints over UART at
  97200 baud.
- Built in Gowin EDA and flashed to embedded flash on real hardware.
