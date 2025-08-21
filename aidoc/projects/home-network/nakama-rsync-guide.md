# Nakama NAS Rsync Configuration Guide

## Current Setup Status ✅ (Updated: August 16, 2025)
- **SSH Access**: Working with key-based authentication on port 2322
- **Rsync**: Available and working over SSH
- **IP Address**: Static <NAKAMA_IP>
- **User**: nami with sudo privileges
- **Storage**: Single 4TB drive, 2.8TB volume at /share/CACHEDEV1_DATA/
- **Storage Configuration**: Single-disk setup (no RAID degradation)

## Available Shares for Backup
```
/share/backup    -> CACHEDEV1_DATA/backup  (Main backup destination)
/share/archive   -> CACHEDEV1_DATA/archive (Long-term storage)
/share/personal  -> CACHEDEV1_DATA/personal (Personal files)
/share/proj      -> CACHEDEV1_DATA/proj    (Projects)
/share/work      -> CACHEDEV1_DATA/work    (Work files)
/share/homes     -> CACHEDEV1_DATA/homes   (User home directories)
```

## Rsync Best Practices Commands

### Basic Rsync Command
```bash
rsync -avz --progress source/ nami@nakama:/share/backup/destination/
```

### Recommended Full Backup Command
```bash
rsync -avzh --progress --stats \
  --exclude '.DS_Store' \
  --exclude 'Thumbs.db' \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude '*.tmp' \
  --exclude '.cache/' \
  source/ nami@nakama:/share/backup/destination/
```

### Incremental Backup with Delete
```bash
rsync -avzh --progress --stats --delete \
  --backup --backup-dir=/share/backup/deleted/$(date +%Y%m%d) \
  --exclude-from=$HOME/.rsync-exclude \
  source/ nami@nakama:/share/backup/destination/
```

### Dry Run (Test First!)
```bash
rsync -avzhn --progress --stats \
  source/ nami@nakama:/share/backup/destination/
```

## Rsync Options Explained
- `-a`: Archive mode (preserves permissions, timestamps, etc.)
- `-v`: Verbose output
- `-z`: Compress during transfer
- `-h`: Human-readable file sizes
- `-n`: Dry run (don't actually transfer)
- `--progress`: Show transfer progress
- `--stats`: Show transfer statistics
- `--delete`: Delete files in destination that don't exist in source
- `--backup`: Keep backup of deleted/changed files
- `--exclude`: Skip specific files/patterns

## Example Backup Scripts

### Daily Home Directory Backup
```bash
#!/bin/bash
# backup-home.sh
SOURCE="$HOME/"
DEST="nami@nakama:/share/backup/home-$(hostname)/"
LOG="/tmp/rsync-$(date +%Y%m%d).log"

rsync -avzh --progress --stats \
  --exclude '.cache' \
  --exclude '.local/share/Trash' \
  --exclude 'Downloads/*.iso' \
  --exclude '.config/*/Cache' \
  "$SOURCE" "$DEST" 2>&1 | tee "$LOG"
```

### Project Backup with Versioning
```bash
#!/bin/bash
# backup-projects.sh
PROJECT_DIR="/export/proj"
BACKUP_BASE="nami@nakama:/share/backup/projects"
DATE=$(date +%Y%m%d-%H%M%S)

# Current backup
rsync -avzh --progress --stats \
  --exclude '.git/objects' \
  --exclude 'build/' \
  --exclude 'dist/' \
  "$PROJECT_DIR/" "$BACKUP_BASE/current/" 

# Snapshot backup
rsync -avzh --link-dest="$BACKUP_BASE/current/" \
  "$PROJECT_DIR/" "$BACKUP_BASE/snapshots/$DATE/"
```

## Performance Optimization

### For Large Files (Video, Archives)
```bash
rsync -avhW --progress --inplace --no-compress \
  largefile.mp4 nami@nakama:/share/backup/media/
```
- `-W`: Copy whole files (no delta)
- `--inplace`: Update destination files in-place
- `--no-compress`: Skip compression for already compressed files

### For Many Small Files
```bash
rsync -avz --progress \
  --sockopts=SO_SNDBUF=524288,SO_RCVBUF=524288 \
  source/ nami@nakama:/share/backup/destination/
```

### Parallel Rsync for Multiple Directories
```bash
#!/bin/bash
dirs=("documents" "pictures" "music" "videos")
for dir in "${dirs[@]}"; do
  rsync -avzh "/home/user/$dir/" \
    "nami@nakama:/share/backup/$dir/" &
done
wait
```

## Monitoring and Verification

### Check Transfer Integrity
```bash
rsync -avzhc --progress source/ nami@nakama:/share/backup/destination/
```
- `-c`: Checksum verification

### List Remote Files
```bash
rsync -av --list-only nami@nakama:/share/backup/
```

### Compare Local and Remote
```bash
rsync -avnc source/ nami@nakama:/share/backup/destination/
```

## Automation with Cron

### Add to crontab
```bash
crontab -e
```

### Daily backup at 2 AM
```cron
0 2 * * * /home/user/scripts/backup-home.sh >> /var/log/rsync-backup.log 2>&1
```

### Weekly full backup on Sunday at 3 AM
```cron
0 3 * * 0 rsync -avzh --delete /important/data/ nami@nakama:/share/backup/weekly/
```

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection
ssh -v nami@nakama

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 700 ~/.ssh
```

### Rsync Permission Issues
```bash
# Use sudo on remote (careful!)
rsync -avz -e "ssh" --rsync-path="sudo rsync" \
  source/ nami@nakama:/share/backup/destination/
```

### Speed Issues
```bash
# Test network speed
iperf3 -c <NAKAMA_IP>

# Limit bandwidth (in KB/s)
rsync -avz --bwlimit=5000 source/ nami@nakama:/share/backup/
```

## Security Best Practices

1. **Always use SSH** (never enable rsyncd daemon unless necessary)
2. **Use SSH keys** instead of passwords
3. **Create a dedicated backup user** if backing up from multiple machines
4. **Set appropriate permissions** on backup directories
5. **Use `--checksum`** for critical data
6. **Test with `--dry-run`** before large operations
7. **Keep logs** of all backup operations
8. **Verify backups regularly** with restore tests

## Storage Migration Notes (August 2025)

### Previous Issue (Resolved)
The NAS was sending daily alert emails about degraded RAID arrays after migrating from a 2-bay to 3-bay enclosure. This was caused by the system expecting 2 drives but only having 1.

### Resolution
- Removed the degraded storage pool configuration
- Created new single-disk storage pool with proper configuration
- Recreated volume with 2.8TB capacity and 743GB snapshot space
- System now shows healthy status: md1 array shows `[1/1] [U]`

### Post-Migration Requirements
After storage reconfiguration, the following must be recreated:
- User home directories (will be wiped)
- SSH authorized_keys (run `ssh-copy-id -p 2322 nami@nakama`)
- Backup directories (already recreated in /share/)