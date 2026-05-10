---
name: tt-gate-level-sim
description: 'Run cocotb tests against the post-harden gate-level netlist for a Tiny Tapeout project. USE WHEN: a harden run is clean and the orchestrator wants to confirm functional equivalence on the actual netlist, or a test passes RTL but the user suspects a synth-introduced bug. Covers the netlist copy step, the GATES=yes makefile path, and triage of GL-only failures (X-propagation, missing reset, undriven uio_oe). DO NOT USE FOR: pre-harden RTL simulation (use tt-cocotb-testing), or interpreting STA/DRC reports (use tt-report-analysis).'
---

# Tiny Tapeout Gate-Level Simulation

Same `test/test.py`, but the DUT is the **post-route netlist** (with sky130/gf180 standard cells or IHP equivalents) instead of the RTL. Run **after** a clean `--harden` to catch synth/route bugs and X-propagation.

## Setup

```bash
source ~/.ttenv
cd "$PROJECT_ROOT/test"
TOP_MODULE=$(cd .. && ./tt/tt_tool.py --print-top-module)
```

Pick the right netlist for the PDK:

| PDK | Netlist | Path |
|---|---|---|
| sky130A, gf180mcuD | **powered** (`pnl`) | `../runs/wokwi/<latest>/final/pnl/$TOP_MODULE.pnl.v` |
| ihp-sg13g2 | **unpowered** (`nl`) | `../runs/wokwi/<latest>/final/nl/$TOP_MODULE.nl.v` |

Copy as `gate_level_netlist.v` (the makefile expects that name):

```bash
# sky / gf:
cp ../runs/wokwi/*/final/pnl/$TOP_MODULE.pnl.v gate_level_netlist.v
# ihp:
cp ../runs/wokwi/*/final/nl/$TOP_MODULE.nl.v   gate_level_netlist.v
```

## Run

```bash
make -B GATES=yes
```

The makefile's `GATES=yes` branch sets `-DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=#1` and pulls in `$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog/{primitives,sky130_fd_sc_hd}.v`. (The Makefile in this repo is sky-only — for IHP/GF, swap those library paths.)

Pass criterion: same as RTL — every `@cocotb.test()` ends with `** TEST PASS **`.

## Triaging GL-only failures

If a test passes `make -B` but fails `make -B GATES=yes`:

### 1. X-propagation

Symptom: signal is `xxxx` after reset, RTL had a defined value.

Cause: GL flops start at `x` and only synchronously reach known values via reset; RTL `initial` blocks (or implicit `0` init) hide this.

Fix: ensure **every** stateful element is reset by `rst_n`. Search `src/` for `always @(posedge clk)` blocks that don't have an `if (!rst_n)` branch.

### 2. Reset too short

Symptom: random tests pass, but `uo_out` is `x` for the first few cycles after reset, breaking assertions.

Fix: extend the reset hold in the test (e.g. `await ClockCycles(dut.clk, 20)` instead of 2) — long enough for every register to clock through reset.

### 3. Undriven `uio_oe`

Symptom: `uio_out` reads as `x` in GL.

Fix: in the top module, drive `uio_oe = 8'b0` (or whatever mask) explicitly. Never leave bits unassigned.

### 4. White-box probe broke

Symptom: `AttributeError: ... has no attribute '<sig>'` or signal renamed.

Cause: synthesis flattens / renames internal nets. White-box probes are RTL-only.

Fix: rewrite the assertion against `dut.uo_out` / `dut.uio_out` only. If you really need internal observability, expose a debug bus via `uio_out` behind a debug enable.

### 5. Power pin connectivity (sky/gf)

Symptom: every cell output is `x`.

Cause: `tb.v` doesn't tie `VPWR=1` / `VGND=0` to the powered netlist.

Fix: `tb.v` already handles this in the TT template — confirm by grepping `VPWR` in `test/tb.v`. If absent, add the `USE_POWER_PINS` block from a fresh template.

### 6. Setup violation that didn't show in STA

Rare. Re-check STA reports via [tt-report-analysis](../tt-report-analysis/SKILL.md); the netlist may have a path the SDC didn't cover (e.g., async input not declared as `set_false_path`).

## When to skip GL sim

GL sim is slow (10–100× RTL). Skip it for:
- Pure visualization or comment changes.
- Iteration loops where multiple harden runs are expected.

Always run it before:
- Submitting a project.
- After bumping `LIBRELANE_TAG`.
- After any RTL change that touches reset, async inputs, or `uio_oe`.

## Handoff

If GL passes → orchestrator marks the run as fully signed off.
If GL fails → categorize using the table above, then hand to [tt-rtl-authoring](../tt-rtl-authoring/SKILL.md) (most GL failures are RTL fixes), then back through `--harden` and GL again.
