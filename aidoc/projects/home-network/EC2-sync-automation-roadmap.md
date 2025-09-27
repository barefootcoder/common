# EC2 Sync Automation Roadmap

**Purpose**: Guide for implementing full automation of EC2 sandbox sync setup  
**Current State**: Semi-automated (manual device approval required)  
**Goal**: Fully automated bidirectional sync on EC2 launch

## Current Semi-Automated Process

1. EC2 runs bootstrap script with Tailscale auth key
2. Desktop user manually approves Syncthing device
3. Desktop user shares folder with new device
4. EC2 accepts folder share (can be automated)

## Full Automation Implementation

### Option 1: Auto-Accept Configuration (Simplest)

**Desktop Side (Avalir) - One-time setup:**
```bash
# Edit Syncthing config to auto-accept folders from EC2 devices
# In ~/.config/syncthing/config.xml, for EC2 device entries:
<device id="DEVICE-ID" ...>
    <autoAcceptFolders>true</autoAcceptFolders>
</device>
```

**EC2 Side - Bootstrap additions:**
```bash
# Add desktop device with auto-accept and pre-configured folders
cat >> ~/.config/syncthing/config.xml << EOF
<device id="<AVALIR_DEVICE_ID>" name="avalir">
    <autoAcceptFolders>false</autoAcceptFolders>
</device>
<folder id="proj-common" label="common" path="/home/$USER/common">
    <device id="<AVALIR_DEVICE_ID>"/>
    <device id="MY-DEVICE-ID"/>
</folder>
<folder id="work" label="Work" path="/home/$USER/work">
    <device id="<AVALIR_DEVICE_ID>"/>
    <device id="MY-DEVICE-ID"/>
</folder>
EOF
```

### Option 2: API-Based Configuration

**Prerequisites:**
- Generate Syncthing API key on both sides
- Store API keys securely (encrypted in repo)

**Implementation:**
```bash
# On EC2, after Syncthing starts
DESKTOP_API_KEY="encrypted-key-here"
EC2_DEVICE_ID=$(syncthing --device-id)

# Add this device to desktop's Syncthing
curl -X PUT \
  -H "X-API-Key: $DESKTOP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"deviceID\": \"$EC2_DEVICE_ID\", \"name\": \"$DEVICE_NAME\"}" \
  http://$DESKTOP_TAILSCALE_IP:8384/rest/config/devices

# Share folder with this device
curl -X PATCH \
  -H "X-API-Key: $DESKTOP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"devices\": [{\"deviceID\": \"$EC2_DEVICE_ID\"}]}" \
  http://$DESKTOP_TAILSCALE_IP:8384/rest/config/folders/proj-common
```

### Option 3: Pre-Shared Configuration Templates

**Setup:**
1. Create template configs with placeholders
2. Store in `common/bootstrap/syncthing-templates/`
3. Bootstrap script fills in device-specific values

**Template Example (`config-template.xml`):**
```xml
<configuration version="37">
    <folder id="proj-common" label="common" path="/home/{{USER}}/common">
        <device id="<AVALIR_DEVICE_ID>"/>
        <device id="{{DEVICE_ID}}"/>
    </folder>
    <device id="<AVALIR_DEVICE_ID>" name="avalir">
        <address>tcp://{{DESKTOP_IP}}:22000</address>
    </device>
</configuration>
```

## Secrets Management

### Current Approach (Manual)
- Tailscale auth key provided at runtime
- No stored credentials

### Automated Approach

**1. GPG Encryption (Recommended):**
```bash
# On desktop, create encrypted secrets file
cat > ~/common/bootstrap/secrets.env << EOF
TAILSCALE_AUTHKEY=tskey-auth-xxx
SYNCTHING_API_KEY=xxx
EOF

gpg --encrypt --recipient buddy@example.com \
    ~/common/bootstrap/secrets.env

# On EC2, decrypt (requires private key - security risk!)
gpg --decrypt ~/common/bootstrap/secrets.env.gpg
```

**2. AWS Secrets Manager (If Available):**
```bash
# Store secrets in AWS
aws secretsmanager create-secret \
    --name ec2-sync-secrets \
    --secret-string '{"tailscale_key":"xxx","syncthing_api":"xxx"}'

# Retrieve in bootstrap script
SECRETS=$(aws secretsmanager get-secret-value \
    --secret-id ec2-sync-secrets \
    --query SecretString --output text)
```

**3. Desktop-Side Script (Most Secure):**
- Desktop runs script that SSHs to EC2 with secrets
- Never store secrets on EC2
- Requires desktop to be online during EC2 launch

## Device Cleanup

