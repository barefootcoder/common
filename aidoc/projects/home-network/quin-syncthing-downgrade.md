# Quin Syncthing Downgrade — v2.1.0 → v1.30.0 (Agent Brief)

**Audience:** An AI agent (or human operator) running with shell access on the
EC2 sandbox host `quin`. All commands below assume you are SSH'd into quin as
`bburden`.

**Goal:** Roll quin's user-installed Syncthing back from `v2.1.0` to a v1.x
release (default target: `v1.30.0`, matching Haven and the planned Avalir
baseline), then **disable auto-upgrade permanently** so this doesn't recur.

**Why:** The rest of the home-network Syncthing cluster (Avalir, Haven,
Zadash) is on the v1.x series. Quin's `~/.local/bin/syncthing` self-upgraded
to `v2.1.0` on 2026-05-12 — see
`/home/buddy/common/aidoc/projects/home-network/syncthing-troubleshooting.md`
for the diagnosed effects. The apt-managed v1 boxes can't reach v2 yet
(Syncthing's `apt stable` channel still only ships v1), so the only realistic
realignment is dragging quin back to v1.

**Do not skip the "Disable auto-upgrade" step.** Without it, quin will
silently roll itself forward to v2 again on its next check, and we'll be
right back here.

---

## 0. Read this first

- File data on disk is *not* at risk in any of the steps below. Worst case is
  Syncthing has to rebuild its index from disk, which is slow but lossless.
- The `~/.config/syncthing/` directory is the entire state Syncthing cares
  about. Snapshot it before touching anything (step 2).
- Anything you back up, **keep** until you've confirmed v1 is happy. Don't
  rm the backup at the end of this session.
- Quin's binary is user-installed at `~/.local/bin/syncthing` — there's no
  apt or systemd involvement to fight with. The supervisor process spawns a
  child; both PIDs need to go.

## 1. Inspect current state

```bash
# Confirm version and find both supervisor + child PIDs
~/.local/bin/syncthing --version
ps -fC syncthing

# Confirm config dir layout — note which DB artifacts exist.
# v1 keeps an `index-v0.14.0.db/` leveldb directory.
# v2 keeps a SQLite-based DB; file names vary by point release
# (e.g. `index-v2.db`, or files under `~/.local/state/syncthing/`).
ls -la ~/.config/syncthing/
ls -la ~/.local/state/syncthing/ 2>/dev/null

# Note auto-upgrade setting and current peer connections
grep -E 'autoUpgrade|listenAddress' ~/.config/syncthing/config.xml
API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml \
    | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
curl -s -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/system/connections \
    | python3 -m json.tool | head -40
```

Record what you find. If `index-v0.14.0.db/` still exists alongside v2's
SQLite files, the downgrade path is gentler (step 5a). If only v2 artifacts
are present, you'll be re-indexing from disk (step 5b).

## 2. Snapshot everything

```bash
ts=$(date +%Y%m%d-%H%M%S)
mkdir -p ~/backups/syncthing
tar czf ~/backups/syncthing/preflight-$ts.tar.gz \
    --exclude='*.log' \
    -C ~ .config/syncthing \
    .local/bin/syncthing \
    $( [ -d ~/.local/state/syncthing ] && echo .local/state/syncthing )
ls -lh ~/backups/syncthing/preflight-$ts.tar.gz
```

Note the tarball name; you'll need it if rollback is required.

## 3. Stop Syncthing

```bash
# Stop both supervisor and child. The supervisor will respawn the child on
# SIGTERM, so kill the supervisor first then any straggling child.
pkill -TERM -f '/syncthing serve'
sleep 2
pgrep -af syncthing                # should be empty
# If anything still lingers:
pkill -KILL -f '/syncthing serve' || true
```

Verify port 8384 is no longer listening:

```bash
ss -tlnp | grep 8384       # expect no output
```

## 4. Install v1.30.0

```bash
cd /tmp
ver=v1.30.0
arch=linux-amd64
url=https://github.com/syncthing/syncthing/releases/download/${ver}/syncthing-${arch}-${ver}.tar.gz
curl -fsSLO "$url"
tar xzf syncthing-${arch}-${ver}.tar.gz

# Stash the v2 binary in case rollback is needed (do NOT just overwrite)
mv ~/.local/bin/syncthing ~/.local/bin/syncthing.v2.1.0.bak
install -m 0755 syncthing-${arch}-${ver}/syncthing ~/.local/bin/syncthing

~/.local/bin/syncthing --version   # expect v1.30.0
```

## 5. Reconcile the database

### 5a. Preferred path: old leveldb still present

If step 1 showed an `index-v0.14.0.db/` directory in `~/.config/syncthing/`,
you can probably just hide the v2 SQLite artifacts and let v1 pick up the
older index. The index will be stale by ~1 day, but it'll re-converge with
Avalir quickly after restart.

```bash
cd ~/.config/syncthing
mkdir -p _v2-stash
# Move ONLY the v2-era files. Keep config.xml, cert*.pem, key*.pem,
# the device IDs, and the index-v0.14.0.db/ directory in place.
# v2 artifacts to look for (names vary by point release — adjust to what
# step 1 actually found):
mv -v index-v2*.db* _v2-stash/ 2>/dev/null || true
mv -v syncthing.db* _v2-stash/ 2>/dev/null || true
# Likewise for anything under ~/.local/state/syncthing/ that v2 created:
[ -d ~/.local/state/syncthing ] && mv ~/.local/state/syncthing ~/.local/state/syncthing.v2-stash
```

### 5b. Fallback: no leveldb backup — re-index from disk

If only v2-era DB files exist, blow away the index entirely. **Do not**
remove `config.xml`, `cert.pem`, or `key.pem` — those carry the device
identity and folder configuration.

```bash
cd ~/.config/syncthing
mkdir -p _v2-stash
# Move every DB-ish artifact out of the way (don't delete yet)
mv -v index-* _v2-stash/ 2>/dev/null || true
mv -v *.db *.db-* _v2-stash/ 2>/dev/null || true
[ -d ~/.local/state/syncthing ] && mv ~/.local/state/syncthing ~/.local/state/syncthing.v2-stash
ls -la ~/.config/syncthing/    # config.xml + cert.pem + key.pem must still be here
```

Expect a long re-indexing pass when Syncthing starts (proportional to the
sizes of the workproj-ce, work-ce, and proj-common folders — several
gigabytes total). Files won't be re-transferred; just re-hashed locally.

## 6. Disable auto-upgrade (CRITICAL)

Edit `~/.config/syncthing/config.xml` and set:

```xml
<options>
    ...
    <autoUpgradeIntervalH>0</autoUpgradeIntervalH>
    ...
</options>
```

`0` disables auto-upgrade entirely. Confirm with:

```bash
grep -A1 autoUpgrade ~/.config/syncthing/config.xml
```

It should show `<autoUpgradeIntervalH>0</autoUpgradeIntervalH>`.

## 7. Start Syncthing and verify

**Config-schema migration:** v2.x bumps the `config.xml` schema version
(`v2.1.0` writes schema `v52`; `v1.30.0` knows schema `v37`). A plain
start will refuse with:

```
config file version (52) is newer than supported version (37)
```

Pass `--allow-newer-config` on the very first v1 start — Syncthing will
migrate in place, archive the v52 form as `config.xml.v52`, and rewrite
`config.xml` as v37. After that one-off start, the flag is no longer
needed.

```bash
# First start — let v1 migrate the schema down. Use --allow-newer-config
# only on this initial run; drop it from any subsequent restarts.
nohup ~/.local/bin/syncthing serve --no-browser --home=/home/bburden/.config/syncthing \
    --allow-newer-config \
    >> ~/.config/syncthing/syncthing.log 2>&1 &
disown

sleep 5
ps -fC syncthing
ss -tlnp | grep 8384

# Watch the early log for fatal errors. "Database open" / "Ready to synchronize"
# is what you want. Errors like "newer database format" mean you skipped 5b.
tail -n 80 ~/.config/syncthing/syncthing.log
```

Then verify the cluster view:

```bash
API_KEY=$(grep '<apikey>' ~/.config/syncthing/config.xml \
    | sed 's/.*<apikey>\(.*\)<\/apikey>.*/\1/')
curl -s -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/system/version
echo
curl -s -H "X-API-Key: $API_KEY" http://127.0.0.1:8384/rest/system/connections \
    | python3 -m json.tool | grep -E 'connected|clientVersion'
echo
for f in proj-common work-ce workproj-archer-boot workproj-ce workproj-cheops; do
    curl -s -H "X-API-Key: $API_KEY" "http://127.0.0.1:8384/rest/db/status?folder=$f" \
        | python3 -c 'import sys,json,os
d=json.load(sys.stdin)
print("%-22s state=%s need=%s err=%s pullErr=%s global=%s local=%s" % (os.environ["F"], d.get("state"), d.get("needFiles"), d.get("errors"), d.get("pullErrors"), d.get("globalFiles"), d.get("localFiles")))' F=$f
done
```

Expected outcome:

- `version` shows `v1.30.0`.
- Avalir's connection comes back up; `clientVersion` matches Avalir's
  running version.
- Every folder's `globalFiles == localFiles` once the initial reconcile
  finishes (give it a few minutes — re-indexing from disk on 5b takes a
  while).
- `errors == 0` and `pullErrors == 0`.

## 8. After confirming health

- Leave `~/backups/syncthing/preflight-*.tar.gz`, `~/.local/bin/syncthing.v2.1.0.bak`,
  and the `_v2-stash` directories in place for at least a week before
  cleaning them up. They're cheap insurance.
- Coordinate with the Avalir-side caretaker so the temporary
  `rescanIntervalS=600` on `workproj-ce` / `proj-common` can be relaxed
  back to `3600` once the cluster is stable — that tightening was a
  v1↔v2-era mitigation that no longer applies.
- Update
  `/home/buddy/common/aidoc/projects/home-network/syncthing-troubleshooting.md`:
  remove the "Cluster version note" at the top (or rewrite it to confirm
  the cluster is aligned again), and add a brief case study summarizing
  the downgrade. (The Avalir-side agent that owns the home-network aidoc
  can handle this; don't edit it from quin unless that's been agreed.)

## Rollback (if v1.30.0 won't start cleanly)

If the v1.30.0 start fails with database/format errors and you've used
path 5b, your fallback is to abandon the downgrade attempt:

```bash
pkill -TERM -f '/syncthing serve'; sleep 2
mv ~/.local/bin/syncthing ~/.local/bin/syncthing.v1.30.0.bak
mv ~/.local/bin/syncthing.v2.1.0.bak ~/.local/bin/syncthing

# Restore the v2-era DB files
cd ~/.config/syncthing
mv _v2-stash/* . 2>/dev/null || true
[ -d ~/.local/state/syncthing.v2-stash ] && mv ~/.local/state/syncthing.v2-stash ~/.local/state/syncthing

# Restart v2
nohup ~/.local/bin/syncthing serve --no-browser --home=/home/bburden/.config/syncthing \
    >> ~/.config/syncthing/syncthing.log 2>&1 &
disown

~/.local/bin/syncthing --version    # expect v2.1.0 again
```

Then report back to the Avalir side so we can decide whether to wait for
Syncthing's apt repo to ship v2 (and upgrade the rest of the cluster
forward) instead.
