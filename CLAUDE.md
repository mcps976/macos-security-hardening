# CLAUDE.md — macos-security-hardening

> For infrastructure context (hardware, networking, IPs, services) see ~/Git/CLAUDE.md

---

## Project Overview

A macOS security and maintenance toolkit integrating open-source tools
(ClamAV, Lynis, LuLu, OverSight, BlockBlock, etc.) into a cohesive set of
shell scripts for security hardening, malware scanning, system cleanup, and
auditing. Target: MacBook Pro M3 Pro (Apple Silicon).

---

## Common Commands

### Installation
```bash
chmod +x install.sh
./install.sh
source ~/.zshrc
```

### Running Scripts
```bash
./scripts/run_full_audit.sh      # Full audit — saves to ~/security-audit-reports/YYYYMMDD-HHMMSS/
~/bin/mac-cleanup.sh             # Caches, logs, Homebrew orphans, DNS flush
~/bin/clamscan-quick.sh          # Update ClamAV defs + scan Downloads/Documents/Desktop
~/bin/mac-security-audit.sh      # Quick Lynis audit + key security checks
~/bin/network-monitor.sh         # Connections, listening services, VPN, DNS
~/bin/weekly-maintenance.sh      # cleanup → brew upgrade → clamscan
```

### Shell Linting
```bash
shellcheck scripts/*.sh          # Requires: brew install shellcheck
```

---

## Architecture

All scripts live in `scripts/` and are deployed to `~/bin/` by `install.sh`,
which also registers shell aliases in `~/.zshrc`.

**Script roles:**
- `run_full_audit.sh` — orchestrates 30+ security checks, writes numbered
  report files and a `00-summary.txt`
- `mac-cleanup.sh` — cache purge, DNS flush, Homebrew cleanup, memory purge
- `clamscan-quick.sh` — runs freshclam then scans key user directories
- `mac-security-audit.sh` — thin wrapper around `lynis audit system --quick`
  plus mdatp/system_profiler checks
- `network-monitor.sh` — one-shot snapshot using netstat, scutil, Tailscale,
  Mullvad
- `weekly-maintenance.sh` — calls mac-cleanup.sh, brew upgrade, clamscan-quick.sh
- `fix-clamav.sh` — idempotent ClamAV post-install config (freshclam.conf,
  clamd.conf, dirs, permissions)
- `install.sh` — installs Homebrew casks and CLI tools, runs fix-clamav.sh,
  deploys scripts to ~/bin/, patches ~/.zshrc

---

## ClamAV Paths (Apple Silicon)

```
Config:    /opt/homebrew/etc/clamav/
Databases: /opt/homebrew/var/lib/clamav/
Logs:      /opt/homebrew/var/log/
```

---

## Audit Report Structure

Each run of `run_full_audit.sh` creates a timestamped directory under
`~/security-audit-reports/`. Files numbered (`01-system-info.txt`,
`02-security-tools.txt`, …) with `00-summary.txt` containing critical findings.

---

## Key Constraints

- All paths use `/opt/homebrew/` (Apple Silicon) — Intel would need `/usr/local/`
- Scripts using sudo: use `sudo -n` with `|| echo "requires sudo"` fallback
  to stay non-interactive — preserve this pattern
- `freshclam` must run before `clamscan`; always use `--quiet` (not `-q`,
  deprecated)
- Lynis: use `--no-colors` piped through `timeout` to prevent blocking in
  automated contexts
- New cross-platform scripts targeting Debian/Ubuntu must use bash 5.x —
  do not assume zsh or macOS-specific builtins

---

## Git Remotes

- `origin` → git@github.com:mcps976/macos-security-hardening.git
- `truenas` → truenas:/mnt/tank/git-repos/macos-security-hardening.git
