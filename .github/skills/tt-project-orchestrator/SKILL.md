---
name: tt-project-orchestrator
description: 'Top-level autonomous loop for developing a Tiny Tapeout (TT) ASIC project end-to-end. USE WHEN: starting a new TT design iteration, asked to "make my TT project pass", "harden and fix until clean", "iterate on this design", or running an unattended improve-and-reharden loop. Coordinates RTL authoring, cocotb testing, local hardening, report analysis, and optimization. Knows the phase order, success criteria, and stop conditions to avoid burning cycles on unfixable problems. DO NOT USE FOR: single-shot tasks (use the specific skill directly: tt-cocotb-testing, tt-local-hardening, tt-report-analysis, etc.).'
---

# Tiny Tapeout Project Orchestrator

The autonomous loop that drives a TT project from "compiles" to "hardened and clean".
Delegates every phase to a focused skill — this file only owns *order*, *gating*, and *stop conditions*.

## Phase order

```
0. platform check        → tt-windows-wsl       (only if uname != Linux)
1. environment setup     → tt-environment-setup (idempotent, runs once per shell)
2. RTL authoring/edits   → tt-rtl-authoring
3. RTL simulation        → tt-cocotb-testing       (must pass before harden)
4. local hardening       → tt-local-hardening
5. report analysis       → tt-report-analysis      (parse + classify findings)
6. optimization          → tt-optimization-strategies (act on findings)
7. gate-level simulation → tt-gate-level-sim       (after a successful harden)
```

Any change to `info.yaml` pin map / tile count / clock period requires re-running `--create-user-config` (handled by [tt-local-hardening](../tt-local-hardening/SKILL.md)).

## Loop

```text
ensure_environment()                       # phase 0–1, once
loop:
    if rtl_changed: run tt-cocotb-testing
    if not tests_pass: run tt-rtl-authoring; continue
    run tt-local-hardening (--harden, --print-warnings)
    findings = run tt-report-analysis
    if findings.is_clean(): break
    if findings == previous_findings: STOP and report   # no progress guard
    run tt-optimization-strategies(findings)
    previous_findings = findings
run tt-gate-level-sim                                  # final confidence check
```

## Success criteria (move to next phase only if ALL true)

| Phase | Gate to advance |
|---|---|
| RTL sim | All cocotb tests pass on `make -B` (RTL build). |
| Hardening | `tt_tool.py --harden` exits 0; `--print-warnings` prints no synthesis/clock warnings. |
| Reports | Setup slack ≥ 0, hold slack ≥ 0, no DRC violations, no LVS mismatches, no antenna violations, utilization within target. |
| Gate-level sim | All cocotb tests pass on `make -B GATES=yes`. |

## Stop-and-report conditions (do NOT keep iterating)

- **No progress**: same set of report findings two iterations in a row.
- **Regression**: a previously passing test now fails after an optimization.
- **Unrecoverable env error**: Docker daemon down, PDK missing, `librelane` import fails — escalate to [tt-environment-setup](../tt-environment-setup/SKILL.md).
- **User intent ambiguity**: a finding requires a design trade-off (e.g. drop a feature to fit) — surface to the user, don't decide silently.
- **Hard cap**: 5 full hardening iterations without convergence.

When stopping, emit a short report:
- last finding set,
- attempted strategies and their outcomes,
- the file/path of the most relevant report.

## Decision rules

- **Never harden if RTL tests fail** — wastes ~10 min per harden run.
- **Never edit `info.yaml` and `src/` in the same iteration** — split so cause/effect on reports is attributable.
- **Always re-run `--create-user-config` before `--harden`** if `info.yaml` was touched.
- **Prefer RTL fixes over LibreLane config tweaks** when both could resolve a finding — RTL fixes are portable.

## Handoff protocol

When invoking a sub-skill, pass:
1. The current phase name.
2. The triggering finding (if any) verbatim, including report file path.
3. Whether this is a retry (and the prior attempt's diff summary).

## What this skill does NOT do

- Does not execute commands itself — every command lives in a sub-skill.
- Does not interpret reports — that is [tt-report-analysis](../tt-report-analysis/SKILL.md)'s job.
- Does not pick optimizations — that is [tt-optimization-strategies](../tt-optimization-strategies/SKILL.md)'s job.
