
# 📁 Action Plan: Synced EC2 Sandbox with Syncthing & Tailscale

**Owner**: Buddy Burden  
**Use Case**: Automate real-time, bidirectional file sync between Buddy's desktop and ephemeral EC2 sandboxes for personal scripts, config, and work data.  
**Primary Sync Target**: `~/common/` (GitHub repo: `barefootcoder/common`, also Syncthing shared folder)  

---

## 📦 System Overview

### Components

- **Syncthing**: Real-time, bidirectional sync with file versioning and `.stignore` support.
- **Tailscale**: Mesh VPN using WireGuard, enabling desktop ⇄ EC2 connectivity through NAT/firewalls.
- **GitHub Repo**: Public repo (`barefootcoder/common`) used as initial seed and encrypted secret store.

### Core Assumptions

- Desktop is the **central, trusted node**.
- EC2 sandboxes are **ephemeral**, **potentially multiple at once**, and **semi-public** (other devs may have `sudo`).
- Secrets must be **protected from sandbox users**.
- **Default Syncthing behavior is acceptable**, except swapfiles must be excluded.

---

## 🔐 Secrets Handling

### Design

- Secrets (Tailscale auth key, Syncthing API key, etc) are stored in the `common/` repo in encrypted form.
- Encryption uses **GPG** with Buddy’s public key committed in the repo.
- Decryption can only occur on the **desktop** (private key not shared).

### Implementation

- Secrets are stored in `common/bootstrap/secrets.env.gpg`.
- Format:
  ```env
  TAILSCALE_AUTHKEY=tskey-...
  SYNCTHING_API_KEY=...
  ```
- Secrets sync to EC2 only **after Syncthing is running**.
- If secrets are required earlier, they may be manually provided via prompt.

---

## 🔄 Syncthing Config Strategy

### Strategy: Hybrid Template + Manual Approval

- EC2 sandbox runs a startup script that:
  - Generates a new Syncthing config via `syncthing -generate`
  - Injects desktop's device ID and folder path (`common/`)
  - Starts Syncthing as user service
- Syncthing on desktop detects a **new device** and **requests folder access**.
- Desktop user:
  - Manually approves device via UI **or**
  - Runs `sync-approve.sh` (optional CLI helper script)

> Rationale: Avoids device ID collisions, supports multiple EC2 sandboxes, minimizes required scripting, and ensures only explicitly approved devices join the sync mesh.

---

## 🔧 EC2 Provisioning Steps

### High-Level Flow

1. Existing EC2 sandbox runs bootstrap script to launch new EC2 instance.
2. Bootstrap script (on new EC2) performs:
   - Tailscale install & auth (`--authkey`, ephemeral)
   - Syncthing install & config
   - Start Syncthing user service
   - (Optional) clone `common/` repo for initial static files

### Details

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey "$TAILSCALE_AUTHKEY" --hostname "quin-$(date +%s)" --ssh

# Install Syncthing
mkdir -p ~/.local/bin
curl -L https://github.com/syncthing/syncthing/releases/latest/download/syncthing-linux-amd64.tar.gz   | tar xz --strip-components=1 -C ~/.local/bin syncthing-linux-amd64/syncthing
chmod +x ~/.local/bin/syncthing

# Generate config and start Syncthing
~/.local/bin/syncthing -generate ~/.config/syncthing
loginctl enable-linger $USER
systemctl --user enable syncthing
systemctl --user start syncthing
```

---

## 🖥️ Desktop Configuration

### One-Time Setup

- Create GPG key and export public key to `common/keys/`
- Add `.stignore` to exclude:
  ```
  (?d).*.sw?
  (?d).*~
  (?d).git/
  ```

- Optional: Create CLI script `sync-approve.sh` to:
  - Detect untrusted devices
  - Approve them
  - Share `common/` folder

### On New EC2 Join

- Desktop detects new Syncthing device.
- Run approval script or use GUI to:
  - Approve device
  - Share `common/`
  - Optionally enable file versioning (desktop side only)

---

## 📋 Key Design Decisions & Rationale

| Decision | Reason |
|---------|--------|
| GPG-encrypted secrets in repo | Avoids cloud secrets manager; respects shared repo model |
| Device approval via desktop | Prevents unauthorized sandbox access; supports multi-EC2 |
| Templated Syncthing config | No static device ID assumptions; safe for simultaneous sandboxes |
| Swapfile ignore | Prevents infinite sync loops from `vim` artifacts |
| Manual bootstrapping script | Keeps startup logic separate from runtime config, avoids boot-time race |

---

## ✅ Completion Criteria

- EC2 sandbox can sync files with desktop over Tailscale + Syncthing
- Secrets are protected from sandbox users (GPG + decryption only on desktop)
- Bootstrap flow supports multiple sandboxes in parallel
- Minimal desktop-side manual intervention required (only device approval)
