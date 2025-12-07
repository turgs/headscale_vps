# headscale_vps

**One-command setup for Headscale VPN with built-in ad/porn blocking**

Automated script to provision an Ubuntu VPS as a Headscale server and exit node with AdGuard Home DNS filtering.

---

## 🚀 Quick Start

Run this one command on your fresh Ubuntu 22.04/24.04 VPS:

```bash
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

**What you get:**
- Headscale VPN server
- Exit node (route all traffic through VPS)
- Ad/tracking/porn blocking (AdGuard Home)
- Security hardening (SSH, firewall, fail2ban)

**Time:** ~10 minutes + automatic reboot

---

## 📖 Post-Installation Steps

### 1. Change AdGuard Home Password

**What is AdGuard Home?**
AdGuard Home is a DNS-based ad blocker and privacy protection tool that runs on your VPS. It blocks:
- Advertisements on websites and apps
- Tracking/analytics scripts
- Adult/pornographic content
- Known malware domains

All devices connected to your VPN automatically use AdGuard Home for DNS filtering.

**DO THIS FIRST for security!**

The default admin credentials need to be changed immediately to prevent unauthorized access to your DNS filtering settings.

```
Visit: http://robin-easy.bnr.la:3000
Login: admin / changeme
Settings → Change Password
```

**Note:** 
- Access via your domain name (robin-easy.bnr.la) or IP address (103.100.37.13).
- AdGuard Home UI uses HTTP (not HTTPS) on port 3000. While this port is accessible from the internet, **changing the password immediately** secures your DNS filtering settings.
- For enhanced security, you can restrict port 3000 access to only your VPN network after changing the password (see Security Best Practices below).

### 2. Create Headscale User & Pre-Auth Key

**What you need to do as admin:**

To connect devices to your VPN, you need to:
1. Create a Headscale user (one per person or device group)
2. Generate a pre-authentication key for that user
3. Share the key with the device owner to connect their devices

SSH into your VPS (port 33003):

```bash
ssh deploy@robin-easy.bnr.la -p 33003
# Or using IP: ssh deploy@103.100.37.13 -p 33003

# Create user (e.g., for family members: mom, dad, child1)
sudo headscale users create myuser

# Generate pre-auth key (save this!)
sudo headscale preauthkeys create --user myuser --reusable --expiration 24h
```

**Pre-auth keys allow devices to automatically join your VPN without manual approval.**

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
4. Enter: `https://robin-easy.bnr.la` (use your domain)
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

# Connect (use your domain with HTTPS)
sudo tailscale up --login-server https://robin-easy.bnr.la

# Use exit node (replace with your actual VPS hostname from 'tailscale status')
sudo tailscale set --exit-node robin-easy
```

#### Android/iOS

1. Install Tailscale app from Play Store/App Store
2. Open app → Settings
3. "Use alternate server" or "Login server"
4. Enter: `https://robin-easy.bnr.la` (use your domain)
5. Connect
6. Tap Settings → "Exit Node" → Select your VPS

---

## 🔐 Security Best Practices

### Restrict AdGuard Home Access (Optional but Recommended)

After changing the AdGuard Home password, you can restrict port 3000 access to only your VPN network:

```bash
ssh deploy@robin-easy.bnr.la -p 33003

# Remove public access to AdGuard Home UI
sudo ufw delete allow 3000/tcp

# Allow access only from VPN network (100.64.0.0/10 is the CGNAT range used by Headscale)
sudo ufw allow from 100.64.0.0/10 to any port 3000 proto tcp comment 'AdGuard Home UI - VPN only'

# Reload firewall
sudo ufw reload
```

After this change, you can only access AdGuard Home when connected to your VPN, providing an additional security layer.

---

## 🛡️ DNS Filtering & Blocking

### Three Operation Modes

**1. Full VPN with Ad/Porn Blocking (Most Protected)**
- Enable VPN exit node on device
- All traffic routes through VPS
- DNS filtering blocks ads, tracking, and adult content
- Your IP appears as the VPS location

**2. Clean Browsing Only (DNS Filtering without VPN)**
- Connect to VPN but don't enable exit node
- Only DNS queries go through VPS
- Get ad/porn blocking without routing all traffic
- Keep your regular IP address
- **LAN devices remain accessible** (printers, NAS, etc. work normally)

**3. VPN Off (No Filtering)**
- Disconnect from VPN entirely
- Normal internet access
- No ad blocking or filtering

### Managing DNS Filters (GitOps Workflow)

Edit DNS filters via GitHub - changes deploy automatically:

**1. Edit filter files on GitHub:**
- `config/dns-allowlist.txt` - Domains to never block
- `config/dns-blocklist.txt` - Additional domains to block

**2. Commit changes to main branch**

**3. GitHub Actions automatically deploys to your VPS**

**Example - Allow a blocked site:**
```txt
# In config/dns-allowlist.txt, add:
facebook.com
instagram.com
```

**Example - Block additional sites:**
```txt
# In config/dns-blocklist.txt, add:
gambling-site.com
distracting-game.com
```

**Benefits:**
- ✅ Edit via GitHub web UI (no SSH needed)
- ✅ Track all changes with git history
- ✅ Automatic deployment
- ✅ Rollback capability if something breaks

### Default Blocking Behavior

**Automatically blocked:**
- ✅ Ads on websites and apps
- ✅ Tracking scripts
- ✅ Adult/porn websites
- ✅ Known malware domains

