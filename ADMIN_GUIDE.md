# Admin Guide for Headscale VPS

Quick reference for managing your Headscale VPS with HTTPS and ACL support.

## Initial Setup

### With Domain (HTTPS - Recommended)

```bash
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --domain="robin-easy.bnr.la"
```

**For Binary Lane VPS:**
1. Domain `robin-easy.bnr.la` is provided automatically - no DNS setup needed!
2. DNS already points to 103.100.37.13
3. Ports 80, 443 are accessible by default for Let's Encrypt

### Without Domain (HTTP)

```bash
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

Uses HTTP on port 8080.

---

## User Management

### Create Users

```bash
ssh deploy@robin-easy.bnr.la -p 33003

# Create users for each family member
sudo headscale users create mom
sudo headscale users create dad
sudo headscale users create child1
sudo headscale users create child2
sudo headscale users create guest
```

### Generate Pre-Auth Keys

```bash
# For each user, generate a key (reusable, 30 days)
sudo headscale preauthkeys create --user mom --reusable --expiration 720h
sudo headscale preauthkeys create --user child1 --reusable --expiration 720h

# Copy these keys and give them to users to connect their devices
```

### List Users

```bash
sudo headscale users list
```

### Delete User

```bash
sudo headscale users destroy USERNAME
```

---

## Access Control (ACL) Management

### Edit ACL Policy

```bash
ssh deploy@robin-easy.bnr.la -p 33003
sudo nano /etc/headscale/acl.yaml
```

### Example ACL Modifications

#### Add User to Family Group

```yaml
groups:
  group:family:
    - mom
    - dad
    - newuser  # Add here
```

#### Create New Group

```yaml
groups:
  group:work:
    - mom
    - dad
```

#### Restrict Access Between Groups

```yaml
acls:
  # Kids can't access family devices
  - action: drop
    src:
      - group:kids
    dst:
      - group:family:*
```

### Apply ACL Changes

After editing `/etc/headscale/acl.yaml`:

```bash
sudo systemctl reload headscale
```

No restart required! Changes take effect immediately.

### Validate ACL

```bash
# Check Headscale logs for any ACL errors
sudo journalctl -u headscale -n 50
```

---

## Device Management

### List Connected Devices

```bash
sudo headscale nodes list
```

### Delete/Remove a Device

```bash
sudo headscale nodes delete --identifier NODE_ID
```

### Tag a Device (e.g., as exit node)

```bash
# First, enable in ACL tagOwners
# Then tag the device
sudo headscale nodes tag --identifier NODE_ID --tags tag:exit-node
```

---

## Exit Node Management

### List Routes

```bash
sudo headscale routes list
```

### Enable Exit Node Route

```bash
# Auto-approved if ACL configured correctly
# Manual approval if needed:
sudo headscale routes enable --route ROUTE_ID
```

### Disable Exit Node Route

```bash
sudo headscale routes disable --route ROUTE_ID
```

---

## HTTPS & Caddy Management

### Check Caddy Status

```bash
sudo systemctl status caddy
```

### View Caddy Logs

```bash
sudo journalctl -u caddy -f
```

### Edit Caddyfile

```bash
sudo nano /etc/caddy/Caddyfile
```

### Reload Caddy (after config changes)

```bash
sudo systemctl reload caddy
```

### View SSL Certificate Info

```bash
sudo caddy list-certificates
```

### Force SSL Certificate Renewal

```bash
sudo systemctl stop caddy
sudo caddy renew
sudo systemctl start caddy
```

---

## DNS & AdGuard Home Management

### Access AdGuard Home UI

```
http://robin-easy.bnr.la:3000  (or http://103.100.37.13:3000)
```

Login: `admin` / `changeme` (change immediately!)

### Managing DNS Filters

**Method 1: GitOps (Recommended)**

Edit `config/dns-allowlist.txt` or `config/dns-blocklist.txt` in GitHub → commit → auto-deploys.

**Method 2: AdGuard Web UI**

Visit `http://robin-easy.bnr.la:3000` → Filters → Custom filtering rules
- Allow: `@@||example.com^$important`
- Block: `||badsite.com^`

**Method 3: SSH**

```bash
ssh deploy@robin-easy.bnr.la -p 33003
sudo nano /opt/adguardhome/conf/AdGuardHome.yaml
# Edit user_rules section
sudo systemctl restart adguardhome
```

### View AdGuard Logs

```bash
sudo journalctl -u adguardhome -f
```

---

## Service Management

### Check All Services

```bash
sudo systemctl status headscale
sudo systemctl status caddy
sudo systemctl status adguardhome
sudo systemctl status tailscaled
```

### Restart Services

```bash
sudo systemctl restart headscale
sudo systemctl restart caddy
sudo systemctl restart adguardhome
```

### View Logs

```bash
# Headscale
sudo journalctl -u headscale -f

# Caddy
sudo journalctl -u caddy -f

# AdGuard Home
sudo journalctl -u adguardhome -f
```

---

## Backup & Restore

### Backup Important Files

