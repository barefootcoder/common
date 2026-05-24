# Fire-Evac Recovery Guide

**Created**: 2026-05-19, during fire-evac shelter-in-place backup setup.
**Audience**: You (post-disaster, on a clean replacement machine) or an AI agent
helping you recover. Assume nothing is remembered.

If you are reading this and the house is gone: **everything is recoverable**, as
long as Haven (or any device with a current copy of `/export/personal/Dropbox/`)
survived. The keys to your Backblaze B2 backup live on Haven.

---

## TL;DR — the 60-second mental model

- Your data was pushed to Backblaze B2 on **2026-05-19** during a fire warning.
- Three buckets matter:
  - **`barefoot-common`** — cleartext bulk data (photos, music, work, etc.)
  - **`barefoot-encrypted`** — credentials and sensitive material, client-side
    encrypted with rclone-crypt. Useless without the passphrase.
  - **`barefoot-caemlyn`** — legacy CloudBerry config, ignore.
- The two recovery secrets live in `/export/personal/Dropbox/sensitive/`,
  Syncthing-replicated to Haven before evacuation:
  - `backup/backblaze-b2.keys` — B2 application keys (cleartext). Use the
    **`QNAP-NAS`** entry (key #4).
  - `b2-crypt.passphrase` — crypt passphrase (cleartext). Has both `password`
    and `password2` (filename salt).

---

## Step-by-step recovery

### 0. Get the secrets off Haven

On Haven (or whichever machine survived with a `/export/personal/` copy):

```bash
cat ~/docs/Dropbox/sensitive/backup/backblaze-b2.keys
cat ~/docs/Dropbox/sensitive/b2-crypt.passphrase
```

(`~/docs` is a symlink to `/export/personal`; both paths work.)

Copy these to the replacement machine via the most convenient channel
(scp over Tailscale if Haven is online, USB stick, secure paste, etc.).
**Treat them as live credentials.** Don't paste either file into chat,
issue trackers, or anything cloud-sync'd that you don't own end-to-end.

### 1. Install rclone on the new machine

```bash
sudo apt-get install -y rclone           # Debian/Ubuntu/Mint
# or download static binary from https://rclone.org/downloads/
```

### 2. Configure rclone (`~/.config/rclone/rclone.conf`)

Create the file with mode 0600 and the following two remotes. Replace both
`<keyID>` and `<applicationKey>` with the values from `backblaze-b2.keys` (the
`keyID` and `applicationKey` lines under the `QNAP-NAS` entry, key #4). Both
also live in this project's `private/api-keys.md`, which is gitignored:

```ini
[b2]
type = b2
account = <keyID from backblaze-b2.keys QNAP-NAS entry>
key = <applicationKey from backblaze-b2.keys QNAP-NAS entry>

[b2-crypt]
type = crypt
remote = b2:barefoot-encrypted
filename_encryption = standard
directory_name_encryption = true
password = <obscured-password>
password2 = <obscured-password2>
```

For the crypt section, you need the **obscured** form of the two passphrases
from `b2-crypt.passphrase` (not the cleartext). Obscure them like this:

```bash
rclone obscure "<password cleartext from passphrase file>"   # paste output as 'password ='
rclone obscure "<password2 cleartext>"                       # paste output as 'password2 ='
```

Verify with:

```bash
rclone lsd b2:                          # should list barefoot-common, barefoot-encrypted, ...
rclone lsd b2-crypt:                    # should list cleartext folder names (avalir/, etc.)
```

If `b2-crypt:` lists garbled names, the passphrase is wrong or the
filename-encryption flags don't match. Double-check the cleartext values.

### 3. Pull your data

All `rclone copy` commands below use `--update` (skip if dest is newer/same)
and never delete. Safe to interrupt and resume.

#### Bulk cleartext data (`barefoot-common/`)

```bash
# /export/* trees (matches your original directory layout)
rclone copy b2:barefoot-common/personal      /export/personal      --update -P
rclone copy b2:barefoot-common/proj          /export/proj          --update -P
rclone copy b2:barefoot-common/work          /export/work          --update -P
rclone copy b2:barefoot-common/backup        /export/backup        --update -P
rclone copy b2:barefoot-common/camera        /export/camera        --update -P
rclone copy b2:barefoot-common/music         /export/music         --update -P
rclone copy b2:barefoot-common/rpg           /export/rpg           --update -P
```

#### Avalir host-unique state (`barefoot-common/avalir/`)

```bash
rclone copy b2:barefoot-common/avalir/thunderbird     ~/.thunderbird     --update -P
rclone copy b2:barefoot-common/avalir/mozilla         ~/.mozilla         --update -P
rclone copy b2:barefoot-common/avalir/config-vivaldi  ~/.config/vivaldi  --update -P
rclone copy b2:barefoot-common/avalir/local           ~/local            --update -P
rclone copy b2:barefoot-common/avalir/workproj/archer-boot-host  ~/workproj/archer-boot-host  --update -P
rclone copy 'b2:barefoot-common/avalir/VirtualBox-VMs' ~/'VirtualBox VMs' --update -P  # only if it got uploaded
```

#### Zadash version history (`barefoot-common/sync_hist/`)

```bash
# These were Syncthing's .stversions/ trees on Zadash — old file revisions
# Useful for "I deleted that file last month" recovery. Restore as needed.
rclone copy b2:barefoot-common/sync_hist/proj/.stversions      /tmp/recover-stv-proj      --update -P
rclone copy b2:barefoot-common/sync_hist/personal/.stversions  /tmp/recover-stv-personal  --update -P
rclone copy b2:barefoot-common/sync_hist/work/.stversions      /tmp/recover-stv-work      --update -P
# ... etc for rpg, music, backup
```

#### Nakama unique data (`barefoot-common/nakama/`)

```bash
# Older snapshots of personal/proj/work + historical archives from Caemlyn-era
rclone copy b2:barefoot-common/nakama/archive   /mnt/recover/nakama/archive    --update -P
rclone copy b2:barefoot-common/nakama/personal  /mnt/recover/nakama/personal   --update -P
rclone copy b2:barefoot-common/nakama/backup    /mnt/recover/nakama/backup     --update -P
# ... etc for proj, work, sync_hist, external, Public, homes
```

#### Encrypted credential material (`b2-crypt:`)

```bash
# Restore in place; mode bits should come through unchanged
rclone copy b2-crypt:avalir/dotssh     ~/.ssh           --update -P
chmod 700 ~/.ssh; chmod 600 ~/.ssh/*
rclone copy b2-crypt:avalir/dotgnupg   ~/.gnupg         --update -P
chmod 700 ~/.gnupg
rclone copy b2-crypt:avalir/dotaws     ~/.aws           --update -P
rclone copy b2-crypt:avalir/config-gh  ~/.config/gh     --update -P
rclone copyto b2-crypt:avalir/dotnetrc ~/.netrc         --update
rclone copy b2-crypt:personal-dropbox-sensitive  ~/docs/Dropbox/sensitive  --update -P

# /etc/ssh restoration (host keys) — only if you want this machine to inherit
# Avalir's old SSH identity:
rclone copyto b2-crypt:avalir/etc-ssh.tar /tmp/etc-ssh.tar
sudo tar -xf /tmp/etc-ssh.tar -C /          # creates /etc/ssh from archive root
sudo systemctl restart ssh
```

### 4. Sanity checks after recovery

```bash
# Did personal land safely?
ls /export/personal/Dropbox/sensitive/backup/    # should show backblaze-b2.keys
gpg --list-secret-keys                          # GPG keys back
ssh -T git@github.com                           # GitHub still trusts your key
```

---

## Bucket layout cheat sheet

| Path | Source | Notes |
|---|---|---|
| `b2:barefoot-common/{archive,backup,camera,music,personal,proj,rpg,work}/` | Avalir `/export/*` | Cleartext, matches original directory layout |
| `b2:barefoot-common/avalir/{thunderbird,mozilla,config-vivaldi,local,workproj/archer-boot-host,VirtualBox-VMs}/` | Avalir `$HOME` | Cleartext, host-unique state |
| `b2:barefoot-common/sync_hist/{folder}/.stversions/` | Zadash `/srv/sync_hist/*/.stversions/` | Cleartext, Syncthing version history |
| `b2:barefoot-common/nakama/{archive,personal,backup,proj,work,sync_hist,external,Public,homes}/` | Nakama `/share/*` | Cleartext, NAS unique content (incl. legacy Caemlyn data) |
| `b2-crypt:avalir/{dotssh,dotgnupg,dotaws,config-gh,dotnetrc,etc-ssh.tar}` | Avalir credential dirs | **Encrypted**, decrypt via `b2-crypt:` remote |
| `b2-crypt:personal-dropbox-sensitive/` | `/export/personal/Dropbox/sensitive/` | **Encrypted** |
| `b2:barefoot-common/{sync_hist,synology}/` (legacy) | Pre-2026 CloudBerry/Synology Cloud Sync | Stale data from prior backup tools |
| `b2:barefoot-caemlyn/CBB_config/` | Defunct CloudBerry agent | Ignore |
| `b2:b2-snapshots-*/` | Backblaze auto-managed | Don't touch |

## Bucket order-of-recovery (if bandwidth is constrained)

1. **`b2-crypt:`** — credentials first, you need them to operate
2. `barefoot-common/avalir/` — host-unique (browser profile has passwords)
3. `barefoot-common/personal` — financial/scanned docs
4. `barefoot-common/proj`, `work`, `backup`
5. `barefoot-common/sync_hist/` — version history
6. `barefoot-common/camera`, `rpg`, `music` — media
7. `barefoot-common/nakama/` — legacy archives

## Hardware that survived (and what to do with it)

| Device | Status | Action |
|---|---|---|
| Haven | Went with you | Source of truth for the recovery secrets. Once you have B2 access, restore the rest of your machines from it + B2. |
| Quin (EC2) | Always-on, never at risk | Holds the developer repos (`proj/common`, `work/ce`, `workproj/{CE,archer-boot,cheops}`). `git pull` from quin to restore the dev environment. |
| Phone | With you | Use as hotspot if home internet is also gone. |
| Anything else (Avalir, Nakama, Zadash, Caemlyn-already-gone) | Presumed lost | Replace as needed; restore from B2 as above. |

## Re-keying after recovery

You should treat the existing B2 keys as compromised in any disaster scenario
(physical access to Avalir = key extraction). After the most urgent recovery:

1. Log into B2 web UI, **revoke the `QNAP-NAS` key** in *Account → Application
   Keys*.
2. Create a new app key with a fresh name (e.g., `Recovery-YYYY-MM-DD`).
3. Update `~/.config/rclone/rclone.conf` `[b2] key=` on the new machine.
4. Add the new key to `~/docs/Dropbox/sensitive/backup/backblaze-b2.keys`.

The crypt passphrase does not need rotation (it never left your possession in
cleartext), but rotating it is harmless if you have time:

1. Generate a new passphrase pair (same way as before).
2. Re-encrypt: `rclone sync b2-crypt:/ b2-crypt-new:/` (using a temporary
   second crypt remote with the new passphrase pointing at a new bucket).
3. Swap `[b2-crypt]` to the new bucket; update the passphrase file.
