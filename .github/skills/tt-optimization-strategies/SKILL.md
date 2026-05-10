---
name: tt-optimization-strategies
description: 'Decide what to change in a Tiny Tapeout project to resolve a finding from tt-report-analysis: pick between RTL restructuring, info.yaml tweaks, or LibreLane config overrides, and route to the right authoring skill. USE WHEN: tt-report-analysis returned non-clean findings and the orchestrator needs the next concrete edit. Each strategy lists the trigger finding, the change to make, and the validation step. DO NOT USE FOR: parsing reports (use tt-report-analysis), or making the edit yourself when an authoring skill should own it (delegate to tt-rtl-authoring or tt-info-yaml).'
---

# Tiny Tapeout Optimization Strategies

Strategy playbook keyed off the categorical findings from [tt-report-analysis](../tt-report-analysis/SKILL.md). Each row: trigger → change → who-owns-it → how-to-verify.

## Strategy table

### RTL-level

| Finding | Likely cause | Change | Owner skill | Verify |
|---|---|---|---|---|
| `rtl-latch` | `always @*` doesn't assign every output on every path | Add `default:` to case, `else` to every `if` | tt-rtl-authoring | `--print-warnings` empty |
| `rtl-multi-driver` | Two drivers on one net | Find the duplicate `assign` / `always` | tt-rtl-authoring | synthesis log clean |
| `rtl-implicit-wire` | Typo created a 1-bit `wire` | Add ``` `default_nettype none ``` and explicit declarations | tt-rtl-authoring | re-synth |
| `sta-setup-fail` (deep combinational) | Long mux tree, wide arithmetic | Pipeline: insert a register stage at the path's midpoint | tt-rtl-authoring | new max.rpt WNS ≥ 0 |
| `sta-setup-fail` (FSM) | One-hot encoded with wide next-state | Re-encode FSM (binary or gray); register the next-state output | tt-rtl-authoring | WNS ≥ 0 |
| `sta-setup-marginal` | Tight but not failing | Try clock-period bump in `info.yaml` first (cheap), then RTL | tt-info-yaml | WNS ≥ 0 |
| `sta-hold-fail` | Pure routing/STA, almost never RTL | Re-harden — LibreLane inserts hold buffers automatically; if persists across 2 runs, escalate | tt-local-hardening | new min.rpt slack ≥ 0 |
| `congestion` (after RTL pass) | Wide muxes, large memory | Split mux tree across two cycles, or move state into smaller submodules | tt-rtl-authoring | congestion.rpt overflow = 0 |

### Config-level

| Finding | Change | Owner skill | Verify |
|---|---|---|---|
| `util-tight` (60–75 %) | First try: bump `tiles:` from 1×1 to 1×2 in `info.yaml` | tt-info-yaml | utilization < 60 % |
| `util-overflow` (> 75 %) | Bump tiles **and** review for unused registers / dead logic | tt-info-yaml + tt-rtl-authoring | utilization < 60 % |
| `sdc-missing-clock` | Set `clock_hz:` correctly in `info.yaml` | tt-info-yaml | warning gone |
| `congestion` (after util fix) | Add a tile dimension; if already ≥ 2×2, return to RTL | tt-info-yaml | congestion = 0 |

### Signoff-level

| Finding | Change | Owner skill | Verify |
|---|---|---|---|
| `drc` (small count, e.g. < 5) | Re-run `--harden` once — sometimes router placement varies | tt-local-hardening | DRC count = 0 |
| `drc` (persistent) | Usually utilization-driven; reduce density via tiles or RTL | tt-info-yaml / tt-rtl-authoring | DRC = 0 |
| `lvs` mismatch | RTL bug or a `uio_oe` left undriven; rare with TT flow | tt-rtl-authoring | `Circuits match` |
| `antenna` | LibreLane usually fixes; if it persists, escalate to user — needs config override | (escalate) | antenna_summary clean |

## Decision rules

1. **Cheap before expensive.** Order of attempts for a borderline issue: clock period → tiles → RTL restructure → LibreLane config override.
2. **One change per iteration.** Never combine an RTL edit with an `info.yaml` edit in the same harden run — you lose attribution.
3. **Match the change scope to the finding.** A single failing path is an RTL fix, not a tile bump. Global utilization is a tile bump, not an RTL rewrite.
4. **Stop conditions** (return to orchestrator, do **not** keep trying):
   - Same finding survives **2** consecutive RTL attempts → it's likely a config/PDK issue.
   - Same finding survives **2** consecutive config bumps → it's likely an RTL issue.
   - Tiles ≥ 4×2 and still tight → escalate to user; design may be too big for TT.

## Worked examples

### Setup slack failing on a deep combinational endpoint

Finding: `sta-setup-fail`, WNS negative, endpoint inside some submodule (e.g. `<submodule>/<reg>[N]`).
Action:
1. Open the offending `src/<submodule>.v`. Trace the cone of logic feeding the failing register.
2. If it's a wide OR/AND/mux tree, register the intermediate result (introduce a `pipe_reg`).
3. Update tests in `test/test.py` so any result-valid check accounts for the extra cycle of latency.
4. Hand to [tt-rtl-authoring](../tt-rtl-authoring/SKILL.md), then [tt-cocotb-testing](../tt-cocotb-testing/SKILL.md), then re-harden.

### Utilization 71 %

Finding: `util-tight`.
Action:
1. Open `info.yaml`. If `tiles: 1x1`, change to `1x2`.
2. Hand to [tt-info-yaml](../tt-info-yaml/SKILL.md) for the edit (validates schema).
3. Re-run `--create-user-config` then `--harden` via [tt-local-hardening](../tt-local-hardening/SKILL.md).

### Congestion after both util fix and an RTL split

Two iterations didn't help → stop, return to orchestrator with `no_progress: true`. Suggest the user consider dropping a feature or moving to a larger tile.

## What this skill does NOT do

- Does not edit files itself. Always delegates to [tt-rtl-authoring](../tt-rtl-authoring/SKILL.md) or [tt-info-yaml](../tt-info-yaml/SKILL.md).
- Does not re-run the harden. That is [tt-local-hardening](../tt-local-hardening/SKILL.md).
- Does not interpret the next set of reports. That is [tt-report-analysis](../tt-report-analysis/SKILL.md).
