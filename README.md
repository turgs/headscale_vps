# headscale_vps

**HostHatch VPS Provisioning for Headscale Exit Node**

Automated setup script to provision a HostHatch (or any) Ubuntu VPS as a Headscale coordination server and exit node, enabling you to create your own self-hosted VPN mesh network with exit node capabilities.

---

## 🚀 Quick Start

### One-Liner Deployment

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

### Or with explicit SSH key

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)"
```

### Or with custom domain

```bash
ssh root@YOUR_SERVER_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="headscale.yourdomain.com"
```

That's it! Your server will be fully configured with Headscale and reboot automatically.

---

## 📋 What Gets Configured

### Security
- ✅ **SSH Hardening**
  - Custom port 33003 (configurable)
  - Root: Password auth enabled (emergency access)
  - Deploy user: Keys-only authentication
  - Connection keep-alive configured

- ✅ **fail2ban Protection**
  - 24-hour bans (progressive for repeat offenders)
  - 5 retry attempts allowed
  - Dynamic IP whitelist via GitHub Gist
  - Auto-updates hourly

- ✅ **UFW Firewall**
  - Ports 33003 (SSH), 80 (HTTP), 443 (HTTPS), 8080 (Headscale)
  - Default deny incoming
  - Default allow outgoing

- ✅ **Automatic Security Updates**
  - Unattended upgrades enabled
  - Auto-reboot disabled by default

### Headscale
- ✅ **Headscale Server**
  - Latest version installed
  - Configured with sensible defaults
  - systemd service enabled
  - SQLite database for coordination

- ✅ **Exit Node Setup**
  - IP forwarding enabled (IPv4 & IPv6)
  - NAT masquerading configured
  - Tailscale client installed as exit node
  - Ready to route all traffic

### System
- ✅ **Deploy User**
  - Created with docker group access
  - SSH key-based authentication
  - Sudo access (password protected)

- ✅ **Docker & Docker Compose**
  - Latest version installed
  - Deploy user can run docker without sudo
  - Log rotation configured

- ✅ **Swap**
  - 2GB by default (configurable)
  - Optimized for containers (swappiness=10)

- ✅ **System Tuning**
  - Timezone set to UTC
  - File watches increased
  - sysctl optimized for networking

---

## 📖 Usage

### Method 1: Zero Config

```bash
ssh root@YOUR_SERVER_IP
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh > provision_vps.sh
bash provision_vps.sh
```

### Method 2: Custom Configuration

```bash
bash provision_vps.sh \
  --ssh-key="ssh-ed25519 AAAA..." \
  --ssh-port=33003 \
  --domain="headscale.yourdomain.com" \
  --swap-size=4G
```

### Available Options

```
Required:
  None - All parameters are optional!

Optional:
  --ssh-key=KEY              SSH public key for deploy user
  --ssh-port=PORT           SSH port (default: 33003)
  --domain=DOMAIN           Your domain for Headscale (e.g., headscale.example.com)
  --deploy-user=USER        Deploy username (default: deploy)
  --swap-size=SIZE          Swap size, e.g., 2G, 4G (default: 2G)
  --fail2ban-whitelist-url=URL  Gist URL for IP whitelist
  --no-fail2ban             Disable fail2ban installation
  --no-reboot               Skip automatic reboot after provisioning
  --help, -h                Show help message
```

---

## 🔧 Post-Installation

### 1. Create Headscale User

```bash
ssh deploy@YOUR_SERVER_IP -p 33003
sudo headscale users create myuser
```

### 2. Generate Pre-Auth Key

```bash
sudo headscale preauthkeys create --user myuser --reusable --expiration 24h
```

### 3. Connect the VPS as Exit Node

The VPS is already configured as an exit node. Verify:

```bash
sudo tailscale status
```

### 4. Connect Client Devices

#### Linux/macOS:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to your Headscale server
sudo tailscale up --login-server http://YOUR_SERVER_IP:8080 --authkey YOUR_PREAUTH_KEY
```

