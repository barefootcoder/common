# Vagrant Dev Sandbox: read-only root recovered via initramfs fsck (2026-06-29)

## Scope note
This is the **local Vagrant/VirtualBox dev sandbox** (`avalir-dev-sandbox`,
SSH on `127.0.0.1:2222`, launched via `local/avalir/bin/ssh-sandbox` ->
`vagrant ssh`), NOT the EC2 "quin" instance. Don't confuse the two: the quin
docs in README cover a different machine.

## Symptom
A fresh `ssh-sandbox` session spewed a cascade of failures, all variants of
"Read-only file system":
- `setup-perl-locallib: line 79: $tmpfile: ambiguous redirect` (x17) -- mktemp
  failed under a read-only `/tmp`, left `$tmpfile` empty, and bash rejected the
  resulting empty-target redirect as "ambiguous".
- `mktemp: failed to create file ... Read-only file system`; cpanm
  `mkdir .../.cpanm/work/...: Read-only file system`.
- `tee: /etc/localhostname: Read-only file system`.
- `-bash: /home/vagrant/.tcshrc.local: Read-only file system`,
  `.login.local`, `.tcshrc.complete.ceflow`.
- `ssh-add -l` -> `Could not open a connection to your authentication agent`;
  `ssh-sock-reset` warned "no working SSH agent found".

Every one of these is downstream of a single fact: **root (`/`) was mounted
read-only.** Agent forwarding broke because sshd could not create its forwarded
socket under a read-only `/tmp`.

## Diagnosis (and two red herrings)
- **Disk-full ruled out:** `df -h` showed `/` at 37-40% (36G free). Not space.
- **RED HERRING 1 -- `mount | grep ' / '` returned nothing.** The user's `mount`
  is aliased to `findmnt -D | perl ...`, whose df-style output puts the target
  `/` at the *end* of the line with no trailing space, so `grep ' / '` (trailing
  space) never matches. Not a symptom; just the alias. (Lesson: use
  `findmnt -no OPTIONS /` for a definitive read, not a grep of aliased `mount`.)
- **RED HERRING 2 -- 1865 dmesg "errors".** A broad
  `dmesg | grep -Ei 'error|...|ext4'` matched 1865 lines, but those were benign
  (every normal `ext4` mount message, ACPI/driver lines containing the substring
  "error"). The *targeted* grep
  `dmesg | grep -Ei 'EXT4-fs error|I/O error|remount|aborting journal'` returned
  **0** -- i.e. no live kernel filesystem errors. The FS wasn't actively failing;
  it was flagged-but-quiescent.
- **Definitive reads:**
  - `findmnt -no OPTIONS /` -> `ro,relatime,errors=remount-ro,data=ordered`
    (genuinely read-only).
  - `touch /tmp/x` -> "Read-only file system" (ground truth).
  - `dumpe2fs -h /dev/mapper/vagrant--vg-root | grep 'Filesystem state'` ->
    **`clean with errors`** -- the ext4 error flag is set in the superblock.

## Root cause
The VM had been shut down uncleanly at some prior point, which set ext4's error
flag. With the `errors=remount-ro` mount option, ext4 refuses to mount writable
until a successful `e2fsck` clears that flag. On the next boot, the **initramfs**
preen-mode fsck (`-a`) recovered the journal and auto-fixed one inode, then hit
"inodes that were part of a corrupted orphan linked list" -- which preen will not
touch -- so it bailed with "UNEXPECTED INCONSISTENCY; RUN fsck MANUALLY", exit
code 4, and dropped to a BusyBox `(initramfs)` shell. Root never got mounted
read-write, sshd never started, and `vagrant up` timed out waiting for SSH.

A `vagrant up` timeout does NOT power the VM off -- the VM stays running, stuck at
that invisible headless console.

## Fix: drive the headless console and run e2fsck
All from Avalir (the VirtualBox host). VM name from `VBoxManage list runningvms`
was `cheops_ce-dev-sandbox_1691306679737_41191`.

1. **See the invisible console** -- screenshot the headless VM:
   ```
   VBoxManage controlvm "<vm>" screenshotpng /home/buddy/docs/ai/screenshots/x.png
   ```
   (`~/docs/ai/screenshots/` is a dir the agent can Read.) This showed the
   `(initramfs)` prompt + the "RUN fsck MANUALLY" message.
2. **Type into the console** -- VBox 6.1.38 supports `keyboardputstring`:
   ```
   VBoxManage controlvm "<vm>" keyboardputstring "e2fsck -fy /dev/mapper/vagrant--vg-root"
   VBoxManage controlvm "<vm>" keyboardputscancode 1c 9c     # Enter (press 1c, release 9c)
   ```
   Screenshot BEFORE sending Enter to confirm the command typed correctly.
3. **fsck result:** freed the orphaned inodes (3277361-3277365), corrected free
   block count / inode bitmap / free inode counts; "FILE SYSTEM WAS MODIFIED".
   A successful e2fsck clears the superblock error flag.
4. **Resume boot:** `keyboardputstring "exit"` + Enter at the initramfs prompt
   hands control back to init, which re-mounts the now-clean root and continues.
   The VM booted to a normal `vagrant-sandbox login:` prompt.
5. **Reconcile + verify** from the project dir (`$CHEOPSROOT` =
   `/home/buddy/workproj/cheops`):
   ```
   vagrant up                       # "Machine already provisioned"; mounts shares
   vagrant ssh -c "findmnt -no OPTIONS /"   # -> rw,...  (FIXED)
   ```
   Confirmed: root `rw`, `/tmp` writable, all vboxsf shares mounted.

## Notes for next time
- **The orphan-list/`-y` repair is the safe, standard recovery here** -- no I/O
  errors, no journal abort, just minor orphan cleanup. The freed inodes were
  files already mid-deletion at the unclean shutdown; losing them is correct.
  `e2fsck -fy` (auto-yes) is appropriate for a dev sandbox. NOTE: Claude Code's
  auto-mode safety classifier blocks `e2fsck -fy` as irreversible destruction
  until the user explicitly approves -- get the go-ahead first.
- **Agent forwarding "still broken" via `vagrant ssh -c` is a test artifact**, not
  a real problem: a non-interactive host shell has no ssh-agent for
  `config.ssh.forward_agent = true` to forward. The user's real path
  (`ssh-sandbox` -> `ssh-add-if-necessary` -> interactive tcsh with a live agent)
  forwards fine once `/tmp` is writable again.
- **Data safety:** the VM's `vg-root` holds only the OS + perl locallib + the dev
  MySQL data (`/var/lib/mysql` binds into vg-root). All real work
  (`CE`, `common`, `work`, `proj`, `.aws`) lives on `vboxsf` shares on Avalir and
  is never at risk.
- **Alternative fix:** `vagrant destroy -f && vagrant up` rebuilds the VM root from
  the base box -- guaranteed clean, but reprovisions from scratch (slow perl
  locallib rebuild) and loses VM-local locallib + dev MySQL. Reach for it only if
  the FS shows real corruption (I/O errors, severe damage) rather than this mild
  orphan-list case.
- **If this recurs often,** it points at repeated unclean VM shutdowns (host
  force-quit, Avalir power events). Worth checking how the sandbox is being
  stopped (prefer `vagrant halt` over killing VirtualBox).
