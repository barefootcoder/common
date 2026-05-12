# Haven: May 11 Crash + Monitor Relocation + Mitigation Hardening

## Session Context

Triggered by another silent power-off crash on Haven on **2026-05-11 ~18:27**
— this time **after a 3-day uptime** and while watching videos via NoMachine
(not on app launch). This is a sequel to:

- `summary:vivaldi-7.9-upgrade-and-haven-instability.md` (May 8/9 2026)
- `summary:haven-fstab-uuid-and-vivaldi-guard.md` (April 2026)
- `summary:haven-kernel-upgrade-and-gpu-fix.md` (February 2026)

The session investigated the new crash and then made the May 8 limp-along
configuration **persistent and idempotent** through `termstart` + a relocated
forensic monitor, since the original `/tmp/viv-mon2.sh` script was lost when
`/tmp` was wiped at reboot.

## Crash Forensics — No Smoking Gun

The crash signature is identical to every prior Haven hardware crash:

- Journal cut cold at `18:27:09` mid-sentence (routine tailscale chatter); no
  panic, no oops, no thermal trip, no GPU error, no shutdown sequence — silent
  power-off.
- The forensic monitor running since May 8 (`~/viv-mon-prelaunch.log`)
  captured **15 seconds further** than journald did, last sample at
  `18:27:24.763`. Confirms journald wedged on `SyncIntervalSec=10s` rather
  than the system dying at 18:27:09 — the actual power-off was at ~18:27:25.
- At the moment of crash: `tz=55..65°C / load=2.12 / bat=8.35V on AC`. Far
  below historical highs during the same uptime (`tz1=88°C` peak May 8,
  `tz4=93°C` peak May 8, `load=10.56` peak May 9 — none of which crashed).
- Two minor anomalies in the final ~15 s but neither looks causal:
  - `tz4` flickered 54→74°C in <1 s (likely sensor read artifact)
  - Load climbed 0.99→2.12 over 10 s, almost certainly the *result* of a
    process starting, not the trigger.

**Conclusion:** consistent with the documented mainboard-aging hypothesis
(VRMs / decoupling capacitors producing transient power-rail collapse). The
randomness and lack of correlation with load/thermal state remain the
defining signature.

### What Changed in the World Since May 8

- **Vivaldi-stable**: no change since 7.9.3970.64 (May 8 upgrade)
- **Kernel**: no change since 6.8.0-100-generic (Jan 19)
- **NoMachine**: upgraded `8.22.1-3 → 9.5.7-4` on **2026-05-09 03:02:51**
  (only dpkg activity between May 8 crashes and May 11 crash). Today's crash
  was during NoMachine video playback. The May 8 summary had already
  established that crashes happen even without NoMachine, so this isn't a
  clean smoking gun — but it's the one new variable and worth tracking.

### What's Newly Established

- **3-day uptime is the longest since the instability dropped its threshold
  in May**. The May 8 limp-along config (powersave governor, touchpad
  disabled, Docker/Insync off, journald sync down to 10 s) is working.
- The limp-along config is **not yet permanent**. That's what this session
  fixed.

## Mitigation Hardening (Files Changed This Session)

### 1. `~/local/bin/viv-mon` (relocated from lost `/tmp/viv-mon2.sh`)

The original monitor script was recovered from Claude transcripts at
`~/.claude/projects/-export-proj-common/058778ab-fdfd-471f-9013-9848492e9ab1.jsonl`
(use `command grep -c viv-mon2` to confirm; line 429 has the heredoc).

Changes vs. the `/tmp/viv-mon2.sh` original:

- **Persistent location** under `~/local/bin/` (host-specific; doesn't get
  wiped at reboot).
- **Default log → `$HOME/viv-mon.log`** (fixed name, not timestamped). This
  lets termstart use a single gate path and lets `rotate_if_big()` cap total
  disk use independent of uptime.
- **Pidfile → `$HOME/.viv-mon.pid`** (was `/tmp/viv-mon.pid`, lost at reboot
  along with the script).
- **`rotate_if_big()`** — every 500 iterations (~100 s) check `stat -c '%s'`;
  if active log > 50 MB, `mv` to `${LOG}.prev` and `exec >>` to reopen.
  Hard ceiling: 100 MB regardless of uptime.

### 2. `local/haven/applets/touchpad-toggle` (Perl Tk applet)

Added `off` and `on` as startup arguments alongside the existing `toggle`
signal mode. Termstart now passes `off` so the touchpad starts disabled
without the user having to fire `tp` manually after every reboot.

```
touchpad-toggle           # start applet, inherit current xinput state
touchpad-toggle off       # start applet, force xinput state to OFF
touchpad-toggle on        # start applet, force xinput state to ON
touchpad-toggle toggle    # signal running applet (USR1) to flip state — used by `tp` alias
```

**Note on the May 8 "permanent disable" open item:** dropped. The user uses
the `tp` toggle pattern regularly (sometimes needs the touchpad when no
mouse is practical), so kernel-level unbind would break workflow. The
applet-level disable plus `off`-at-startup is sufficient.

### 3. `local/haven/bin/termstart`

Two new sections, both idempotent (per the project rule: termstart should
re-run safely after first boot):

```bash
# After screen-buflog-hold-files:
sudo cpupower frequency-set -g powersave >/dev/null
if ! kill -0 "$(cat ~/.viv-mon.pid 2>/dev/null)" 2>/dev/null
then
    nohup ~/local/bin/viv-mon >/dev/null 2>&1 &
fi
```

- `cpupower frequency-set` is naturally idempotent (setting the same governor
  twice is a no-op).
- viv-mon launch is gated by `kill -0` against the pidfile — stale PIDs from
  prior boots fail the check, live PIDs from the current boot pass it.