#### Windows (Detailed Guide for Non-Technical Users):

**Step 1: Download and Install Tailscale**

1. Visit https://tailscale.com/download/windows
2. Click "Download Tailscale for Windows"
3. Run the downloaded installer (`tailscale-setup-*.exe`)
4. Follow the installation wizard (click "Next" → "Install" → "Finish")
5. Tailscale will start automatically after installation

**Step 2: Connect to Your Headscale Server**

1. Look for the Tailscale icon in your system tray (near the clock)
   - It looks like a small network diagram icon
2. Right-click the Tailscale icon
3. Select "Settings" or "Preferences"
4. Look for "Login Server" or "Custom Control Server"
5. Enter your server address: `http://YOUR_SERVER_IP:8080`
   - Replace `YOUR_SERVER_IP` with your actual VPS IP address
   - Example: `http://192.168.1.100:8080`
6. Click "Save" or "Apply"
7. Click "Connect" or "Log in"
8. A browser window will open - follow the authorization steps

**Step 3: Enable Exit Node**

1. Right-click the Tailscale icon in system tray
2. Select "Exit Node" → Choose your VPS hostname
   - It will show your VPS name (e.g., "headscale-vps" or similar)
3. Click to enable it
4. You should see a green checkmark or "Connected via exit node" message

**Step 4: Verify Connection**

1. Open your web browser
2. Visit https://whatismyipaddress.com
3. You should see your VPS's IP address (not your home IP)
4. This confirms your traffic is routing through your VPS!

**Troubleshooting Windows Connection:**
- If Tailscale won't connect: Restart the Tailscale service (right-click icon → "Quit" → Open Tailscale again)
- If you don't see exit node option: Wait 1-2 minutes for nodes to sync, then check again
- If IP doesn't change: Make sure "Use exit node" is checked and enabled

#### Android:

1. Install "Tailscale" from Google Play Store
2. Open the app and tap "Get Started"
3. Tap the three dots menu (⋮) → "Settings"
4. Tap "Use alternate server"
5. Enter: `http://YOUR_SERVER_IP:8080`
6. Tap "Connect"
7. After connecting, tap the three dots again → "Exit node"
8. Select your VPS from the list

#### iOS:

1. Install "Tailscale" from App Store
2. Open the app and tap "Get Started"
3. Tap Settings (gear icon)
4. Tap "Login Server"
5. Enter: `http://YOUR_SERVER_IP:8080`
6. Tap "Connect"
7. After connecting, go to Settings → "Exit Node"
8. Select your VPS from the list

### 5. Use the Exit Node

On Linux/macOS command line:

```bash
# See available exit nodes
tailscale exit-node list

# Use your VPS as exit node
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME
```

On Windows/Mobile: Use the GUI as described above.

---

## 🌐 Built-in DNS Filtering (AdGuard Home)

### Automatic DNS-Based Content Filtering

The provisioning script **automatically installs AdGuard Home** on your VPS, providing:

✅ **Ad blocking** - Blocks ads and tracking across all devices
✅ **Porn blocking** - Blocks adult/inappropriate content  
✅ **Malware protection** - Blocks known malicious domains
✅ **Custom allow/deny lists** - Full control over what gets blocked
✅ **YouTube safe mode OFF** - YouTube works normally (not restricted)
✅ **MagicDNS** - Access devices by name (e.g., `ssh laptop`)

**No configuration needed** - DNS filtering is enabled by default for all devices using your VPN!

### How It Works

1. **AdGuard Home runs on your VPS** at `127.0.0.1:53`
2. **Headscale routes all DNS queries** through AdGuard Home
3. **AdGuard Home filters** using curated blocklists:
   - AdGuard DNS filter (ads & trackers)
   - AdAway Default Blocklist (ads)
   - OISD Big List (comprehensive blocking)
   - Block List Project (porn, tracking, malware)