**NOT blocked by default:**
- ❌ YouTube (works normally)
- ❌ Social media (unless you add to blocklist)
- ❌ Legitimate sites

### Manual DNS Filter Management (Alternative)

If you prefer SSH instead of GitOps:

```bash
ssh deploy@robin-easy.bnr.la -p 33003

# Edit AdGuard Home config
sudo nano /opt/adguardhome/conf/AdGuardHome.yaml

# Add to user_rules section:
# Allow a domain: @@||example.com^$important
# Block a domain: ||badsite.com^

sudo systemctl restart adguardhome
```

**Note:** GitOps method is recommended for easier management and change tracking.

---

## 🔧 Configuration Options

When running the provision script, you can customize:

```bash
provision_vps.sh --help

Options:
  --ssh-key=KEY          Your SSH public key
  --ssh-port=PORT        SSH port (default: 33003)
  --domain=DOMAIN        Domain for Headscale (enables HTTPS with Caddy)
  --swap-size=SIZE       Swap size (default: 2G)
```

### Example with Domain (Recommended)

Using a domain enables automatic HTTPS with Let's Encrypt:

```bash
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --domain="robin-easy.bnr.la"
```

**Important**: Binary Lane provides the domain `robin-easy.bnr.la` automatically - no DNS setup needed!
- No need to purchase a separate domain
- DNS already points to your VPS (103.100.37.13)
- Port 80 and 443 are accessible for Let's Encrypt

---

## 🤖 GitOps DNS Management

**Quick Setup:**

1. Fork this repo
2. Update `config/vps-config.txt` with your VPS details (if different)
3. Add GitHub Secret (Settings → Secrets → Actions):
   - `VPS_SSH_KEY` - Your SSH private key (only secret needed!)
4. Edit `config/dns-allowlist.txt` or `config/dns-blocklist.txt` on GitHub
5. Commit → Auto-deploys to VPS

**Files:** One domain per line, `#` for comments
```txt
youtube.com
facebook.com  # comment
```

**Manual deploy:** `./scripts/deploy-dns.sh --host=robin-easy.bnr.la`

**Detailed setup guide:** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

---

## ⚠️ Important Notes

**Security:**
- SSH is on port **33003** (not 22)
- Deploy user: `deploy` (SSH key only)
- Root: password access (emergency only)

**Performance:**
- Speed limited by VPS bandwidth
- Binary Lane typically provides 1 Gbps

**Privacy:**
- Your VPS provider can see traffic
- Better privacy than ISP directly
- Not anonymous (VPS traceable to you)

**For Family Use:**
- Ad/porn blocking enabled by default
- Can't be easily disabled by users
- Monitor at: `http://robin-easy.bnr.la:3000` (use your domain)

---

## 🆘 Troubleshooting

**Can't SSH after reboot?**
```bash
# Wait 2-3 minutes, then use port 33003:
ssh deploy@robin-easy.bnr.la -p 33003
# Or: ssh deploy@103.100.37.13 -p 33003
```

**Headscale not working?**
```bash
ssh deploy@robin-easy.bnr.la -p 33003
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

## 🔀 Split Tunneling & Access Control

Want to route only specific traffic through your VPN? Or control which family members can access which devices?

See **[SPLIT_TUNNELING.md](SPLIT_TUNNELING.md)** for:
- Per-device split tunneling (easiest for families)
- DNS-only mode (ad blocking without full VPN)
- ACL configuration (user access control)
- Simple instructions for non-technical users

**Quick ACL Setup:**
```bash
# Edit ACL policy
sudo nano /etc/headscale/acl.yaml

# Apply changes
sudo systemctl reload headscale
```

## 🔒 HTTPS Setup

When you provide a domain using `--domain=robin-easy.bnr.la`, the script automatically:
- Installs Caddy reverse proxy
- Configures automatic HTTPS with Let's Encrypt
- Sets up security headers
- Enables HTTP/2

**For Binary Lane VPS:**
- Domain `robin-easy.bnr.la` is provided automatically
- DNS already configured (points to 103.100.37.13)
- No domain purchase needed
- Ports 80 and 443 are open by default

## 📚 Additional Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Step-by-step setup guide
- **[ADMIN_GUIDE.md](ADMIN_GUIDE.md)** - Admin reference (users, ACLs, backups)
- **[SPLIT_TUNNELING.md](SPLIT_TUNNELING.md)** - Split tunneling guide
- **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - GitHub Actions automation setup
- **Headscale:** https://headscale.net/
- **Tailscale:** https://tailscale.com/kb/

---

## 📁 Repository Files

```
├── provision_vps.sh          # Main setup script (run this)
├── setup_exit_node.sh        # Post-install exit node helper
├── test_setup.sh             # Remote VPS verification
├── QUICKSTART.md             # Quick setup guide
├── ADMIN_GUIDE.md            # Admin reference
├── SPLIT_TUNNELING.md        # Split tunneling guide
├── .github/
│   └── workflows/
│       └── deploy-dns.yml    # GitHub Actions workflow for DNS deployment
├── scripts/
│   └── deploy-dns.sh         # DNS deployment script
└── config/
    ├── vps-config.txt        # VPS configuration (provider, domain, IP)
    ├── deploy.yml            # Kamal config (for updates)
    ├── headscale-config.yaml # Headscale configuration template
    ├── acl.yaml              # ACL policy template
    ├── dns-allowlist.txt     # DNS domains to never block (GitOps)
    └── dns-blocklist.txt     # Additional DNS domains to block (GitOps)
```

---

## License

MIT License - See LICENSE file for details
