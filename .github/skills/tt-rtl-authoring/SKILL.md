---
name: tt-rtl-authoring
description: 'Write or modify synthesizable Verilog for a Tiny Tapeout project. USE WHEN: adding/changing logic in src/, creating a new module, fixing a bug found by cocotb tests, or responding to a synthesis warning (latch inferred, multi-driven net, undriven output). Enforces TT pinout conventions (tt_um_* top, ui_in/uo_out/uio_*), synchronous reset style, async-input synchronizers, and avoidance of constructs that fail in OpenLane/LibreLane synthesis. DO NOT USE FOR: testbench code (use tt-cocotb-testing), info.yaml edits (use tt-info-yaml), or post-hardening optimization (use tt-optimization-strategies).'
---

# Tiny Tapeout RTL Authoring

Rules for writing Verilog that survives both cocotb sim and LibreLane synthesis on the TT flow.

## Top module contract

Every TT project has exactly one top module named `tt_um_<author>_<project>` in `src/tt_um_*.v`. Its port list is fixed:

```verilog
module tt_um_example (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional input path
    output wire [7:0] uio_out,  // bidirectional output path
    output wire [7:0] uio_oe,   // bidirectional enable (1 = output)
    input  wire       ena,      // always 1 when design selected
    input  wire       clk,
    input  wire       rst_n     // active-low reset
);
```

Do **not** rename, reorder, or change widths of these ports. Drive `uio_oe` deterministically — never leave bits floating. Tie unused outputs to `0` and unused `uio_oe` bits to `0`.

## Mandatory patterns

### Reset

Reset is **active-low, asynchronous-assert / synchronous-deassert** is acceptable, but the simplest portable form is fully synchronous:

```verilog
always @(posedge clk) begin
    if (!rst_n) state <= '0;
    else        state <= next_state;
end
```

Never reset to `'x`. Never use `initial` for synthesizable state — only for sim-only constructs.

### Async input synchronizer

Any signal coming from `ui_in` / `uio_in` that crosses into `clk` domain and is asynchronous (button, external clock, etc.) **must** go through a 2-flop synchronizer. See `src/pwrup_synchronizer.v` and `src/btn_debounce.v` in this repo for the pattern.

```verilog
reg [1:0] sync;
always @(posedge clk) sync <= {sync[0], async_in};
wire safe = sync[1];
```

### No latches

Every `always @*` must assign every output on every path. Use a `default:` in case statements and an `else` on every `if`. The synthesis log will warn `inferring latch for ...` — fix immediately, don't defer.

### No multi-driven nets

Every `wire` / `reg` has exactly one driver. Multiple `assign` statements to the same wire, or two `always` blocks writing the same `reg`, will fail synthesis.

### No combinational loops

A signal cannot depend on itself without a flop in between. If you need a feedback path, register it.

## Forbidden constructs

| Construct | Why | Use instead |
|---|---|---|
| `initial` for state | Not synthesizable on sky130 flow | Reset to known value |
| `#delay` outside testbench | Ignored / errors | Pure RTL |
| `real`, `time`, `event` | Not synthesizable | Integer types |
| `fork`/`join` in RTL | Sim-only | Sequential `always` |
| `assign` to `reg`, `<=` to `wire` | Type confusion | Match LHS type |
| Unsized literals (`'1`, `'0`) on wide buses without context | Width inference bugs | `8'hFF`, `{8{1'b0}}` |
| Memory inferred from `reg [N:0] mem [M:0]` larger than ~256 entries | Will not fit a TT tile | Use multiple tiles or external memory |

## Tile budget

A single TT tile is small (~160×100 µm on sky130A, ≈1k standard cells effective). If your design needs more, bump `tiles:` in `info.yaml` (see [tt-info-yaml](../tt-info-yaml/SKILL.md)) and re-run `--create-user-config`. Do not silently exceed the budget — the report-analysis skill will catch utilization > 60% as a warning.

## Editing checklist

When changing `src/`:

1. Did the **port list** of the top module change? → update `info.yaml` `pinout:` (see [tt-info-yaml](../tt-info-yaml/SKILL.md)).
2. Did you add a **new `.v` file**? → add it to `info.yaml` `source_files:` AND to `test/Makefile`'s `PROJECT_SOURCES`.
3. Did you change **observable behavior**? → add/update a cocotb test (see [tt-cocotb-testing](../tt-cocotb-testing/SKILL.md)).
4. Did you change `docs/info.md` if the user-facing description changed?

## When done

Hand back to [tt-cocotb-testing](../tt-cocotb-testing/SKILL.md) to verify the change, then to [tt-project-orchestrator](../tt-project-orchestrator/SKILL.md) to continue the loop.
