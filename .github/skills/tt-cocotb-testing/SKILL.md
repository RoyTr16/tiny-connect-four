---
name: tt-cocotb-testing
description: 'Write, run, and debug cocotb tests for a Tiny Tapeout project. USE WHEN: adding test coverage for new RTL behavior, reproducing a bug before fixing it, after any RTL edit (regression), or when the orchestrator gates further phases on test pass. Covers the test/Makefile flow, tb.v wiring, the @cocotb.test() pattern, clock/reset boilerplate, ui_in/uo_out/uio_* access, and the GATES=yes gate-level variant. DO NOT USE FOR: writing synthesizable RTL (use tt-rtl-authoring), or interpreting hardening reports (use tt-report-analysis).'
---

# Tiny Tapeout cocotb Testing

The TT test harness uses **cocotb + Icarus** by default. Tests live in `test/test.py`; the testbench wrapper is `test/tb.v`; the build is driven by `test/Makefile`.

## Run tests

```bash
cd test
pip install -r requirements.txt    # first time only
make -B                            # RTL simulation
make -B GATES=yes                  # gate-level (after harden, see tt-gate-level-sim)
```

`-B` forces a clean rebuild — always use it; cocotb's incremental build is unreliable across edits.

A passing run ends with `** TEST PASS **` lines per `@cocotb.test()`. A failing run prints a Python traceback or a `assert` mismatch — read the **last** assertion, not the first warning.

## Adding a new source file

If you create `src/foo.v`, add `foo.v` to the `PROJECT_SOURCES` list in [test/Makefile](../../../test/Makefile). The makefile prefixes `$(SRC_DIR)/` automatically.

## Test file structure

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_<descriptive_name>(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, unit="ns")   # 100 MHz; pick what info.yaml clock_hz says
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Stimulus
    dut.ui_in.value = 0b0000_0001
    await ClockCycles(dut.clk, 5)

    # Check
    assert dut.uo_out.value == 0xAB, f"got {dut.uo_out.value}"
```

## Driving / reading TT ports from the test

| Signal | Direction | Access |
|---|---|---|
| `dut.clk`, `dut.rst_n`, `dut.ena` | drive | `dut.clk.value = 0` |
| `dut.ui_in[7:0]` | drive | `dut.ui_in.value = 0xAA` |
| `dut.uio_in[7:0]` | drive (bits where `uio_oe`==0) | `dut.uio_in.value = ...` |
| `dut.uo_out[7:0]` | read | `int(dut.uo_out.value)` |
| `dut.uio_out`, `dut.uio_oe` | read | only valid bits where `uio_oe`==1 |

For internal signals, use the dotted hierarchy through `dut.user_project.<inst>.<sig>` — useful for white-box debug, **never** for assertions that should survive gate-level (signals get renamed/optimized away).

## Patterns to use

- **Golden model in Python**: write the spec in Python, drive the same stimulus into both, assert equality every cycle. Far better than handcrafted `assert` lists.
- **Parametrized scenarios**: one `@cocotb.test()` per scenario, with descriptive names. Don't `for`-loop unrelated scenarios inside one test — failures lose attribution.
- **Reset helper**: factor the reset boilerplate into `async def reset(dut): ...` at module top.
- **Self-checking from `uo_out` only** when the test must also pass at gate-level. White-box probes break under GL.

## Patterns to avoid

- `await Timer(...)` for synchronization — race-prone. Use `RisingEdge(dut.clk)` / `ClockCycles`.
- Reading combinational outputs in the same delta as driving inputs — insert at least `await ClockCycles(dut.clk, 1)`.
- Printing `dut.uo_out.value` without `int(...)` — it's a `BinaryValue`, equality with int works but arithmetic does not.
- Hard-coding the clock period — derive it from `info.yaml`'s `clock_hz` if you can.

## Gate-level (GL) tests

Same `test.py` runs, but synth-only constructs (white-box probes, X comparisons) will fail. After a successful harden:

```bash
TOP_MODULE=$(cd .. && ./tt/tt_tool.py --print-top-module)
cp ../runs/wokwi/*/final/pnl/$TOP_MODULE.pnl.v gate_level_netlist.v   # sky/gf
# or .../final/nl/$TOP_MODULE.nl.v   for IHP
make -B GATES=yes
```

See [tt-gate-level-sim](../tt-gate-level-sim/SKILL.md) for failure triage.

## Debugging a failing test

1. Re-run with `make -B` (clean) to rule out stale build.
2. Open `test/sim_build/rtl/dump.vcd` (or whatever the makefile dumps) in GTKWave with `test/tb.gtkw`.
3. If the failure is in a complex module, add a `@cocotb.test()` that drives **that module's signals only** via the top — never instantiate the submodule directly in `tb.v`, that diverges from the synthesized hierarchy.
4. If the test passes RTL but fails GL, suspect: missing reset, X-propagation, undriven `uio_oe` bit. See [tt-gate-level-sim](../tt-gate-level-sim/SKILL.md).