4. **YouTube is whitelisted** to avoid restricted mode

### Managing DNS Filtering

#### View Web Interface

Access AdGuard Home's web UI to view statistics and manage settings:

```
http://YOUR_SERVER_IP:3000
Username: admin
Password: changeme
```

**⚠️ IMPORTANT:** Change the default password immediately after first login!

#### Allow/Deny Specific Domains

Use the management script on your VPS:

```bash
# SSH into your VPS
ssh deploy@YOUR_SERVER_IP -p 33003

# Allow a domain (bypass all blocking)
sudo bash manage_dns_filtering.sh allow example.com

# Block a specific domain
sudo bash manage_dns_filtering.sh deny badsite.com

# List all custom rules
sudo bash manage_dns_filtering.sh list

# Reload configuration
sudo bash manage_dns_filtering.sh reload
```

#### Examples

```bash
# Allow a legitimate site that's being blocked
sudo bash manage_dns_filtering.sh allow paypal.com

# Block a specific social media site
sudo bash manage_dns_filtering.sh deny tiktok.com

# Allow all Microsoft domains
sudo bash manage_dns_filtering.sh allow microsoft.com
sudo bash manage_dns_filtering.sh allow live.com
```

### What Gets Blocked by Default

- ✅ Ads on websites and in apps
- ✅ Tracking scripts and analytics
- ✅ Adult/porn websites
- ✅ Known malware domains
- ✅ Phishing sites
- ❌ YouTube (explicitly allowed)
- ❌ Legitimate websites
- ❌ Social media (unless you specifically block it)

### Testing DNS Filtering

After connecting to your VPN:

```bash
# Test if ads are blocked
# Visit: http://ads-blocker.com/testing/

# Check your DNS server
# Visit: https://www.dnsleaktest.com/
# Should show your VPS IP

# Try visiting a known ad/tracking domain (should be blocked)
ping doubleclick.net
```

---

## ⚠️ Important Information for Daily VPN Use

### What This Setup Provides

✅ **Bypasses government censorship** - Your ISP sees only encrypted traffic to your VPS
✅ **Bypasses ISP filtering** - DNS and traffic routing through your VPS
✅ **Hides browsing from ISP** - ISP cannot see which websites you visit
✅ **Encrypted connection** - WireGuard protocol (same as commercial VPNs)
✅ **Static exit IP** - Your VPS's IP address for all internet traffic
✅ **Built-in ad/tracking/porn blocking** - AdGuard Home runs on your VPS
✅ **Custom allow/deny lists** - Full control over DNS filtering

### What Users Should Know

**Speed Considerations:**
- Internet speed limited by your VPS's connection speed
- HostHatch typically provides 1 Gbps connections
- Latency depends on VPS location (ping time will increase)

**Data Usage:**
- All internet traffic routes through your VPS
- Check your VPS plan for bandwidth limits
- HostHatch typically provides generous/unlimited bandwidth

**Connection Stability:**
- If VPS goes down, internet access will fail (while exit node is enabled)
- Can quickly disable exit node to use direct connection
- VPS should have 99%+ uptime with good hosting provider

