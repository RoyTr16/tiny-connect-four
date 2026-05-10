---
name: tt-report-analysis
description: 'Parse and classify the reports produced by a Tiny Tapeout LibreLane harden run: STA slack, utilization, congestion, DRC, LVS, antenna, manufacturability, synthesis warnings. USE WHEN: a harden run completes (clean or not) and the orchestrator needs structured findings, or the user asks "is my design clean / what failed / why is slack negative". Produces a list of findings with severity, file path, and a suggested category that tt-optimization-strategies can act on. DO NOT USE FOR: choosing what to do about a finding (use tt-optimization-strategies), running the harden (use tt-local-hardening), or RTL editing (use tt-rtl-authoring).'
---

# Tiny Tapeout Report Analysis

The "read and classify" half of the autonomous loop. Output a structured list of findings; do **not** decide fixes — that is [tt-optimization-strategies](../tt-optimization-strategies/SKILL.md)'s job.

## Where reports live

After `tt_tool.py --harden`, results are under:

```
runs/wokwi/<TIMESTAMP>/        # symlinked as runs/wokwi/latest or similar
├── final/
│   ├── gds/<top>.gds
│   ├── pnl/<top>.pnl.v        # sky/gf: powered netlist
│   ├── nl/<top>.nl.v          # ihp:    unpowered netlist
│   └── metrics.csv            # one-line summary
├── reports/
│   ├── manufacturability.rpt
│   ├── synthesis/
│   │   ├── 1-synthesis.stat.rpt
│   │   └── *-synthesis.warnings.rpt
│   ├── floorplan/
│   ├── placement/
│   ├── routing/
│   │   ├── *-detailed-route.drc
│   │   └── congestion.rpt
│   ├── signoff/
│   │   ├── sta-rcx_*/         # per-corner STA
│   │   │   ├── *.min.rpt      # hold
│   │   │   ├── *.max.rpt      # setup
│   │   │   └── summary.rpt
│   │   ├── magic.drc
│   │   ├── lvs.rpt
│   │   └── antenna_summary.rpt
│   └── metrics.json
└── logs/<step>.log            # full step output
```

Always start with `final/metrics.csv` and `reports/metrics.json` — they summarize 80% of the run in one line each.

## Top-level checks (in order)

Run these as a triage; bail out at the first failing layer **only for the orchestrator's pass/fail decision**, but for the loop, collect ALL findings before returning.

### 1. Did synthesis warn?

Source: `./tt/tt_tool.py --print-warnings` output, plus `reports/synthesis/*.warnings.rpt`.

Patterns to flag:
| Regex / phrase | Severity | Category |
|---|---|---|
| `inferring latch for` | **error** | rtl-latch |
| `multiple drivers` / `multi-driven` | **error** | rtl-multi-driver |
| `sensitivity list` | warn | rtl-sensitivity |
| `wire .* is implicitly declared` | warn | rtl-implicit-wire |
| `assigning constant to .* output` | info | rtl-tied-output |
| `clock .* not constrained` | **error** | sdc-missing-clock |

### 2. STA — setup & hold slack

Source: `reports/signoff/sta-rcx_*/*.max.rpt` (setup) and `*.min.rpt` (hold), per corner.

Find the **worst** WNS (Worst Negative Slack) across all corners:

```bash
grep -h '^slack' reports/signoff/sta-rcx_*/*.max.rpt | sort -k2 -n | head -1
grep -h '^slack' reports/signoff/sta-rcx_*/*.min.rpt | sort -k2 -n | head -1
```

| Slack | Severity | Category |
|---|---|---|
| setup ≥ 0 | clean | — |
| setup < 0, > -0.5 ns | warn | sta-setup-marginal |
| setup ≤ -0.5 ns | **error** | sta-setup-fail |
| hold ≥ 0 | clean | — |
| hold < 0 | **error** | sta-hold-fail |

Always report the **failing endpoint path** verbatim — it points the optimization skill at the right register.

### 3. Utilization

Source: `reports/metrics.json` → key `design__instance__utilization` or `OpenROAD-floorplan: util:` in `logs/openroad-floorplan.log`.

| Util | Severity | Category |
|---|---|---|
| < 60 % | clean | — |
| 60–75 % | warn | util-tight |
| > 75 % | **error** | util-overflow |

### 4. Congestion

Source: `reports/routing/congestion.rpt` or `reports/metrics.json` → `route__overflow__*`.

Any non-zero overflow on `H` or `V` layers → **error**, category `congestion`.

### 5. DRC (detailed route + magic)

Sources:
- `reports/routing/*-detailed-route.drc` (router-time)
- `reports/signoff/magic.drc` (signoff)

Count violations:
```bash
wc -l reports/signoff/magic.drc
```
Anything > 0 → **error**, category `drc`. Capture the first 5 violation types verbatim.

### 6. LVS

Source: `reports/signoff/lvs.rpt`. Look for `Final result:`. Anything other than `Circuits match` → **error**, category `lvs`.

### 7. Antenna

Source: `reports/signoff/antenna_summary.rpt`. Any reported violations → **error**, category `antenna`.

### 8. Manufacturability

Source: `reports/manufacturability.rpt`. Treat as **info** unless it explicitly says FAIL.

## Output format

Return a JSON-ish list the orchestrator and optimization skill can consume:

```yaml
findings:
  - category: sta-setup-fail
    severity: error
    file: runs/wokwi/2025-11-13_12-34-56/reports/signoff/sta-rcx_nom_tt_025C_1v80/multi_corner.max.rpt
    detail: "WNS = -0.412 ns at endpoint <module>/<reg>[N]"
  - category: util-tight
    severity: warn
    file: runs/wokwi/.../reports/metrics.json
    detail: "utilization = 0.71"
clean: false
worst_severity: error
```

`clean: true` only if **zero** findings of severity `warn` or `error` AND `--print-warnings` produced no output.

## Comparing against a previous run

The orchestrator's no-progress guard needs run-over-run diffs. Save findings to `.tt-history/<TIMESTAMP>.yaml`. Compare current vs. previous by `(category, detail-without-numbers)` set — if identical, signal `no_progress: true` to the orchestrator.

## Sanity checks before reporting findings

- Confirm the run actually completed: `runs/wokwi/<latest>/final/gds/` is non-empty.
- Confirm the timestamp is from *this* invocation, not a stale prior run.
- If `metrics.json` is missing, the run aborted mid-flow — point to the last `logs/*.log` by mtime instead.

## Handoff

Pass findings to [tt-optimization-strategies](../tt-optimization-strategies/SKILL.md). For RTL-category findings (`rtl-*`), it will route to [tt-rtl-authoring](../tt-rtl-authoring/SKILL.md). For config-level findings (`util-*`, `sdc-*`), it will edit `info.yaml` via [tt-info-yaml](../tt-info-yaml/SKILL.md).
