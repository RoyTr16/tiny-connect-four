---
name: tt-environment-setup
description: 'Detect-and-install prerequisites for Tiny Tapeout local hardening: Docker, Python 3.11+, OSS CAD Suite, tt-support-tools, the LibreLane Python venv, and the SkyWater/IHP/GF180 PDK. USE WHEN: first-time setup of a TT project, errors like "docker: command not found", "ModuleNotFoundError: librelane", "PDK_ROOT not set", or any "ttsetup" path missing. Idempotent — safe to re-run. Reads the canonical LIBRELANE_TAG/PDK from tt-gds-action so it never goes stale. DO NOT USE FOR: Windows host setup of WSL itself (use tt-windows-wsl) or for re-activating an already-installed venv (just `source ~/ttsetup/venv/bin/activate`).'
---

# Tiny Tapeout Environment Setup

Idempotent prerequisite installer. Run inside Linux (native or WSL2). For Windows host setup of WSL, see [tt-windows-wsl](../tt-windows-wsl/SKILL.md) first.

## Source of truth for versions

The local-hardening guide (https://tinytapeout.com/guides/local-hardening/) explicitly says: **read `LIBRELANE_TAG` and `PDK` defaults from `tt-gds-action`'s `action.yml`** — do not hard-code them here. Fetch:

```
https://raw.githubusercontent.com/TinyTapeout/tt-gds-action/main/action.yml
```

and grep for inputs `librelane-version`, `pdk`, `pdk-version`. Use those as defaults unless the user pins different versions.

## Detect → install order

Run each check; only install if missing. Persist env vars to `~/.ttenv` at the end so future shells/skills can `source ~/.ttenv` instead of re-exporting.

### 1. Docker

```bash
docker info >/dev/null 2>&1 || echo MISSING
```

If missing:
- Inside WSL: instruct the user to install **Docker Desktop on Windows** with WSL2 integration enabled (engine cannot live cleanly inside WSL alongside Desktop). Pause — this needs user action and possibly a reboot.
- Native Linux: `curl -fsSL https://get.docker.com | sh` then `sudo usermod -aG docker $USER` and re-login.

Verify the daemon is actually running: `docker run --rm hello-world`.

### 2. Python 3.11+

```bash
python3 -c 'import sys; assert sys.version_info >= (3,11)' || echo TOO_OLD
```

If too old, prefer **uv** (no root needed):
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.11
```
otherwise on Debian/Ubuntu:
```bash
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update && sudo apt install -y python3.11 python3.11-venv
```

### 3. tt-support-tools

The TT project must contain a `tt/` subdirectory with the support tools:
```bash
cd "$PROJECT_ROOT"
[ -d tt ] || git clone https://github.com/TinyTapeout/tt-support-tools tt
```
Use `main` branch unless the project pins another.

### 4. Python venv + dependencies

```bash
mkdir -p ~/ttsetup
[ -d ~/ttsetup/venv ] || python3 -m venv ~/ttsetup/venv
source ~/ttsetup/venv/bin/activate
pip install -r "$PROJECT_ROOT/tt/requirements.txt"
pip install "librelane==$LIBRELANE_TAG"
```

### 5. PDK + env vars

Pick PDK based on `info.yaml` (`pdk:` field) or user choice — `sky130A` (default), `gf180mcuD`, or `ihp-sg13g2`.

Write `~/.ttenv`:
```bash
cat > ~/.ttenv <<EOF
export PDK_ROOT=$HOME/ttsetup/pdk
export PDK=$PDK
export LIBRELANE_TAG=$LIBRELANE_TAG
source $HOME/ttsetup/venv/bin/activate
EOF
```

The PDK itself is downloaded by LibreLane on first `--harden` — do not pre-fetch.

### 6. OSS CAD Suite (for cocotb / icarus)

Only required for RTL/gate-level simulation, not for hardening. Install if `which iverilog` fails:
```bash
mkdir -p ~/ttsetup
cd ~/ttsetup
LATEST=$(curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest | grep -oP '"tag_name": "\K[^"]+')
# pick the linux-x64 tarball for that release, extract to ~/ttsetup/oss-cad-suite
```
Append to `~/.ttenv`:
```bash
export PATH=$HOME/ttsetup/oss-cad-suite/bin:$PATH
```

### 7. Optional: PNG export deps

Only if the user wants `tt_tool.py --create-png`:
```bash
sudo apt install -y librsvg2-bin pngquant
```

## Validation

After install, run all of:
```bash
source ~/.ttenv
docker run --rm hello-world
python3 --version          # ≥ 3.11
python3 -c 'import librelane; print(librelane.__version__)'
iverilog -V | head -1
ls "$PROJECT_ROOT/tt/tt_tool.py"
```

All must succeed before handing back to [tt-project-orchestrator](../tt-project-orchestrator/SKILL.md).

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `Cannot connect to the Docker daemon` in WSL | Docker Desktop WSL integration off | Settings → Resources → WSL Integration → toggle distro on |
| `pip install librelane` hangs | Building from source w/o wheel | Pin a tagged release; ensure Python 3.11 not 3.12 |
| `tt_tool.py: command not found` | `tt/` clone missing | Re-run step 3 |
| Slow `pip install` from `/mnt/c/...` | Project on Windows filesystem | Move project to `~/` inside WSL — see [tt-windows-wsl](../tt-windows-wsl/SKILL.md) |

## Re-running

This skill is idempotent. To force a fresh install: `rm -rf ~/ttsetup ~/.ttenv` then re-run. The project's `tt/` directory is not touched by re-runs.
