# Haven fstab UUID Fix and Vivaldi Guard (2026-04-23)

## Session Context

Haven was recovering from a battery-drain shutdown. The first post-shutdown
boot worked fine — user clicked the Vivaldi panel icon and immediately got a
**hard hardware-off crash** (no graceful shutdown, no journal entries).
Subsequent reboots dropped into **systemd emergency mode** because `/export`
wouldn't mount. Recovery required diagnosing two independent problems.

This session is a sequel to `summary:haven-kernel-upgrade-and-gpu-fix.md`
(Feb 2026). The kernel upgrade is still in place and working — but it did
not fully eliminate the Vivaldi + NoMachine crash mode under the heaviest
GPU loads.

## Two Independent Findings

### 1. NVMe Enumeration Flip Broke /export Mount

Haven has two NVMe drives. At install time:
- `nvme1n1` — main drive (EFI, /boot, encrypted LVM containing `/` + swap)
- `nvme0n1` — secondary drive (`/export` at p1)

At some point during the Apr 23 crash cycle the NVMe probe order flipped
(plausibly from dirty shutdown timing changes or USB-C init timing).
After the flip:
- `nvme0n1` — main drive
- `nvme1n1` — `/export` drive

`/etc/fstab` hardcoded `/dev/nvme0n1p1 /export ext4 defaults 0 0`. After the
flip, `/dev/nvme0n1p1` was the EFI partition (vfat), so the ext4 mount failed
with "Can't find ext4 filesystem", which dropped systemd to emergency mode.

`/boot`, `/boot/efi` were unaffected (they already used UUID). `/` and swap
were unaffected (they use `/dev/mapper/vgmint-*` names, LVM discovers by
metadata not probe order). `/etc/crypttab` was unaffected (uses UUID).

**Fix applied**: switched `/etc/fstab` line for `/export` to use UUID and
set pass=2 for routine fsck:
```
UUID=ea3cc4a1-a47d-4d9b-973d-d8bea71c5a82 /export ext4 defaults 0 2
```
Original preserved at `/etc/fstab.bak.pre-uuid-fix`. Validated with
`findmnt --verify`.

### 2. Vivaldi + NoMachine Still Crashes Post-Kernel-Fix

During the crash boot, an NoMachine session (`nxexec`) opened at 15:58:50
and the user clicked the Vivaldi icon ~30 seconds later; system died at
15:59:23 with no kernel errors, no oops bits, no thermal events — just
sudden journal silence. Classic signature of hardware-triggered power-off.

Isolation testing confirmed:
- **Chrome Ungoogled alone**: 2h11m soak, zero GPU/kernel events — clean
- **Vivaldi alone, full main profile, physical keyboard, no NoMachine**:
  restore burst of all windows + workspaces + many tabs — zero events,
  temp 42°C → 51°C, stable
- **Vivaldi + NoMachine**: the combo that triggered the hard crash

Conclusion: The kernel 6.8 fix eliminated the `arb session failed to go in
play` errors and raised the crash threshold, but running Vivaldi's heavy
GPU load *while* NoMachine captures/re-encodes the display is still beyond
this hardware's margin. NoMachine + Vivaldi = hard crash, every time.

**Fix applied**: `~/common/bin/vivaldi-guard` wrapper intercepts Vivaldi
launches and refuses with a red zenity warning if `pgrep -f
'nxagent|nxplayer\.bin'` finds an active session (either direction).
Haven's Mate panel launchers
(`~/.config/mate/panel2.d/default/launchers/vivaldi-stable*.desktop`)
now call the wrapper instead of `/usr/bin/vivaldi-stable` directly.
Original launcher files preserved as `*.bak.pre-guard`.

The guard does *not* fire on the always-running NoMachine daemons
(`nxserver.bin`, `nxd`, `nxnode.bin`, idle `nxexec --nopam`, `nxrunner`) —
only on actual active sessions. The idle daemons were verified not to
match the pgrep pattern.

## Red Herrings / Benign Noise to Ignore

These messages appear on every Haven boot and are **not** related to any
real problem:

- `ucsi_acpi USBC000:00: error -ETIMEDOUT: PPM init failed` — USB-C UCSI
  (USB Power Policy Manager, *not* Power Management) firmware timeout.
  Common on laptops; no functional impact.
- `ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PC00.MHBR]` and
  similar `_SB.PTID.PBAR`, `_TZ.ETMD` errors — buggy firmware references
  undeclared symbols. Known Clevo ACPI quirks; benign.
- Kernel taint = 12289 = bits 0 + 12 + 13 → proprietary-licensed kernel
  module (clevo-keyboard), firmware workaround applied, external DKMS
  module. Does **not** include any oops/panic/softlockup bits.
- `hidpp_battery_0` / `powerprofilesctl` failures around AC state changes
  — pre-existing udev scripts that fail on battery peripherals. Not new.

## Verification Commands

```bash
# Confirm fstab UUID fix is in place
grep export /etc/fstab
# → UUID=ea3cc4a1-… /export ext4 defaults 0 2

sudo findmnt --verify
# → "Success, no errors or warnings detected"

# Confirm guard is wired in
grep -H Exec= ~/.config/mate/panel2.d/default/launchers/vivaldi-stable*.desktop

# Test guard detection (should match nothing when no NoMachine session active)
pgrep -f 'nxagent|nxplayer\.bin'

# Verify kernel fix still in place
uname -r                          # → 6.8.0-100-generic
dmesg | grep -iE 'i915.*ERROR|arb session'   # → empty
```

## Files Changed

- `/etc/fstab` (Haven) — `/export` line switched to UUID, pass=2
- `/etc/fstab.bak.pre-uuid-fix` (Haven) — backup of original
- `/home/buddy/.config/mate/panel2.d/default/launchers/vivaldi-stable.desktop`
  (Haven) — 3 Exec lines routed through guard
- `/home/buddy/.config/mate/panel2.d/default/launchers/vivaldi-stable-1.desktop`
  (Haven) — 3 Exec lines routed through guard
- `vivaldi-stable.desktop.bak.pre-guard`, `vivaldi-stable-1.desktop.bak.pre-guard`
  (Haven) — backups
- `bin/vivaldi-guard` (common repo, new) — guard wrapper

## Lessons

1. **UUIDs in fstab are mandatory, not optional.** Device paths
   (`/dev/nvme0n1p1` etc.) are enumeration-dependent and can silently
   change between boots. Any hardcoded `/dev/nvmeXnY` line in fstab is
   a latent boot failure.
2. **Kernel fixes raise thresholds, they don't remove them.** The Feb
   2026 i915 kernel upgrade stopped the `arb session` crashes in ordinary
   use, but the combined Vivaldi + NoMachine GPU load still exceeds the
   margin. Guard against the combination rather than assuming the kernel
   fix covers all cases.
3. **Hard crashes leave no journal.** When the symptom is "hardware-off,
   nothing logged," the diagnostic strategy is isolating triggers
   empirically (test Chrome, then Vivaldi alone, then the combo) rather
   than searching for a kernel error that doesn't exist.
4. **Emergency mode is recoverable without force.** When the root fs is
   fine and only a secondary mount fails, the fix is usually: identify
   the failed unit with `systemctl --failed`, check the error, and
   manually mount or repair that one filesystem. Hard-power-cycling
   through emergency mode makes things worse, not better.
