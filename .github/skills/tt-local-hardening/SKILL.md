---
name: tt-local-hardening
description: 'Run the LibreLane local hardening flow for a Tiny Tapeout project: --create-user-config, --harden, --print-warnings, plus --open-in-openroad / --open-in-klayout / --create-png. USE WHEN: RTL tests pass and the orchestrator wants a hardened GDS, after info.yaml changes (re-create user config), or when re-hardening after an optimization. Knows the --ihp / --gf flags, that the venv + env vars must be sourced first, and how to detect a stalled Docker daemon. DO NOT USE FOR: interpreting the resulting reports (use tt-report-analysis), changing RTL (use tt-rtl-authoring), or first-time install (use tt-environment-setup).'
---

# Tiny Tapeout Local Hardening

Single source of truth for the `tt_tool.py` invocations. Always sourced via [tt-environment-setup](../tt-environment-setup/SKILL.md) first.

## Preflight

```bash
source ~/.ttenv                  # written by tt-environment-setup
cd "$PROJECT_ROOT"
[ -d tt ] || { echo "tt/ missing — run tt-environment-setup"; exit 1; }
docker info >/dev/null || { echo "Docker daemon not running"; exit 1; }
```

If `~/.ttenv` doesn't exist → invoke [tt-environment-setup](../tt-environment-setup/SKILL.md) and stop.

## PDK flag

`tt_tool.py` defaults to sky130. For other PDKs, **every** invocation needs a flag:

| PDK | Flag |
|---|---|
| `sky130A` | (none) |
| `gf180mcuD` | `--gf` |
| `ihp-sg13g2` | `--ihp` |

Read the PDK from `info.yaml` (`pdk:` field) or `$PDK`. Set `TT_FLAG` once and reuse:

```bash
case "$PDK" in
  sky130A) TT_FLAG="" ;;
  gf180*)  TT_FLAG="--gf" ;;
  ihp*)    TT_FLAG="--ihp" ;;
esac
```

## Commands

### Generate the LibreLane user config

```bash
./tt/tt_tool.py $TT_FLAG --create-user-config
```

**Run this whenever `info.yaml` changes** (tile count, clock, pinout). Outputs the generated config under `src/config_merged.json` (or similar — check `tt/`).

### Harden

```bash
./tt/tt_tool.py $TT_FLAG --harden
```

This invokes LibreLane in Docker. Takes roughly 5–15 min on sky130 for a 1-tile design. Output:

```
runs/wokwi/<RUN_TIMESTAMP>/
    final/
        gds/        — the GDS
        pnl/        — powered netlist  (sky/gf)
        nl/         — unpowered netlist (ihp)
    reports/        — STA, DRC, manufacturability, metrics
    logs/           — full step-by-step logs
```

The `runs/wokwi/` symlink (or `latest` dir) points to the most recent run.

### Print warnings (mandatory after every harden)

```bash
./tt/tt_tool.py $TT_FLAG --print-warnings
```

Surfaces synthesis and clock warnings that LibreLane buries in step logs. **Empty output = clean.** Any output is treated as a finding by [tt-report-analysis](../tt-report-analysis/SKILL.md).

### Inspect

```bash
./tt/tt_tool.py $TT_FLAG --open-in-openroad   # GUI; needs X11/WSLg
./tt/tt_tool.py $TT_FLAG --open-in-klayout    # GUI
./tt/tt_tool.py $TT_FLAG --create-png         # gds_render.png; needs librsvg2-bin + pngquant
```

### Helpers

```bash
./tt/tt_tool.py --print-top-module            # for the GL-sim copy step
./tt/tt_tool.py --help                        # full flag list
```

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `docker: Cannot connect to the Docker daemon` | Docker Desktop not running / WSL integration off | Start Docker Desktop; see [tt-windows-wsl](../tt-windows-wsl/SKILL.md) |
| `librelane: command not found` | venv not activated | `source ~/.ttenv` |
| `KeyError: 'PDK'` | env vars missing | `source ~/.ttenv` |
| `--harden` fails immediately, no run dir | `info.yaml` invalid | `./tt/tt_tool.py --create-user-config` first; fix yaml errors |
| `step synthesis: latch inferred` | RTL bug | Hand to [tt-rtl-authoring](../tt-rtl-authoring/SKILL.md) |
| `step floorplanning: utilization > 1.0` | Design too big for tile count | Bump `tiles:` in `info.yaml`, re-create-user-config, re-harden |
| `step routing: congestion` or `DRC violations` | Layout too dense | See [tt-optimization-strategies](../tt-optimization-strategies/SKILL.md) |

## After a successful harden

1. Run `--print-warnings`.
2. Hand off to [tt-report-analysis](../tt-report-analysis/SKILL.md) with the run directory path.
3. If reports clean → optionally run gate-level sim via [tt-gate-level-sim](../tt-gate-level-sim/SKILL.md).
4. Return control to [tt-project-orchestrator](../tt-project-orchestrator/SKILL.md).

## Re-hardening after a change

| What changed | Required steps |
|---|---|
| Only `src/*.v` (no port changes) | `--harden` |
| `info.yaml` (clock, tiles, pinout, sources) | `--create-user-config` then `--harden` |
| `tt/` updated (rare) | `--create-user-config` then `--harden` |
| `LIBRELANE_TAG` bumped | `pip install librelane==$LIBRELANE_TAG` then `--create-user-config` then `--harden` |
