# Quick Start Guide

Get your Headscale VPS up and running in minutes!

## Prerequisites

- A fresh Ubuntu 22.04 or 24.04 VPS (HostHatch or any provider)
- SSH access as root
- Your SSH public key (optional but recommended)

## Step 1: Provision the VPS

### Option A: One-Liner (Simplest)

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

### Option B: With Your SSH Key

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)"
```

### Option C: With Domain

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="headscale.yourdomain.com"
```

**What it does:**
- Installs Headscale server
- Installs Tailscale client
- **Installs AdGuard Home** (ad/tracking/porn blocking)
- Configures firewall (UFW)
- Sets up fail2ban
- Enables IP forwarding
- Creates deploy user
- Hardens SSH (port 33003)

**Time:** ~5-10 minutes + reboot

**DNS Filtering:** Ad blocking, tracking protection, and porn filtering are automatically enabled for all VPN users!

---

## Step 2: Wait for Reboot

The server will automatically reboot after provisioning. Wait 2-3 minutes.

---

## Step 3: Setup Exit Node

SSH into your VPS:

```bash
ssh deploy@YOUR_SERVER_IP -p 33003
```

Run the exit node setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/setup_exit_node.sh | bash
```

This will:
1. Create a Headscale user (or use existing)
2. Generate a pre-auth key
3. Connect the VPS as an exit node

**Save the pre-auth key shown!**

---

## Step 4: Connect Client Devices

### On your laptop/phone/etc:

#### Linux/macOS:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to your Headscale server
sudo tailscale up --login-server http://YOUR_SERVER_IP:8080
```

#### Windows (Step-by-Step):

1. Download Tailscale from https://tailscale.com/download/windows
2. Run the installer and follow the wizard
3. After installation, find the Tailscale icon in your system tray (near clock)
4. Right-click the icon → "Settings"
5. Find "Login Server" or "Custom Control Server"
6. Enter: `http://YOUR_SERVER_IP:8080` (use your actual VPS IP)
7. Click "Save" then "Connect"
8. After connected, right-click icon again → "Exit Node" → Select your VPS
9. You're now routing through your VPS!

**To verify:** Visit https://whatismyipaddress.com - you should see your VPS IP

---

## Step 5: Use the Exit Node

### On client devices:

```bash
# See available exit nodes
tailscale exit-node list

# Use your VPS as exit node
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME
```

Or use the Tailscale GUI to select the exit node.

---

## Verify It's Working

Check your IP address:

```bash
curl ifconfig.me
```

Should show your VPS's IP address!

---

## Troubleshooting

### Can't SSH after provisioning?

Wait 3 minutes for reboot, then:

```bash
ssh deploy@YOUR_SERVER_IP -p 33003
```

### Headscale not responding?

```bash
ssh deploy@YOUR_SERVER_IP -p 33003
sudo systemctl status headscale
sudo journalctl -u headscale -f
```

### Exit node not working?

```bash
# On VPS
sudo headscale routes list
sudo headscale routes enable -r <route-id>

# Check IP forwarding
sysctl net.ipv4.ip_forward  # Should be 1
```

---

## Test Your Setup

Run the automated test:

```bash
# From your local machine
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/test_setup.sh | bash -s YOUR_SERVER_IP
```

---

## Managing DNS Filtering

Your VPS now blocks ads, tracking, and adult content automatically!

### Change AdGuard Home Password

**IMPORTANT:** Change the default password immediately:

1. Visit `http://YOUR_SERVER_IP:3000`
2. Login with `admin` / `changeme`
3. Go to Settings → Change Password

### Allow/Block Specific Domains

To allow a blocked site, edit the AdGuard Home config:

```bash
# SSH into your VPS
ssh deploy@YOUR_SERVER_IP -p 33003

# Edit config file
sudo nano /opt/adguardhome/conf/AdGuardHome.yaml

# Add to user_rules section:
# @@||example.com^$important

# Restart AdGuard Home
sudo systemctl restart adguardhome
```

Or use the web UI at `http://YOUR_SERVER_IP:3000` → Filters → Custom filtering rules

### What's Blocked by Default?

✅ Ads and tracking
✅ Adult/porn websites
✅ Known malware domains
❌ YouTube (works normally)
❌ Legitimate sites

---

## Next Steps

- **Add more devices**: Use the same `tailscale up` command on other devices
- **Create more users**: `sudo headscale users create username`
- **Configure ACLs**: Edit `/etc/headscale/config.yaml`
- **Setup HTTPS**: Add a reverse proxy (Caddy/Nginx)
- **Monitor DNS filtering**: Visit `http://YOUR_SERVER_IP:3000`

---

## Useful Commands

```bash
# List connected nodes
sudo headscale nodes list

# List users
sudo headscale users list

# Generate new pre-auth key
sudo headscale preauthkeys create --user myuser --reusable --expiration 24h

# Check Tailscale status on VPS
sudo tailscale status

# View Headscale logs
sudo journalctl -u headscale -f

# View AdGuard Home logs
sudo journalctl -u adguardhome -f

# Restart services
sudo systemctl restart headscale
sudo systemctl restart adguardhome
```

---

## Security Notes

- SSH is on port **33003** (not 22)
- fail2ban is active with 24-hour bans
- Firewall (UFW) is configured
- Deploy user has sudo access
- Root login requires password (emergency access)

---

## Support

- Full docs: [README.md](README.md)
- Headscale docs: https://headscale.net/
- Issues: https://github.com/turgs/headscale_vps/issues

---

**Enjoy your self-hosted VPN!** 🎉
