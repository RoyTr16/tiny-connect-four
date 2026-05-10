---
name: tt-info-yaml
description: 'Edit and validate info.yaml for a Tiny Tapeout project: source_files, top_module, pinout (ui_in/uo_out/uio), tiles, clock_hz, pdk, and project metadata. USE WHEN: a new .v file was added, the top module port list / pin assignment changed, the design needs more area (tile bump), the clock period changed, or tt_tool.py reports a yaml/schema error. Knows which fields force a re-run of --create-user-config. DO NOT USE FOR: changing RTL itself (use tt-rtl-authoring), running tt_tool.py (use tt-local-hardening), or docs/info.md edits.'
---

# Tiny Tapeout `info.yaml`

Single source of truth for the project's metadata, pinout, and physical configuration. The TT migration tool lives at https://tinytapeout.github.io/tt-yaml-upgrade-tool/ — when the schema changes, run the project through it instead of hand-patching.

## Schema (current TT shuttles)

```yaml
# Tiny Tapeout project information
project:
  title:        "<project title>"            # ≤ 35 chars
  author:       "<author name>"
  discord:      ""                           # optional
  description:  "1-line summary of the chip"
  language:     "Verilog"                    # or "VHDL", "Wokwi", ...
  clock_hz:     50000000                     # target clock; LibreLane uses this for SDC
  tiles:        "1x1"                        # "1x1", "1x2", "2x2", "3x2", "4x2", "8x2", ...
  pdk:          "sky130A"                    # sky130A | gf180mcuD | ihp-sg13g2
  top_module:   "tt_um_<author>_<project>"   # must match the module name in src/
  source_files:                              # every src/*.v that is part of the design
    - "tt_um_<author>_<project>.v"
    - "<submodule_a>.v"
    - "<submodule_b>.v"
    # ...

# Pinout — names that show up in the demoboard UI / docs
pinout:
  ui[0]:   "select column low"
  ui[1]:   "..."
  ui[7]:   "..."
  uo[0]:   "vga r1"
  # ...
  uio[0]:  "..."
  # ...
```

## Field-by-field rules

| Field | Constraints | Re-run `--create-user-config`? |
|---|---|---|
| `title`, `author`, `description`, `discord` | docs only | no |
| `language` | enum | no |
| `clock_hz` | integer Hz; this is the **target**, not max | **yes** |
| `tiles` | one of the supported sizes; bigger = more area = longer harden | **yes** |
| `pdk` | enum; changes which `--gf`/`--ihp` flag the harden needs | **yes** (and re-install LibreLane corner files) |
| `top_module` | must equal the module name in `src/`, must start with `tt_um_` | **yes** |
| `source_files` | list of file basenames in `src/`; order doesn't matter; do not include `.v` files that are sim-only | **yes** |
| `pinout.ui[N]` / `uo[N]` / `uio[N]` | strings; documented in the demoboard | no (cosmetic) but update docs |

## Common edits

### Added a new `.v` file

```yaml
project:
  source_files:
    - "tt_um_<author>_<project>.v"
    - "...existing..."
    - "my_new_module.v"     # ← add here
```
Also update `test/Makefile`'s `PROJECT_SOURCES` (see [tt-cocotb-testing](../tt-cocotb-testing/SKILL.md)).

### Bumping tiles for utilization

```yaml
project:
  tiles: "1x2"   # was "1x1"
```
Then `--create-user-config` then `--harden`.

### Changing the clock target

```yaml
project:
  clock_hz: 25000000   # halved to give STA more headroom
```
**Caution**: changing this changes the user-visible clock spec. Prefer RTL pipelining for slack issues; only relax the clock if the spec genuinely allows it.

### Renaming a pin label

```yaml
pinout:
  ui[0]: "player_1_select_column"
```
Cosmetic — also update `docs/info.md` so the docs match.

## Validation

There is no offline schema validator that ships with the project. The fastest validation is:

```bash
./tt/tt_tool.py --create-user-config
```

If it exits 0, the yaml is valid. Errors are printed verbatim — common ones:

| Error | Fix |
|---|---|
| `top_module 'X' not found in source_files` | Add the file; check capitalization |
| `tiles: invalid value 'NxM'` | Use one of the supported sizes |
| `pdk: must be one of [...]` | Use canonical PDK name |
| YAML parse error on a quoted pin label | Escape colons, or wrap in single quotes |

## Anti-patterns

- Listing **testbench files** in `source_files` — the harden flow will try to synthesize them and fail.
- Hand-editing `clock_hz` to chase slack instead of fixing RTL.
- Bumping `tiles` to `8x2` "just in case" — wastes silicon and lengthens the harden by 5×.
- Changing `top_module` without renaming the actual module in `src/` and `test/tb.v`.

## Handoff

After a successful edit, hand control to [tt-local-hardening](../tt-local-hardening/SKILL.md) to run `--create-user-config` and (usually) `--harden`.