```bash
# On VPS
ssh deploy@robin-easy.bnr.la -p 33003

# Create backup directory
mkdir -p ~/backups/$(date +%Y%m%d)

# Backup Headscale database and config
sudo cp /var/lib/headscale/db.sqlite ~/backups/$(date +%Y%m%d)/
sudo cp /etc/headscale/config.yaml ~/backups/$(date +%Y%m%d)/
sudo cp /etc/headscale/acl.yaml ~/backups/$(date +%Y%m%d)/

# Backup AdGuard Home config
sudo cp /opt/adguardhome/conf/AdGuardHome.yaml ~/backups/$(date +%Y%m%d)/

# Download to local machine
exit
scp -P 33003 -r deploy@robin-easy.bnr.la:~/backups/$(date +%Y%m%d) ./headscale-backup-$(date +%Y%m%d)
```

### Restore from Backup

```bash
# Upload backup to VPS
scp -P 33003 -r ./headscale-backup-20231206 deploy@robin-easy.bnr.la:~/restore/

# On VPS
ssh deploy@robin-easy.bnr.la -p 33003

# Stop services
sudo systemctl stop headscale
sudo systemctl stop adguardhome

# Restore files
sudo cp ~/restore/headscale-backup-20231206/db.sqlite /var/lib/headscale/
sudo cp ~/restore/headscale-backup-20231206/config.yaml /etc/headscale/
sudo cp ~/restore/headscale-backup-20231206/acl.yaml /etc/headscale/
sudo cp ~/restore/headscale-backup-20231206/AdGuardHome.yaml /opt/adguardhome/conf/

# Fix permissions
sudo chown headscale:headscale /var/lib/headscale/db.sqlite
sudo chown root:root /etc/headscale/*.yaml

# Start services
sudo systemctl start headscale
sudo systemctl start adguardhome
```

---

## Troubleshooting

### Headscale Not Starting

```bash
sudo journalctl -u headscale -n 100 --no-pager
sudo headscale nodes list  # Test CLI
```

### Caddy SSL Issues

```bash
# Check DNS is pointing to server
dig robin-easy.bnr.la

# Check ports are open
sudo ufw status
sudo netstat -tlnp | grep -E ':(80|443)'

# View detailed Caddy logs
sudo journalctl -u caddy -n 100 --no-pager
```

### Can't Connect to VPN

```bash
# On VPS - check Headscale is running
sudo systemctl status headscale

# Check firewall
sudo ufw status

# If using domain, check DNS
curl -I https://robin-easy.bnr.la

# Check routes
sudo headscale routes list
```

### Exit Node Not Working

```bash
# List and enable routes
sudo headscale routes list
sudo headscale routes enable --route ROUTE_ID

# Check IP forwarding
sysctl net.ipv4.ip_forward  # Should be 1

# Check iptables NAT
sudo iptables -t nat -L -n -v | grep MASQUERADE
```

### DNS Not Blocking Ads

```bash
# Check AdGuard Home is running
sudo systemctl status adguardhome

# Test DNS resolution
dig @127.0.0.1 google.com

# Check Headscale is using correct DNS
sudo cat /etc/headscale/config.yaml | grep -A 5 dns_config
```

---

## Updating Headscale

```bash
ssh deploy@robin-easy.bnr.la -p 33003

# Check current version
headscale version

# Download new version (example: 0.24.0)
wget https://github.com/juanfont/headscale/releases/download/v0.24.0/headscale_0.24.0_linux_amd64.deb

# Stop Headscale
sudo systemctl stop headscale

# Install update
sudo apt install ./headscale_0.24.0_linux_amd64.deb

# Start Headscale
sudo systemctl start headscale

# Verify
sudo systemctl status headscale
headscale version
```

---

## Security Best Practices

1. **Change default passwords immediately**
   - AdGuard Home admin password
   - Deploy user password (if not using SSH keys)

2. **Keep ACLs restrictive**
   - Kids should only access exit node, not family devices
   - Guests should have minimal access

3. **Regular backups**
   - Weekly backup of database and configs
   - Test restore procedure

4. **Monitor logs**
   - Check for unauthorized access attempts
   - Review fail2ban reports

5. **Update regularly**
   - Enable unattended-upgrades (done by provision script)
   - Manually update Headscale when new versions release

6. **Use HTTPS**
   - Always use domain with HTTPS in production
   - HTTP is acceptable for testing only

---

## Quick Reference Commands

```bash
# SSH into VPS
ssh deploy@robin-easy.bnr.la -p 33003

# Create user and get key
sudo headscale users create USERNAME
sudo headscale preauthkeys create --user USERNAME --reusable --expiration 720h

# Manage ACLs
sudo nano /etc/headscale/acl.yaml
sudo systemctl reload headscale

# List everything
sudo headscale users list
sudo headscale nodes list
sudo headscale routes list

# Check services
sudo systemctl status headscale caddy adguardhome

# View logs
sudo journalctl -u headscale -f
```

---

## Support & Documentation

- Full Documentation: [README.md](README.md)
- Quick Setup: [QUICKSTART.md](QUICKSTART.md)
- Split Tunneling: [SPLIT_TUNNELING.md](SPLIT_TUNNELING.md)
- Headscale Docs: https://headscale.net/
- Caddy Docs: https://caddyserver.com/docs/
- AdGuard Home: https://github.com/AdguardTeam/AdGuardHome/wiki
