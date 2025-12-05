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

On your client devices:

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to your Headscale server
sudo tailscale up --login-server http://YOUR_SERVER_IP:8080 --authkey YOUR_PREAUTH_KEY
```

### 5. Use the Exit Node

On client devices, route traffic through the VPS:

```bash
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME
```

Or use the Tailscale GUI to select your exit node.

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
- **Firewall**: Only necessary ports are opened
- **Root Access**: Maintained for emergency access with password
- **Deploy User**: Primary user with key-only authentication

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