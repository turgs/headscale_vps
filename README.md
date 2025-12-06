# headscale_vps

**One-command setup for Headscale VPN with built-in ad/porn blocking**

Automated script to provision an Ubuntu VPS as a Headscale server and exit node with AdGuard Home DNS filtering.

---

## 🚀 Quick Start

Run this one command on your fresh Ubuntu 22.04/24.04 VPS:

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

**What you get:**
- Headscale VPN server
- Exit node (route all traffic through VPS)
- Ad/tracking/porn blocking (AdGuard Home)
- Security hardening (SSH, firewall, fail2ban)

**Time:** ~10 minutes + automatic reboot

---

## 🌍 Choosing a VPS Location

**Not sure where to host your VPS?** See our [VPS Location Selection Guide](VPS_LOCATIONS.md) for:
- Performance vs. content access trade-offs
- Specific recommendations for Australia/Brisbane users
- How to access UK services (BBC iPlayer) from Australia
- Multi-VPS setup for best of both worlds

**Quick tip:** For Brisbane users, Singapore offers best performance (~100ms latency), while UK locations enable BBC iPlayer access (~300ms latency). Consider running both!

---

## 📖 Post-Installation Steps

### 1. Change AdGuard Home Password

**DO THIS FIRST for security!**

```
Visit: http://YOUR_SERVER_IP:3000
Login: admin / changeme
Settings → Change Password
```

### 2. Create Headscale User & Pre-Auth Key

SSH into your VPS (port 33003):

```bash
ssh deploy@YOUR_SERVER_IP -p 33003

# Create user
sudo headscale users create myuser

# Generate pre-auth key (save this!)
sudo headscale preauthkeys create --user myuser --reusable --expiration 24h
```

### 3. Connect Client Devices

#### Windows (For Non-Technical Users)

**Step 1: Install Tailscale**
1. Go to https://tailscale.com/download/windows
2. Download and install
3. Look for Tailscale icon in system tray (near clock)

**Step 2: Connect to Your VPN**
1. Right-click Tailscale icon
2. Click "Settings"
3. Find "Login Server" or "Custom Control Server"
4. Enter: `http://YOUR_SERVER_IP:8080`
5. Click "Save" then "Connect"
6. Browser will open - follow authorization

**Step 3: Use Exit Node (Route Traffic Through VPS)**
1. Right-click Tailscale icon again
2. Click "Exit Node"
3. Select your VPS name from the list
4. Done! All traffic now goes through your VPS

**To verify it's working:**
- Visit https://whatismyipaddress.com
- Should show your VPS IP (not home IP)

**To turn off:**
- Right-click Tailscale icon
- Uncheck "Use exit node"

#### Linux/macOS

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect
sudo tailscale up --login-server http://YOUR_SERVER_IP:8080

# Use exit node
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME
```

#### Android/iOS

1. Install Tailscale app from Play Store/App Store
2. Open app → Settings
3. "Use alternate server" or "Login server"
4. Enter: `http://YOUR_SERVER_IP:8080`
5. Connect
6. Tap Settings → "Exit Node" → Select your VPS

---

## 🛡️ What Gets Blocked (AdGuard Home)

**Automatically blocked:**
- ✅ Ads on websites and apps
- ✅ Tracking scripts
- ✅ Adult/porn websites
- ✅ Known malware domains

**NOT blocked:**
- ❌ YouTube (works normally)
- ❌ Social media (unless you block it)
- ❌ Legitimate sites

**To allow a blocked site:**
```bash
ssh deploy@YOUR_SERVER_IP -p 33003
# Edit /opt/adguardhome/conf/AdGuardHome.yaml
# Add to user_rules: @@||example.com^$important
sudo systemctl restart adguardhome
```

---

## 🔧 Configuration Options

When running the provision script, you can customize:

```bash
provision_vps.sh --help

Options:
  --ssh-key=KEY          Your SSH public key
  --ssh-port=PORT        SSH port (default: 33003)
  --domain=DOMAIN        Domain for Headscale (optional)
  --swap-size=SIZE       Swap size (default: 2G)
```

---

## ⚠️ Important Notes

**Security:**
- SSH is on port **33003** (not 22)
- Deploy user: `deploy` (SSH key only)
- Root: password access (emergency only)

**Performance:**
- Speed limited by VPS bandwidth
- HostHatch typically provides 1 Gbps

**Privacy:**
- Your VPS provider can see traffic
- Better privacy than ISP directly
- Not anonymous (VPS traceable to you)

**For Family Use:**
- Ad/porn blocking enabled by default
- Can't be easily disabled by users
- Monitor at: `http://YOUR_SERVER_IP:3000`

---

## 🆘 Troubleshooting

**Can't SSH after reboot?**
```bash
# Wait 2-3 minutes, then use port 33003:
ssh deploy@YOUR_SERVER_IP -p 33003
```

**Headscale not working?**
```bash
ssh deploy@YOUR_SERVER_IP -p 33003
sudo systemctl status headscale
sudo journalctl -u headscale -f
```

**Exit node not routing traffic?**
```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward  # Should be 1

# Check routes
sudo headscale routes list
sudo headscale routes enable -r <route-id>
```

---

## 📚 Additional Documentation

- **[VPS_LOCATIONS.md](VPS_LOCATIONS.md)** - VPS location selection guide
- **[QUICKSTART.md](QUICKSTART.md)** - Step-by-step setup guide
- **Headscale docs:** https://headscale.net/
- **Tailscale docs:** https://tailscale.com/kb/

---

## 📁 Repository Files

```
├── provision_vps.sh          # Main setup script (run this)
├── setup_exit_node.sh        # Post-install exit node helper
├── test_setup.sh             # Remote VPS verification
└── config/
    ├── deploy.yml            # Kamal config (for updates)
    └── headscale-config.yaml # Headscale template
```

---

## License

MIT License - See LICENSE file for details
