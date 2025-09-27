# EC2 Sync Proof-of-Concept Results

**Date**: 2025-09-12
**EC2 Instance**: quin-<INSTANCE_ID>
**Desktop**: Avalir

## Successfully Completed Steps

### 1. Tailscale Installation & Configuration

**Installation on EC2:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

**Configuration:**
```bash
sudo tailscale up --authkey "tskey-auth-xxx" --hostname "quin-$(date +%s)" --ssh
```

**Results:**
- EC2 hostname: quin-{timestamp}
- Bidirectional connectivity confirmed (ping latency ~77-80ms)
- IPs and credentials: See `private/ec2-sync-credentials.md`

### 2. Syncthing Installation & Configuration

**Installation on EC2:**
```bash
# Get latest version URL
curl -s https://api.github.com/repos/syncthing/syncthing/releases/latest | \
  grep "browser_download_url.*linux-amd64" | grep -v ".asc" | cut -d\" -f4

# Install (v2.0.8)
mkdir -p ~/.local/bin
curl -L https://github.com/syncthing/syncthing/releases/download/v2.0.8/syncthing-linux-amd64-v2.0.8.tar.gz | \
  tar xz --strip-components=1 -C ~/.local/bin syncthing-linux-amd64-v2.0.8/syncthing
chmod +x ~/.local/bin/syncthing
```

**Configuration:**
```bash
# Generate config (note: v2 uses different syntax)
~/.local/bin/syncthing generate --home ~/.config/syncthing

# Enable user lingering for systemd services
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
systemctl --user enable syncthing
systemctl --user start syncthing
```

**Results:**
- Both services running successfully
- Device IDs stored in `private/ec2-sync-credentials.md`

## Lessons Learned

### Key Findings

1. **Tailscale Auth Key Requirements:**
   - Need reusable, ephemeral auth key for automation
   - SSH flag allows interactive auth but not suitable for scripts
   - Auth key should be stored encrypted (GPG) as per action plan

2. **Syncthing v2 Changes:**
   - Command syntax changed: `syncthing generate --home` instead of `syncthing -generate`
   - Must use `--home` flag (not separate --config/--data)
   - Service command: `syncthing serve` instead of just `syncthing`

3. **Systemd User Services:**
   - `loginctl enable-linger` required for services to run without active session
   - User services stored in `~/.config/systemd/user/`
   - Service starts automatically on boot after enabling

4. **Network Connectivity:**
   - Tailscale provides reliable mesh VPN connectivity
   - ~77-80ms latency between Avalir and EC2 (acceptable for file sync)
   - No firewall changes needed on either end

## Successfully Tested Features

### 3. Device Pairing & Folder Sharing

**Manual Steps Required:**
1. Added EC2 device to Avalir via Syncthing UI
2. Created folder shares:
   - "repo-common" (`/export/proj/common` → `~/common`)
   - "work-ce" (`/export/work/ce` → `~/work`) 
   - "repo-CE" (`~/workproj/CE-mounted` → `~/CE`)
3. Shared with EC2 device only
4. Accepted folders on EC2 side with appropriate paths

**Sync Test Results:**
- File created on Avalir synced to EC2 immediately
- File created on EC2 synced to Avalir within 3 seconds
- Bidirectional sync confirmed working
- Multiple folders syncing without issues
- Files maintain correct permissions and timestamps

### 4. Security Configuration

**Implemented:**
- Changed EC2 Syncthing to localhost-only binding (127.0.0.1:8384)
- Access via SSH tunnel: `cessh --tunnel 8388:localhost:8384 <instance>`
- No password needed for ephemeral single-user instances

## Next Steps

1. **Security Setup**: Implement GPG encryption for secrets
2. **Automation Script**: Create bootstrap script based on these findings
3. **Auto-accept Configuration**: Enable auto-accept folders for automation
4. **Cleanup Process**: Define ephemeral device removal procedure

## Automation Considerations

### For Full Automation

1. **Tailscale Auth Key**: Store encrypted in repo, decrypt on desktop only
2. **Syncthing Auto-Accept**: Set `autoAcceptFolders: true` for EC2 device on Avalir
3. **Folder Pre-Configuration**: Include folder config in bootstrap script
4. **API Authentication**: Consider setting up API key for programmatic control

### Semi-Automated Approach (Acceptable)

1. EC2 runs bootstrap script to install/configure services
2. Desktop user manually:
   - Approves new Syncthing device
   - Shares common folder with device
3. EC2 auto-accepts shared folders

## Potential Issues to Address

1. **Device Naming**: Consider more descriptive names (include user/purpose)
2. **Cleanup Process**: Remove devices from Syncthing when EC2 terminated
3. **Monitoring**: Add health checks for both services
4. **.stignore Configuration**: Add swap files and temp files patterns

## Key Files Created

1. **`ec2-sync-bootstrap.sh`** - Bootstrap script for new EC2 instances
2. **`sandbox-setup`** - Local script to setup tunnels and connections
3. **`EC2-sync-automation-roadmap.md`** - Detailed automation implementation guide

## Current Working Setup

- **EC2 Instance**: See `private/ec2-sync-credentials.md`
- **Folders Syncing**: common, work-ce, repo-CE
- **Access**: Via SSH tunnel on port 8388
- **Credentials**: Stored in `private/` directory

## Commands for Manual Testing

```bash
# Setup sandbox connections (run on Avalir)
sandbox-setup <INSTANCE_ID>

# Check Tailscale status
tailscale status
tailscale ip -4

# Check Syncthing status
systemctl --user status syncthing
syncthing --device-id --home ~/.config/syncthing

# Test connectivity
ping <tailscale-ip>

# Access Syncthing UI
# On Avalir: http://localhost:8388 (via tunnel)
# On EC2: http://localhost:8384 (local only)
```

## Important Notes for Future Agents

1. **Check private directory for credentials** - `private/ec2-sync-credentials.md`
2. **Tailscale auth key expires in 90 days** - Generate new one when needed
3. **Syncthing v2 syntax changes** - Use `generate --home` not `-generate`
4. **Use localhost binding for security** - Remote access via SSH tunnel only
5. **cessh is required** - Standard SSH won't work through the proxy
6. **Manual approval currently required** - See roadmap for automation options