**Privacy Notes:**
- Your VPS provider can see your traffic (choose trusted provider)
- Better privacy than using ISP directly
- Not anonymous (VPS IP can be traced to you if you're targeted)
- For maximum privacy, consider additional layers (Tor, etc.)

**Legal Considerations:**
- Check local laws regarding VPN use
- This is YOUR infrastructure (not a commercial VPN service)
- You are responsible for how it's used
- Some countries restrict or ban VPN usage

**Family Safety:**
- **Built-in ad/porn blocking** enabled by default via AdGuard Home
- Test that inappropriate content is blocked: try visiting known adult sites (should be blocked)
- Use `manage_dns_filtering.sh` to allow educational sites if they're blocked
- Exit node can be disabled by users if they have device access
- Monitor AdGuard Home logs at `http://YOUR_SERVER_IP:3000` to see what's being blocked
- Consider device management software for young children for additional controls

### Quick Disable/Enable (for emergencies)

**Windows:**
- Right-click Tailscale icon → Uncheck "Use exit node"

**Mobile:**
- Open Tailscale app → Tap exit node → "None"

**Linux/Mac:**
```bash
tailscale set --exit-node=
```

### Monitoring and Maintenance

**Check VPS health weekly:**
```bash
ssh deploy@YOUR_SERVER_IP -p 33003
sudo systemctl status headscale
sudo systemctl status tailscaled
sudo systemctl status adguardhome
df -h  # Check disk space
free -h  # Check memory
```

**Update Headscale (when new versions release):**
```bash
sudo systemctl stop headscale
# Download and install new version (see provision_vps.sh for process)
sudo systemctl start headscale
```

---

## 🧪 Testing

After provisioning, test the setup:

```bash
# Run the test script
bash test_setup.sh YOUR_SERVER_IP
```

Or manually test:

```bash
# SSH into the server
ssh deploy@YOUR_SERVER_IP -p 33003

# Check Headscale status
sudo systemctl status headscale

# Check Tailscale status
sudo tailscale status

# Verify IP forwarding
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding

# Test firewall
sudo ufw status
```

---

## 🐳 Docker Deployment (Alternative)

If you prefer Docker deployment:

```bash
# Clone this repo
git clone https://github.com/turgs/headscale_vps.git
cd headscale_vps

# Edit docker-compose.yml if needed
nano docker-compose.yml

# Deploy with Docker Compose
docker compose up -d

# Or with Kamal (if configured)
kamal setup
kamal deploy
```

---

## 📁 Repository Structure

```
.
├── README.md                 # This file
├── provision_vps.sh          # Main provisioning script
├── docker-compose.yml        # Docker Compose configuration
├── config/
│   ├── deploy.yml           # Kamal deployment config
│   └── headscale-config.yaml # Headscale configuration template
└── test_setup.sh            # Testing script
```

---

## 🔒 Security Notes

- **SSH Port**: Changed to 33003 to reduce automated attacks
- **fail2ban**: Enabled by default with 24-hour bans
- **Firewall**: Only necessary ports are opened (UFW)
- **Root Access**: Maintained for emergency access with password
- **Deploy User**: Primary user with key-only authentication

### Important Security Considerations

1. **External URLs**: If using `--fail2ban-whitelist-url`, ensure it points to a **trusted source you control**. The script fetches SSH keys and IP whitelists from this URL.

2. **Package Verification**: The script attempts to verify Headscale package checksums when available. Review the script before running on production systems.

3. **GPG Keys**: Docker and Tailscale GPG keys are fetched from official sources. For maximum security, verify fingerprints manually:
   - Docker: `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88`
   - Tailscale: Official Tailscale package repository

4. **Review Before Running**: Always review provisioning scripts before running them with root privileges:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh | less
   ```

5. **Minimal Permissions**: The script follows the principle of least privilege where possible

---

## 🆘 Troubleshooting

### Can't connect after reboot

Wait 2-3 minutes for the server to fully restart, then:

```bash
ssh deploy@YOUR_SERVER_IP -p 33003
```

### Headscale not responding

```bash
sudo systemctl restart headscale
sudo journalctl -u headscale -f
```

### Exit node not working

```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -v

# Restart Tailscale
sudo systemctl restart tailscaled
```

### fail2ban blocking legitimate IPs

Add your IP to the whitelist:

```bash
sudo fail2ban-client set sshd unbanip YOUR_IP
```

---

## 📚 References

- [Headscale Documentation](https://headscale.net/)
- [Tailscale Exit Nodes](https://tailscale.com/kb/1103/exit-nodes)
- [Kamal Documentation](https://kamal-deploy.org/)

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

---

## ⚠️ Disclaimer

This script modifies system security settings. Review the code before running on production systems.