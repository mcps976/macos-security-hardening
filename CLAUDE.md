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
- `clamscan-quick.sh` — runs freshclam then scans key user directories (Cisco package binaries)
- `mac-security-audit.sh` — thin wrapper around `lynis audit system --quick`
  plus mdatp/system_profiler checks
- `network-monitor.sh` — one-shot snapshot using netstat, scutil, Tailscale,
  Mullvad
- `weekly-maintenance.sh` — calls mac-cleanup.sh, brew upgrade, clamscan-quick.sh;
  `--unattended` swaps the upgrade for a `brew outdated` report
- `weekly-maintenance-run.sh` — launchd wrapper: dated log under
  `~/logs/weekly-maintenance/`, ntfy digest (target from
  `~/.config/macos-security-hardening/notify.conf`, never in-repo) only when
  outdated packages / macOS updates / infections / errors exist
- `schedule-weekly-maintenance.sh` — renders `launchd/local.macos-hardening.weekly-maintenance.plist.template`
  (Sundays 10:00) and bootstraps it; `--now` kickstarts; `--remove`
- `fix-clamav.sh` — idempotent ClamAV post-install config (freshclam.conf
  incl. `UpdateLogFile`, clamd.conf, dirs, permissions)
- `schedule-freshclam.sh` — renders `launchd/local.clamav.freshclam.plist.template`
  (`__HOME__` → real home; launchd does not expand `~`) into
  `~/Library/LaunchAgents/` and bootstraps it: freshclam daily 12:00 + at login.
  `--remove` unloads. Idempotent
- `install.sh` — installs Homebrew casks and CLI tools, runs fix-clamav.sh and
  schedule-freshclam.sh, deploys scripts to ~/bin/, patches ~/.zshrc

---

## ClamAV Paths (Apple Silicon)

```
Binaries:  /usr/local/clamav/bin/   (Cisco .pkg — NOT Homebrew; see below)
Config:    /opt/homebrew/etc/clamav/
Databases: /opt/homebrew/var/lib/clamav/
Logs:      /opt/homebrew/var/log/clamav/freshclam.log   (UpdateLogFile)
           ~/logs/freshclam-launchd.log                 (LaunchAgent stdout/err)
Agent:     ~/Library/LaunchAgents/local.clamav.freshclam.plist
```

Homebrew's clamav 1.5.4_1 (OpenSSL 4.1) loads no signatures: Cisco-Talos/clamav#1887,
fix in PR #1873. The package has no config of its own, so always pass
`--config-file=/opt/homebrew/etc/clamav/freshclam.conf` to freshclam and
`--database=/opt/homebrew/var/lib/clamav` to clamscan. Each script defines
`CLAMAV_BIN`; revert it to `/opt/homebrew/bin` once Homebrew ships a fix.

Definition freshness check: `freshclam --config-file=… --version` prints `ClamAV x.y.z/DBVERSION/DATE`.

---

## Audit Report Structure

Each run of `run_full_audit.sh` creates a timestamped directory under
`~/security-audit-reports/`. Files numbered (`01-system-info.txt`,
`02-security-tools.txt`, …) with `00-summary.txt` containing critical findings.

---

## Key Constraints

- Paths use `/opt/homebrew/` (Apple Silicon) — Intel would need `/usr/local/` — except
  the ClamAV binaries, which are `/usr/local/clamav/bin` (Cisco package) on both
- Scripts using sudo: use `sudo -n` with `|| echo "requires sudo"` fallback
  to stay non-interactive — preserve this pattern (`mac-cleanup.sh`'s `privileged()`
  helper is the reference; it also does a one-time `sudo -v` when a tty exists)
- Never `brew upgrade` unattended — see README "Unattended maintenance"
- `freshclam` must run before `clamscan`; always use `--quiet` (not `-q`,
  deprecated)
- Never commit absolute `/Users/...` paths (public remote). launchd plists that
  need one are templates rendered at install time — follow the `__HOME__`
  pattern in `launchd/`
- Lynis: use `--no-colors` piped through `timeout` to prevent blocking in
  automated contexts
- New cross-platform scripts targeting Debian/Ubuntu must use bash 5.x —
  do not assume zsh or macOS-specific builtins

---

## Git Remotes

- `github` → git@github.com:mcps976/macos-security-hardening.git (public remote)
- `origin` → a private self-hosted mirror (not reachable externally)
- **Never push `main` to `github`.** The public history was squashed and shares no ancestry with `main`;
  a forced push would publish the private history. Publish a fresh commit on top of it instead:
  `git fetch github`, then
  `new=$(git commit-tree "$(git rev-parse HEAD^{tree})" -p github/main -m "describe the change")`,
  then `git push github "$new":refs/heads/main`. Match the signing of the existing public commits
  (`git commit-tree -S` if they are signed). Run the public-exposure audit afterwards (see `~/Git/README.md`).
