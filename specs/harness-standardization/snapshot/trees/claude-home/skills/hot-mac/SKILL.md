---
name: hot-mac
description: Diagnose why this Mac is running hot, loud, or sluggish — find the culprit process and cool it down. Use when user says the computer is heating up, fans are loud, the machine is working too hard, "what's eating my CPU", everything is slow, or battery is draining fast.
---

# Hot Mac

STARTER_CHARACTER = 🌡️ — open each reply with it while this skill is active.

Find the actual culprit before touching anything. Heat is a symptom; the job is attribution.
Machine context: Apple Silicon (M1 Max), macOS, zsh.

## Phase 1 — Snapshot

Run these together; they're all read-only:

```sh
pmset -g therm                     # thermal/perf warning level, CPU power status
pmset -g batt                      # on battery vs AC — battery + heavy load compounds
memory_pressure -Q                 # free % — swapping generates heat too
top -l 2 -o cpu -n 12 -stats pid,command,cpu,mem | tail -16   # CPU hogs
top -l 2 -o mem -n 8  -stats pid,command,cpu,mem | tail -12   # memory hogs
```

`top` gotcha: the **first** sample is meaningless on macOS — always `-l 2` and read the second.

If CPU looks tame but the machine is still hot/loud, offer the sudo-level view (per the `!`
convention, the user runs it themselves):

```
! sudo powermetrics --samplers tasks,thermal -i 3000 -n 1
```

## Phase 2 — Attribute

Match the top offenders against the usual suspects before proposing anything:

| Process | What it means | Move |
|---|---|---|
| `kernel_task` high | **Symptom, not cause** — it throttles to shed heat. Never kill. | Find the real load; check ambient/vents/charger side |
| `WindowServer` | Display compositing — external monitors, many windows, animation-heavy apps | Close windows/spaces; check which app repaints constantly |
| `mdworker*`, `mds_stores` | Spotlight indexing (often after big file churn — builds, clones) | Usually finishes on its own; can exclude busy dirs in Spotlight prefs |
| `Google Chrome Helper` | One or more tabs | Chrome's own Task Manager (⋮ → More Tools) names the tab |
| `photoanalysisd`, `mediaanalysisd` | Photos ML scan | Finishes on its own; plugged-in idle overnight clears it |
| `backupd` | Time Machine | Let it finish |
| `bird`, `cloudd` | iCloud sync | Let it finish unless stuck for hours |
| `node`, `docker`, `qemu`, `claude` | Dev workloads — build watchers, containers, **runaway agent sessions** | These are the likely real culprits on this machine; identify which project/session |
| `duetexpertd`, `corespotlightd` | System ML/indexing background work | Transient; ignore unless sustained |

For a dev process, get its story before judging it: `ps -p <pid> -o lstart,etime,command`
(what is it, how long has it been running, which repo/session spawned it).

## Phase 3 — Act

Order of escalation — cheapest and least destructive first:

1. **No action** — if it's a system task that will finish (indexing, backup, sync), say so
   and stop. Don't kill things that are doing legitimate one-time work.
2. **Close at the source** — quit the app, close the Chrome tab, stop the build watcher,
   end the stale agent session via its own interface.
3. **Kill the process** — only with confirmation. Show what will be killed
   (`ps -p <pid> -o pid,lstart,command`) and what state might be lost, then wait for a yes.
   `kill -TERM` first; `-9` only if TERM is ignored. Never kill `kernel_task`,
   `WindowServer`, or `launchd`.
4. **Environment** — on battery under load: suggest plugging in (throttling is more
   aggressive on battery). Mention Low Power Mode as a deliberate trade-off, not a fix.

Hard rule: no `kill`, no `mdutil`, no `launchctl` changes without showing the target and
getting an explicit yes — same as any destructive command in loose work.

## Phase 4 — Report

One short summary: what was hot, why, what was done (or why nothing needed doing), and —
if it's recurring (same watcher, same runaway session pattern) — the one-line prevention.
