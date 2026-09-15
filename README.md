# macOS Security Hardening Stack

Open-source security and maintenance toolkit for macOS. Complete replacement for CleanMyMac.

## Features

- **LuLu** — outbound network firewall (macOS's own firewall filters inbound only)
- **OverSight** — camera/mic activation monitor
- **BlockBlock** — persistence monitor (launch agents, daemons, login items, cron)
- **ReiKey** — keyboard event-tap (keylogger) detector
- **KnockKnock** — on-demand persistence scanner, VirusTotal cross-checked
- **ClamAV** — malware scanner
- **Lynis** — system security auditor
- **AppCleaner** — complete application uninstaller

> **The Objective-See tools are real-time monitors.** LuLu, OverSight, BlockBlock and
> ReiKey detect nothing unless they are actually *running*. Installing them is not
> configuring them — set each to start at login and verify with `secaudit`, which
> reports any monitor that is installed but not running.

## Quick Start

```bash
git clone git@github.com:mcps976/macos-security-hardening.git
cd macos-security-hardening
chmod +x install.sh
./install.sh
```

Scripts are **symlinked** into `~/bin`, so this repo is the single source of truth —
edit either path and `git status` shows the change.

## Commands

| Alias | Script | Purpose |
|---|---|---|
| `cleanup` | `mac-cleanup.sh` | Age-limited cache/log cleanup, Trash, Homebrew, Xcode, npm |
| `scanmalware` | `clamscan-quick.sh` | ClamAV scan of Downloads/Documents/Desktop |
| `secaudit` | `mac-security-audit.sh` | Lynis + FileVault/SIP/firewall/Gatekeeper + monitor status |
| `weekly` | `weekly-maintenance.sh` | Cleanup → Homebrew update/upgrade → scan → macOS updates |
| `netmon` | `network-monitor.sh` | Topology-aware network posture (see below) |
| `fullaudit` | `run_full_audit.sh` | Everything, saved to `~/security-audit-reports/` |
| `scanstartup` | — | Opens KnockKnock |
| `checkkeylog` | — | Opens ReiKey |
| `viewnetwork` | — | Opens Netiquette |
| `uninstall` | — | Opens AppCleaner |

## Design rules

**Composition, not duplication.** `run_full_audit.sh` *calls* `mac-security-audit.sh`
and `network-monitor.sh` rather than repeating their commands. An earlier version ran
Lynis twice and repeated FileVault/SIP/firewall/Gatekeeper three times each in a single
run. Add new checks to the relevant sub-script; the full audit picks them up
automatically.

**Forensics are preserved.** `mac-cleanup.sh` does not delete
`/Library/Logs/DiagnosticReports`. Crash reports are the first artefacts you examine
after a BlockBlock or KnockKnock alert — a security stack must not destroy them.
Caches and user logs are age-limited (30 days) rather than wiped.

**`coreutils` is a hard dependency.** macOS has no native `timeout`. Without it the
ClamAV steps in the full audit silently no-op while printing reassuring output.

**ClamAV definitions update on a schedule, not on memory.** `install.sh` loads a user
LaunchAgent (`local.clamav.freshclam`, from `launchd/`) that runs `freshclam` daily at
12:00 and at login. Every other `freshclam` call in this repo sits behind a manual
alias, and between April and September 2026 none of them ran — the scanner had
five-month-old signatures while looking fully installed. `scanmalware` now prints the
definition build date so staleness is visible; `fix-clamav.sh` sets `UpdateLogFile` so a
failing update leaves a trace in `/opt/homebrew/var/log/clamav/freshclam.log`.
Manage with `~/bin/schedule-freshclam.sh` (`--remove` to unload).

## Network topology assumptions

`network-monitor.sh` is written against this homelab:

| Segment | Subnet | Notes |
|---|---|---|
| LAN | `192.0.2.0/24` | Gateway `192.0.2.1` — firewall, reverse proxy, DNS |
| SERV | `198.51.100.0/24` | NAS `198.51.100.10` |
| NODE | `203.0.113.0/24` | Node `203.0.113.100` |

> Example addresses only (RFC 5737). Put your real topology in
> `~/.config/macos-security-hardening/network.conf` — see `scripts/network.conf.example`.

**Mullvad is not a local CLI.** It is reached only as a Tailscale exit node, so VPN
state is read from `tailscale status --json` (exit node, subnet routes, egress IP)
rather than from a `mullvad` binary. Scripts that shell out to `mullvad` will always
fail on this machine.

`netmon` reports which interface each subnet is reached through (`utunN` = via the
Tailscale subnet route, `en0` = direct on the wire), which is the fastest way to spot
routes missing from the netmap or an exit node swallowing RFC1918 traffic.

## Repository

Public remote: `git@github.com:mcps976/macos-security-hardening.git`

## License

MIT License — See LICENSE file