### Manual Cleanup
1. When EC2 terminates, remove from Tailscale admin
2. Remove device from Syncthing on desktop

### Automated Cleanup

**Option 1: Expiring Devices:**
- Use ephemeral Tailscale keys (auto-cleanup)
- Set device expiry in Syncthing (not built-in, needs scripting)

**Option 2: Termination Hook:**
```bash
# Add to EC2 user data or systemd service
cat > /etc/systemd/system/cleanup-sync.service << EOF
[Unit]
Description=Cleanup sync on shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup-sync.sh
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target
EOF

# Cleanup script
cat > /usr/local/bin/cleanup-sync.sh << EOF
#!/bin/bash
# Notify desktop to remove this device
curl -X DELETE \
  -H "X-API-Key: $API_KEY" \
  http://$DESKTOP_IP:8384/rest/config/devices/$DEVICE_ID
EOF
```

## Multiple Folder Configuration

### Standard Folder Set for EC2 Sandboxes

**Folders to sync:**
1. **common** (`/export/proj/common` → `~/common`): Personal scripts, configs, documentation
2. **work** (`/export/work/ce` → `~/work`): Work-related files and projects

**Desktop (Avalir) folder configurations:**
```xml
<folder id="proj-common" label="common" path="/export/proj/common">
    <!-- Shared with EC2 sandboxes only -->
</folder>
<folder id="work" label="Work" path="/export/work/ce">
    <!-- Shared with EC2 sandboxes only -->
</folder>
```

**EC2 folder paths:**
- `~/common` - Personal utilities and configs
- `~/work` - Work files

**Bootstrap script additions:**
```bash
# Create all sync directories
mkdir -p ~/common ~/work

# When using API or config templates, include both folders
FOLDERS=("proj-common:common:/home/$USER/common" "work:Work:/home/$USER/work")
for folder in "${FOLDERS[@]}"; do
    IFS=':' read -r id label path <<< "$folder"
    # Add folder configuration
done
```

## Advanced Features

### 1. Selective Sync with .stignore
```bash
# Create .stignore in common folder
cat > ~/common/.stignore << 'EOF'
# Swap files
(?d).*.sw?
(?d).*~

# OS files
.DS_Store
Thumbs.db

# Temp files
(?d)*.tmp
(?d)*.temp

# Large files (optional)
(?d)*.iso
(?d)*.zip
EOF
```

### 2. Folder Profiles
Different sync configs for different use cases:
- `common-full`: Everything in common/
- `common-code`: Only code files (*.pl, *.pm, *.sh, etc.)
- `common-config`: Only config files (rc/*, conf/*)

### 3. Health Monitoring
```bash
# Add to EC2 crontab
*/5 * * * * /usr/local/bin/check-sync-health.sh

# Health check script
#!/bin/bash
if ! systemctl --user is-active syncthing >/dev/null; then
    systemctl --user restart syncthing
    echo "Restarted Syncthing at $(date)" >> ~/sync-health.log
fi

if ! tailscale status >/dev/null 2>&1; then
    echo "Tailscale down at $(date)" >> ~/sync-health.log
    # Could trigger re-auth here
fi
```

## Testing Automation

### Test Scenarios
1. **Fresh EC2 with no prior setup**
2. **EC2 with existing (different) Syncthing config**
3. **Network interruption during initial sync**
4. **Desktop offline during EC2 launch**
5. **Multiple EC2 instances simultaneously**

### Validation Checks
```bash
# Verify sync is working
echo "test-$(date +%s)" > ~/common/sync-test
sleep 5
ssh desktop "cat ~/common/sync-test"

# Check both directions
ssh desktop "echo 'desktop-test' > ~/common/sync-test2"
sleep 5
cat ~/common/sync-test2
```

## Implementation Priority

1. **Phase 1** (Current): Manual approval, working sync
2. **Phase 2**: Auto-accept folders on desktop side
3. **Phase 3**: API-based device addition
4. **Phase 4**: Encrypted secrets management
5. **Phase 5**: Automated cleanup on termination

## Notes for Future Implementation

- Consider using Syncthing's relay servers if direct connection fails
- Watch for Syncthing v2 API changes (different from v1)
- Test with large files and many small files
- Consider bandwidth limits for large syncs
- May want different ignore patterns for different EC2 purposes
- Could use Tailscale ACLs to restrict EC2 access to only Syncthing ports

## References

- [Syncthing API Docs](https://docs.syncthing.net/dev/rest.html)
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys)
- [Syncthing Auto-Accept](https://docs.syncthing.net/users/config.html#device-element)
- Tailscale auth key stored in: `private/ec2-sync-credentials.md`