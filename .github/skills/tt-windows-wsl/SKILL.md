---
name: tt-windows-wsl
description: 'Windows-host setup for Tiny Tapeout development: install/configure WSL2 + Ubuntu, install Docker Desktop with WSL2 backend, reopen the workspace in VS Code WSL Remote, and place the project on the Linux filesystem. USE WHEN: the user is on Windows and wants to run a TT hardening/sim flow, getting errors like "docker: not found" on PowerShell, slow performance from /mnt/c paths, or "X server" errors from --open-in-openroad. Returns control to tt-environment-setup once the workspace is reopened in WSL. DO NOT USE FOR: native Linux/macOS setups, or when VS Code is already connected to WSL (uname says Linux).'
---

# Tiny Tapeout on Windows via WSL

LibreLane, Docker images, and the TT toolchain all assume Linux. **Do not try to run hardening from PowerShell.** The strategy: get a WSL2 Ubuntu, install Docker Desktop, and reopen the workspace in VS Code's WSL Remote — then every other TT skill can assume Linux.

## Detect

In a terminal, this skill is needed if any of these are true:
- `$env:OS -eq 'Windows_NT'` in PowerShell.
- `uname -s` is not available, or returns something other than `Linux`.
- The workspace path starts with a drive letter (`C:\...`) when running TT commands.

If `uname -s` already returns `Linux` and the workspace path starts with `/home/` or `/root/`, this skill is **not needed** — proceed to [tt-environment-setup](../tt-environment-setup/SKILL.md).

## Steps

### 1. Install WSL2 + Ubuntu

In an **admin PowerShell**:
```powershell
wsl --install -d Ubuntu
wsl --set-default-version 2
```
Reboot if prompted. Launch Ubuntu once to create the Linux user.

### 2. Install Docker Desktop

Download from https://www.docker.com/products/docker-desktop/ and install. After install:
- Open Docker Desktop → Settings → **General** → "Use the WSL 2 based engine" ✅
- Settings → **Resources → WSL Integration** → enable for the Ubuntu distro.
- Restart Docker Desktop.

Verify from inside WSL:
```bash
docker run --rm hello-world
```

### 3. Install the VS Code WSL extension

Extension ID: `ms-vscode-remote.remote-wsl`.

### 4. Move the project to the Linux filesystem

**Critical for performance.** Building/hardening from `/mnt/c/...` is 5–20× slower and triggers file-watcher bugs. Inside WSL:

```bash
mkdir -p ~/projects
cd ~/projects
git clone <your-repo-url> <project-name>    # or move existing
```

If the project currently lives on Windows and has uncommitted work, commit/stash first, then re-clone in WSL — do not just `cp -r /mnt/c/...`, line endings and permissions will bite you.

### 5. Reopen the workspace in WSL

In VS Code: `Ctrl+Shift+P` → **"WSL: Open Folder in WSL"** → pick `~/projects/<project-name>`.

After this, the integrated terminal is bash inside Ubuntu, and `uname -s` returns `Linux`. Every other TT skill now works.

### 6. (Optional) X11 for OpenROAD/KLayout GUI

WSLg (Windows 11) supports GUI apps natively — no setup needed. On Windows 10, install VcXsrv and:
```bash
echo 'export DISPLAY=$(ip route list default | awk "{print \$3}"):0' >> ~/.bashrc
```
Then `xhost +local:docker` before `tt_tool.py --open-in-openroad`.

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `docker` works in PowerShell but not WSL | WSL integration disabled for the distro | Docker Desktop → Resources → WSL Integration |
| Files appear with `\r\n` endings, makefiles fail | Cloned on Windows, edited there | `git config --global core.autocrlf input` then re-clone in WSL |
| `make` is missing | Fresh Ubuntu | `sudo apt install -y build-essential git curl` |
| Permission errors on `~/ttsetup` | Created with root via `sudo` | `sudo chown -R $USER:$USER ~/ttsetup` |
| Hardening takes hours | Project on `/mnt/c/...` | Move to `~/...` (step 4) |

## Handoff

Once `uname -s` is `Linux`, the workspace is at `~/...`, and `docker run --rm hello-world` succeeds → invoke [tt-environment-setup](../tt-environment-setup/SKILL.md).