- `sudo` does not prompt on Haven (NOPASSWD or equivalent configured).

Also changed line 16: `touchpad-toggle &` → `touchpad-toggle off &`.

### 4. `bin/vivaldi-guard`

Added hostname-gated `--disable-gpu` injection (the May 8 open item):

```bash
if [[ "$(hostname -s)" == "haven" ]]; then
    # check args for existing --disable-gpu; if absent, prepend
    extra_args+=(--disable-gpu)
fi
exec /usr/bin/vivaldi-stable "${extra_args[@]}" "$@"
```

Idempotent: if the caller (or a self-invocation) already passed
`--disable-gpu`, it's not duplicated. Other hosts (Avalir, etc.) are
unaffected.

This unblocks panel launchers on Haven — they previously bypassed the
`--disable-gpu` flag because they invoke `vivaldi-guard` directly and the
flag was only being added manually at the terminal.

## Memory Updates

Two new feedback memories saved to
`~/.claude/projects/-export-proj-common/memory/`:

- `feedback_perl_over_python.md` — default to Perl for ad-hoc scripts on
  this account. User has 30 years of Perl + a "metric fuck-ton" of CPAN
  libs; very little Python installed.
- `feedback_termstart_for_persistence.md` — for "run X after every reboot"
  tasks, edit the host's `termstart` script (manually-invoked
  post-reboot kickoff) rather than writing systemd user units. termstart is
  host-specific, is in the user's repo, is just shell so ordering is
  trivial.

## State of Open Items from May 8 Summary

| May 8 open item | Status |
|----|----|
| 1. Hardware intervention (battery + repaste + cap inspection) | **Still pending** — most impactful remaining work |
| 2. Avalir Vivaldi upgrade | Unchanged (separate machine) |
| 3. Migrate Tabs Backup & Restore → Tab Session Manager | Deferred (still works on 7.9) |
| 4. Update `bin/vivaldi-guard` for `--disable-gpu` on Haven | **Done this session** |
| 5. Touchpad permanent disable (kernel-level) | **Rejected** — `tp` toggle pattern is the user's preferred workflow; applet-level + `off`-at-startup is enough |
| 6. CPU governor persistence | **Done this session** via termstart |

## New / Deferred Items After This Session

1. **Hardware intervention on Haven** (battery / repaste / cap inspection)
   — still the most important next step. Battery at 40% of design as of
   May 8; Clevo NS50AU-compatible part, $60-110, source from Sager (US
   Clevo distributor) or Green Cell. Serial number in
   `private/haven-snlabel.jpg`.
2. **NoMachine 9.5.7 watch** — only software variable that changed between
   the May 8 crashes and the May 11 crash. User is **not** ready to
   downgrade and `apt pin` won't work anyway (NoMachine self-updates via
   in-app prompt, not via the apt repo). Mitigation for now: ignore the
   "new version available" prompt when it appears in-app. If a future crash
   also correlates with NoMachine, revisit.
3. **Transcript-searcher with screenbuf fallback** — deferred tool idea. A
   Perl utility that grep across `~/.claude/projects/-*/*.jsonl` (Claude
   Code transcripts) and falls back to `~/local/data/screen-buflog/*/ai-common.buf`
   when the requested context predates Claude transcripts. Not yet built.

## Forensic State Currently Running on Haven

- **viv-mon (old version, pre-rotation)** is running at PID per
  `~/.viv-mon.pid`, writing to `~/viv-mon.log`. Started during this session.
  Will not rotate its log until restarted; user opted to leave it for now
  since the log is small. Next termstart re-run after a reboot will pick up
  the new rotation-capable version.
- **`~/viv-mon-prelaunch.log` (95 MB)** is the legacy log from the May 8/9
  crash forensics through to the May 11 crash. Safe to archive or delete
  once no longer needed for cross-checking.

## Conventions / Workflow Notes for the Next Agent

- **Don't use `git -C`** to point at the current working directory — see
  `~/.claude/CLAUDE.md`. Just run `git` directly.
- **For commits, always invoke `/x-commit`** rather than the default
  template.
- **For "run X after reboot" tasks, edit `termstart`** (`local/<host>/bin/termstart`)
  rather than writing systemd units. See feedback memory
  `feedback_termstart_for_persistence`.
- **Default to Perl, not Python** for ad-hoc scripts. See feedback memory
  `feedback_perl_over_python`.
- **`tp`** is the user's tcsh alias for the touchpad toggle. Defined in
  `local/haven/rc/tcshrc.local`.
- The user runs **`termstart` manually first thing after every reboot**,
  reliably. So work added to it actually happens.

## Files Changed This Session

In repo:

- `bin/vivaldi-guard` — Haven-gated `--disable-gpu` injection
- `local/haven/applets/touchpad-toggle` — `off`/`on` startup modes
- `local/haven/bin/termstart` — governor + gated viv-mon launch + touchpad
  off arg
- `local/haven/bin/viv-mon` — relocated forensic monitor with rotation
  (the user-facing path is `~/local/bin/viv-mon` via the symlink
  `~/local/bin → ~/common/local/haven/bin`)
- `aidoc/projects/home-network/summary:haven-may11-monitor-relocation-and-mitigation-hardening.md`
  — this doc
- `aidoc/projects/home-network/summary:vivaldi-7.9-upgrade-and-haven-instability.md`
  — forward pointer + strike-throughs in the open-items section
- `aidoc/projects/home-network/README.md` — reference to this summary

Outside repo (in `~/.claude/`):

- `feedback_perl_over_python.md`
- `feedback_termstart_for_persistence.md`
- `MEMORY.md` index updated
