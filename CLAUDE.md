# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS security and maintenance toolkit that integrates open-source tools (ClamAV, Lynis, LuLu, OverSight, BlockBlock, etc.) into a cohesive set of shell scripts for security hardening, malware scanning, system cleanup, and auditing.

## Common Commands

### Installation
```bash
chmod +x install.sh
./install.sh
source ~/.zshrc
```

### Running Scripts Directly
```bash
./scripts/run_full_audit.sh          # Full automated audit — saves reports to ~/security-audit-reports/YYYYMMDD-HHMMSS/
~/bin/mac-cleanup.sh                  # System cleanup (caches, logs, Homebrew, DNS flush)
~/bin/clamscan-quick.sh              # ClamAV scan of ~/Downloads, ~/Documents, ~/Desktop
~/bin/mac-security-audit.sh         # Quick Lynis audit + key security checks
~/bin/network-monitor.sh            # Network connections, listening services, VPN, DNS
~/bin/weekly-maintenance.sh         # cleanup + brew upgrade + clamav scan
```

### Shell Linting
```bash
shellcheck scripts/*.sh              # Requires: brew install shellcheck
```

## Architecture

All scripts live in `scripts/` and are copied to `~/bin/` by `install.sh`, which also registers shell aliases in `~/.zshrc`.

**Script roles:**
- `run_full_audit.sh` — orchestrates 30+ security checks, writes numbered report files and a `00-summary.txt`
- `mac-cleanup.sh` — system cleanup (cache purge, DNS flush, Homebrew cleanup, memory purge)
- `clamscan-quick.sh` — updates ClamAV definitions via `freshclam`, then scans key user directories
- `mac-security-audit.sh` — thin wrapper around `lynis audit system --quick` plus `mdatp`/`system_profiler` checks
- `network-monitor.sh` — one-shot network snapshot using `netstat`, `scutil`, Tailscale, Mullvad
- `weekly-maintenance.sh` — calls `mac-cleanup.sh`, `brew upgrade`, and `clamscan-quick.sh` in sequence
- `fix-clamav.sh` — idempotent ClamAV post-install config (creates `freshclam.conf`, `clamd.conf`, dirs, permissions)
- `install.sh` — installs Homebrew casks and CLI tools, runs `fix-clamav.sh`, deploys scripts to `~/bin/`, patches `~/.zshrc`

**ClamAV config paths (Apple Silicon):**
- Config: `/opt/homebrew/etc/clamav/`
- Databases: `/opt/homebrew/var/lib/clamav/`
- Logs: `/opt/homebrew/var/log/`

**Audit report structure:** Each run of `run_full_audit.sh` creates a timestamped directory under `~/security-audit-reports/`. Files are numbered (`01-system-info.txt`, `02-security-tools.txt`, …) with `00-summary.txt` containing critical findings.

## Key Constraints

- All scripts target **Apple Silicon Macs** (paths use `/opt/homebrew/`). Intel Mac paths (`/usr/local/`) would need adjustment.
- Scripts require `sudo` for certain operations (FileVault, SIP checks, memory purge). The audit script uses `sudo -n` with `|| echo "requires sudo"` fallbacks — preserve this pattern to keep the script non-interactive.
- `freshclam` must be called before `clamscan`; always use `--quiet` (not `-q`, which is deprecated).
- Lynis runs use `--no-colors` and piped through `timeout` to prevent blocking in automated contexts.
- New cross-platform scripts (anything intended to run on Debian/Ubuntu nodes) must target **bash 5.x** — do not assume zsh or macOS-specific builtins.

## Infrastructure Context

Understanding the broader environment is useful when scripts check VPN status, DNS, network connections, or remote services.

**Network / Security Layer**
- **OPNsense** on Protectli VP2420 — Suricata IDS/IPS, Unbound DNS resolver, HAProxy reverse proxy
- **Tailscale** mesh VPN for remote access across all devices
- **Mullvad** VPN client running on all devices

**Storage / Self-Hosted Services**
- **TrueNAS** on Terramaster F4-423 — primary NAS; runs Dockge (container manager) hosting the full ARR stack (Sonarr, Radarr, Lidarr, Prowlarr, Jellyfin, Jellyseerr, Audiobookshelf, Homarr), Nextcloud, and SMB shares

**Workstations**
- **MacBook Pro M3 Pro** — primary Mac workstation (this repo's primary target)
- **Beelink SER** running Debian KDE — primary Linux workstation
- **Beelink** (separate unit) running Ubuntu — Bitcoin node with Mempool.space and Alby Hub

## Git Remotes

| Remote | Location | Purpose |
|--------|----------|---------|
| `origin` | GitHub (`mcps976`) | Public/shared source of truth |
| `truenas` | `/mnt/tank/git-repos/<repo>.git` on TrueNAS | Local bare repo backup |

Push to both remotes when changes should be preserved locally: `git push origin && git push truenas`.
