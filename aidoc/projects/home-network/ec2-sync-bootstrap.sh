#!/bin/bash
# EC2 Sandbox Syncthing/Tailscale Bootstrap Script
# Sets up bidirectional sync between EC2 sandbox and desktop via Tailscale VPN
# 
# Usage: ./ec2-sync-bootstrap.sh [--authkey TAILSCALE_KEY] [--device-name NAME]
#
# If no authkey provided, will prompt for one or attempt to read from encrypted file

set -e  # Exit on error

ME=$(basename "$0")
DESKTOP_DEVICE_ID="<AVALIR_DEVICE_ID>"  # Avalir
DESKTOP_TAILSCALE_IP="<TAILSCALE_IP>"  # Avalir's Tailscale IP

# Parse command line arguments
TAILSCALE_AUTHKEY=""
DEVICE_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --authkey)
            TAILSCALE_AUTHKEY="$2"
            shift 2
            ;;
        --device-name)
            DEVICE_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $ME [--authkey TAILSCALE_KEY] [--device-name NAME]"
            echo "  --authkey KEY     Tailscale auth key (will prompt if not provided)"
            echo "  --device-name NAME Device name for Tailscale (default: ec2-USERNAME-TIMESTAMP)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Generate device name if not provided
if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME="ec2-${USER}-$(date +%s)"
fi

echo "=== EC2 Sandbox Sync Setup ==="
echo "Device name: $DEVICE_NAME"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install Tailscale
echo ""
echo "=== Installing Tailscale ==="
if command_exists tailscale; then
    echo "Tailscale already installed"
else
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Step 2: Configure Tailscale
echo ""
echo "=== Configuring Tailscale ==="
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "No auth key provided. Please provide one:"
    echo "1. Generate at: https://login.tailscale.com/admin/settings/keys"
    echo "2. Settings: Ephemeral=Yes, Reusable=Yes, Expiration=90 days"
    read -p "Enter Tailscale auth key: " TAILSCALE_AUTHKEY
fi

sudo tailscale up --authkey "$TAILSCALE_AUTHKEY" --hostname "$DEVICE_NAME" --ssh

# Get our Tailscale IP
MY_TAILSCALE_IP=$(tailscale ip -4)
echo "This device's Tailscale IP: $MY_TAILSCALE_IP"

# Test connectivity to desktop
echo "Testing connectivity to desktop..."
if ping -c 1 -W 2 $DESKTOP_TAILSCALE_IP >/dev/null 2>&1; then
    echo "✓ Connected to desktop via Tailscale"
else
    echo "✗ Cannot reach desktop. Check Tailscale status on both ends."
    exit 1
fi

# Step 3: Install Syncthing
echo ""
echo "=== Installing Syncthing ==="
if [ -f ~/.local/bin/syncthing ]; then
    echo "Syncthing already installed"
else
    mkdir -p ~/.local/bin
    
    # Get latest version
    SYNCTHING_URL=$(curl -s https://api.github.com/repos/syncthing/syncthing/releases/latest | \
                    grep "browser_download_url.*linux-amd64" | grep -v ".asc" | cut -d\" -f4)
    
    if [ -z "$SYNCTHING_URL" ]; then
        # Fallback to known version
        SYNCTHING_URL="https://github.com/syncthing/syncthing/releases/download/v2.0.8/syncthing-linux-amd64-v2.0.8.tar.gz"
    fi
    
    echo "Downloading from: $SYNCTHING_URL"
    curl -L "$SYNCTHING_URL" | tar xz --strip-components=1 -C ~/.local/bin --wildcards '*/syncthing'
    chmod +x ~/.local/bin/syncthing
fi

# Step 4: Configure Syncthing
echo ""
echo "=== Configuring Syncthing ==="

# Generate config if it doesn't exist
if [ ! -f ~/.config/syncthing/config.xml ]; then
    ~/.local/bin/syncthing generate --home ~/.config/syncthing
    
    # Keep default localhost binding for security
    # If remote access needed, use SSH tunneling:
    # ssh -L 8385:localhost:8384 user@ec2-ip
    
    # Get our device ID
    MY_DEVICE_ID=$(~/.local/bin/syncthing --device-id --home ~/.config/syncthing)
    echo "This device's Syncthing ID: $MY_DEVICE_ID"
fi

# Step 5: Setup systemd service
echo ""
echo "=== Setting up Syncthing service ==="

# Enable user lingering (allows services to run without active session)
loginctl enable-linger $USER

# Create systemd user service
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/syncthing.service << 'EOF'
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/syncthing serve --no-browser --home=%h/.config/syncthing
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable and start service
systemctl --user daemon-reload
systemctl --user enable syncthing
systemctl --user restart syncthing

# Wait for service to start
sleep 3

# Step 6: Create sync directories
echo ""
echo "=== Creating sync directories ==="
mkdir -p ~/common ~/work
echo "Created ~/common and ~/work directories for syncing"

# Step 7: Display connection info
echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Syncthing Web UI (local only): http://localhost:8384/"
echo "For remote access, use SSH tunneling: ssh -L 8385:localhost:8384 ${USER}@${MY_TAILSCALE_IP}"
echo ""
echo "Next steps (on desktop - Avalir):"
echo "1. Open Syncthing UI: http://localhost:8384/"
echo "2. Add this device with ID: $(~/.local/bin/syncthing --device-id --home ~/.config/syncthing)"
echo "3. Share these folders with this device:"
echo "   - 'common' folder (path: /export/proj/common)"
echo "   - 'work' folder (path: /export/work/ce)"
echo ""
echo "On this EC2 instance:"
echo "1. Accept the folder shares when they appear"
echo "2. Set folder paths to:"
echo "   - common: /home/${USER}/common"
echo "   - work: /home/${USER}/work"
echo ""
echo "To make this fully automated, consider:"
echo "- Setting autoAcceptFolders=true for this device on desktop"
echo "- Pre-configuring the folder share in this script"

# Step 8: Show service status
echo ""
echo "=== Service Status ==="
systemctl --user status syncthing --no-pager | head -15
echo ""
echo "Tailscale status:"
tailscale status | grep -E "(${DEVICE_NAME}|avalir)"