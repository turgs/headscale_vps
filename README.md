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

## 📖 Post-Installation Steps

### 1. Change AdGuard Home Password

**DO THIS FIRST for security!**

```
Visit: http://vpn.bethanytim.com:3000 (or http://YOUR_DOMAIN:3000)
Login: admin / changeme
Settings → Change Password
```

**Note:** Access via your domain name (not IP address) for security and convenience.

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
4. Enter: `https://vpn.bethanytim.com` (use your domain)
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
sudo tailscale up --login-server https://vpn.bethanytim.com

# Use exit node
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME
```

#### Android/iOS

1. Install Tailscale app from Play Store/App Store
2. Open app → Settings
3. "Use alternate server" or "Login server"
4. Enter: `https://vpn.bethanytim.com` (use your domain)
5. Connect
6. Tap Settings → "Exit Node" → Select your VPS

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
ssh deploy@vpn.bethanytim.com -p 33003

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
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --domain="vpn.bethanytim.com"
```

**Important**: Before running with a domain, make sure:
1. You own the domain
2. DNS A record points to your VPS IP address
3. Port 80 and 443 are accessible (for Let's Encrypt verification)

---

## 🤖 GitOps DNS Filter Management (Advanced)

Manage your DNS filters using Git and GitHub Actions for automated deployment.

### Setup Requirements

1. **Fork or clone this repository**
2. **Configure GitHub Secrets:**
   - Go to your repository → Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `VPS_HOST`: Your VPS domain or IP (e.g., `vpn.bethanytim.com`)
     - `VPS_SSH_KEY`: Your SSH private key for the deploy user
     - `VPS_SSH_PORT`: (Optional) SSH port (default: 33003)
     - `VPS_SSH_USER`: (Optional) SSH user (default: deploy)

### How It Works

1. **Edit DNS filter files** in the GitHub web UI or locally:
   - `config/dns-allowlist.txt` - Domains to never block
   - `config/dns-blocklist.txt` - Additional domains to block

2. **Commit and push** to the main branch

3. **GitHub Actions automatically**:
   - Validates the DNS configuration
   - Deploys to your VPS via SSH
   - Updates AdGuard Home configuration
   - Reloads the service
   - Rolls back on failure

### File Format

One domain per line, comments with `#`:

```txt
# This is a comment
example.com
subdomain.example.com

# Inline comments are supported too
another-domain.com  # This domain is important
```

### Testing Changes

You can test deployment without making changes:

1. Go to Actions tab in your repository
2. Click "Deploy DNS Filters" workflow
3. Click "Run workflow"
4. Check "Run in dry-run mode"
5. Review the output to see what would be deployed

### Viewing Deployment History

- Go to Actions tab to see all deployments
- Each deployment shows:
  - Which files changed
  - How many domains were added/removed
  - Deployment status (success/failure)
  - Complete deployment logs

### Rollback

If a deployment causes issues:

1. Go to the repository commits
2. Find the last working commit
3. Revert the problematic commit
4. Push - this triggers automatic redeployment

Or manually rollback via SSH:
```bash
ssh deploy@vpn.bethanytim.com -p 33003
sudo cp /opt/adguardhome/conf/AdGuardHome.yaml.backup.* /opt/adguardhome/conf/AdGuardHome.yaml
sudo systemctl restart adguardhome
```

### Manual Deployment

You can also run the deployment script locally:

```bash
# From repository root
./scripts/deploy-dns.sh --host=vpn.bethanytim.com --ssh-key=~/.ssh/id_rsa

# Dry run (test without changes)
./scripts/deploy-dns.sh --host=vpn.bethanytim.com --dry-run
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
- Monitor at: `http://vpn.bethanytim.com:3000` (use your domain)

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

When you provide a domain using `--domain=vpn.bethanytim.com`, the script automatically:
- Installs Caddy reverse proxy
- Configures automatic HTTPS with Let's Encrypt
- Sets up security headers
- Enables HTTP/2

**Prerequisites:**
- Own a domain name
- DNS A record pointing to your VPS
- Ports 80 and 443 open

## 📚 Additional Documentation

- **[ADMIN_GUIDE.md](ADMIN_GUIDE.md)** - Complete admin reference (user management, ACLs, backups, troubleshooting)
- **[SPLIT_TUNNELING.md](SPLIT_TUNNELING.md)** - Split tunneling and ACL guide
- **[QUICKSTART.md](QUICKSTART.md)** - Step-by-step setup guide
- **[GITOPS_DNS.md](GITOPS_DNS.md)** - GitOps DNS filter management guide (recommended)
- **Headscale docs:** https://headscale.net/
- **Tailscale docs:** https://tailscale.com/kb/

---

## 📁 Repository Files

```
├── provision_vps.sh          # Main setup script (run this)
├── setup_exit_node.sh        # Post-install exit node helper
├── test_setup.sh             # Remote VPS verification
├── ADMIN_GUIDE.md            # Complete admin reference
├── SPLIT_TUNNELING.md        # Split tunneling & ACL guide
├── QUICKSTART.md             # Quick setup guide
├── GITOPS_DNS.md             # GitOps DNS filter management guide
├── .github/
│   └── workflows/
│       └── deploy-dns.yml    # GitHub Actions workflow for DNS deployment
├── scripts/
│   └── deploy-dns.sh         # DNS deployment script
└── config/
    ├── deploy.yml            # Kamal config (for updates)
    ├── headscale-config.yaml # Headscale configuration template
    ├── acl.yaml              # ACL policy template
    ├── dns-allowlist.txt     # DNS domains to never block (GitOps)
    └── dns-blocklist.txt     # Additional DNS domains to block (GitOps)
```

---

## License

MIT License - See LICENSE file for details
