#!/bin/bash

# Backup script for Nakama NAS
# Configure these variables for your setup

# Configuration
NAS_USER="nami"
NAS_HOST="nakama"  # or use IP: <NAKAMA_IP>
NAS_BACKUP_BASE="/share/backup"
EXCLUDE_FILE="$(dirname "$0")/rsync-exclude.txt"
LOG_DIR="$HOME/.backup-logs"
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/backup-$DATE.log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to perform backup
backup_directory() {
    local source="$1"
    local dest_name="$2"
    local dest="${NAS_USER}@${NAS_HOST}:${NAS_BACKUP_BASE}/${dest_name}/"
    
    log_message "Starting backup of $source to $dest"
    
    # Dry run first to check what will be transferred
    log_message "Running dry-run to check changes..."
    rsync -avzhn --progress --stats \
        --exclude-from="$EXCLUDE_FILE" \
        "$source" "$dest" >> "$LOG_FILE" 2>&1
    
    # Ask for confirmation
    echo "Dry run complete. Check log for details."
    read -p "Proceed with actual backup? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_message "Starting actual transfer..."
        rsync -avzh --progress --stats \
            --exclude-from="$EXCLUDE_FILE" \
            "$source" "$dest" 2>&1 | tee -a "$LOG_FILE"
        
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            log_message "Backup completed successfully!"
        else
            log_message "ERROR: Backup failed with exit code ${PIPESTATUS[0]}"
            return 1
        fi
    else
        log_message "Backup cancelled by user"
        return 1
    fi
}

# Main script
log_message "=== Starting backup session ==="
log_message "NAS: ${NAS_USER}@${NAS_HOST}"
log_message "Exclude file: $EXCLUDE_FILE"

# Test connection
log_message "Testing connection to NAS..."
if ssh "${NAS_USER}@${NAS_HOST}" "echo 'Connection successful'" > /dev/null 2>&1; then
    log_message "Connection test passed"
else
    log_message "ERROR: Cannot connect to NAS"
    exit 1
fi

# Example backups - customize these for your needs
# Uncomment and modify as needed:

# Backup home directory
# backup_directory "$HOME/" "home-$(hostname)"

# Backup projects
# backup_directory "/export/proj/" "projects"

# Backup specific directory
# backup_directory "/path/to/important/data/" "important-data"

# Interactive mode - ask what to backup
echo "What would you like to backup?"
echo "1) Home directory"
echo "2) Projects (/export/proj)"
echo "3) Custom directory"
echo "4) Exit"
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        backup_directory "$HOME/" "home-$(hostname)"
        ;;
    2)
        backup_directory "/export/proj/" "projects"
        ;;
    3)
        read -p "Enter source directory: " src_dir
        read -p "Enter destination name on NAS: " dest_name
        if [ -d "$src_dir" ]; then
            backup_directory "$src_dir" "$dest_name"
        else
            log_message "ERROR: Directory $src_dir does not exist"
            exit 1
        fi
        ;;
    4)
        log_message "Exiting without backup"
        exit 0
        ;;
    *)
        log_message "Invalid choice"
        exit 1
        ;;
esac

log_message "=== Backup session complete ==="
echo "Log file: $LOG_FILE"