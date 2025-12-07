# GitOps DNS Filter Management Guide

Manage your VPS DNS filters using Git and automated deployment.

## Overview

This GitOps workflow allows you to manage AdGuard Home DNS filters through simple text files in your GitHub repository. Changes are automatically validated and deployed to your VPS.

## Quick Start

### 1. Initial Setup

**Configure GitHub Secrets:**

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `VPS_HOST` | Your VPS domain or IP address | `vpn.bethanytim.com` |
| `VPS_SSH_KEY` | SSH private key for deploy user | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `VPS_SSH_PORT` | SSH port (optional, default: 33003) | `33003` |
| `VPS_SSH_USER` | SSH username (optional, default: deploy) | `deploy` |

**To get your SSH private key:**
```bash
# On your local machine (the one you use to SSH to VPS)
cat ~/.ssh/id_rsa
# or
cat ~/.ssh/id_ed25519
```

Copy the entire output including the `-----BEGIN` and `-----END` lines.

### 2. Edit DNS Filters

**Allowlist** (`config/dns-allowlist.txt`):
- Domains that should NEVER be blocked
- Useful for false positives
- One domain per line

**Blocklist** (`config/dns-blocklist.txt`):
- Additional domains to block
- Supplements the default blocklists
- One domain per line

**Example edits:**

```txt
# config/dns-allowlist.txt
youtube.com
facebook.com
instagram.com
```

```txt
# config/dns-blocklist.txt
gambling-site.com
time-wasting-game.com
distracting-social-media.com
```

### 3. Deploy Changes

**Method 1: GitHub Web UI (Easiest)**

1. Go to your repository on GitHub
2. Navigate to `config/dns-allowlist.txt` or `config/dns-blocklist.txt`
3. Click the pencil icon (Edit)
4. Make your changes
5. Scroll down and click **Commit changes**
6. GitHub Actions automatically deploys to your VPS!

**Method 2: Git Command Line**

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/headscale_vps.git
cd headscale_vps

# Edit files
nano config/dns-allowlist.txt
nano config/dns-blocklist.txt

# Commit and push
git add config/dns-*.txt
git commit -m "Update DNS filters"
git push

# GitHub Actions automatically deploys!
```

### 4. Monitor Deployment

1. Go to **Actions** tab in your repository
2. Click on the latest workflow run
3. Watch the deployment progress
4. Green checkmark = successful deployment
5. Red X = deployment failed (check logs)

## Features

### Automatic Validation

Before deployment, the workflow validates:
- ✅ File format is correct
- ✅ Domain names are valid
- ✅ No syntax errors
- ✅ SSH connection works
- ✅ AdGuard Home configuration is valid

### Safe Deployment

The deployment process:
1. Creates a backup of current configuration
2. Updates the configuration
3. Validates the new configuration
4. Reloads AdGuard Home
5. **Rolls back automatically if anything fails**

### Change Tracking

Every change is tracked in Git:
- See who changed what and when
- Compare versions with `git diff`
- Revert changes easily
- Full audit trail

## Advanced Usage

### Manual Deployment (Local Testing)

Test changes before pushing to GitHub:

```bash
# Dry run (shows what would be deployed)
./scripts/deploy-dns.sh --host=vpn.bethanytim.com --ssh-key=~/.ssh/id_rsa --dry-run

# Actual deployment
./scripts/deploy-dns.sh --host=vpn.bethanytim.com --ssh-key=~/.ssh/id_rsa
```

### Manual Workflow Trigger

Deploy without changing files:

1. Go to **Actions** tab
2. Click **Deploy DNS Filters**
3. Click **Run workflow**
4. Choose options:
   - **dry_run**: Test without making changes
5. Click **Run workflow**

### Rollback to Previous Version

**Method 1: Git Revert**

```bash
# View commit history
git log --oneline config/dns-*.txt

# Revert to a previous commit
git revert COMMIT_HASH

# Push (triggers automatic redeployment)
git push
```

**Method 2: Manual SSH Rollback**

```bash
ssh deploy@vpn.bethanytim.com -p 33003

# List backups
ls -lh /opt/adguardhome/conf/AdGuardHome.yaml.backup.*

# Restore a backup
sudo cp /opt/adguardhome/conf/AdGuardHome.yaml.backup.20231207_120000 \
        /opt/adguardhome/conf/AdGuardHome.yaml

# Restart service
sudo systemctl restart adguardhome
```

## File Format

### Comment Syntax

```txt
# Full line comment - ignored

domain.com  # Inline comment - also ignored
```

### Domain Format

```txt
# Good - simple domain
example.com

# Good - subdomain
subdomain.example.com

# Good - complex domain
my-site.co.uk

# Bad - includes protocol
https://example.com  ❌

# Bad - includes path
example.com/path  ❌

# Bad - includes port
example.com:8080  ❌
```

### Empty Lines

Empty lines are ignored - use them for organization:

```txt
# Social media
facebook.com
instagram.com
twitter.com

# Streaming
youtube.com
netflix.com

# Shopping
amazon.com
```

## Troubleshooting

### Deployment Fails - SSH Connection Error

**Problem:** Can't connect to VPS

**Solutions:**
1. Check `VPS_HOST` secret is correct
2. Verify `VPS_SSH_KEY` secret contains the full private key
3. Ensure `VPS_SSH_PORT` is correct (default: 33003)
4. Test SSH manually:
   ```bash
   ssh deploy@vpn.bethanytim.com -p 33003
   ```

### Deployment Fails - Invalid Domain Format

**Problem:** Validation fails with "invalid domain format"

**Solutions:**
1. Check for invalid characters
2. Remove protocols (http://, https://)
3. Remove paths (/page)
4. Remove ports (:8080)
5. Ensure one domain per line

### Changes Not Taking Effect

**Problem:** Deployed successfully but domains still blocked/allowed

**Solutions:**
1. Wait 2-3 minutes for DNS cache to clear
2. Check AdGuard Home logs:
   ```bash
   ssh deploy@vpn.bethanytim.com -p 33003
   sudo journalctl -u adguardhome -f
   ```
3. Verify rules were applied:
   ```bash
   ssh deploy@vpn.bethanytim.com -p 33003
   sudo grep -A 20 "user_rules:" /opt/adguardhome/conf/AdGuardHome.yaml
   ```
4. Restart AdGuard Home:
   ```bash
   sudo systemctl restart adguardhome
   ```

### Workflow Not Triggering

**Problem:** Changes pushed but workflow doesn't run

**Solutions:**
1. Ensure changes are in `config/dns-allowlist.txt` or `config/dns-blocklist.txt`
2. Ensure changes are pushed to `main` branch
3. Check GitHub Actions are enabled (Settings → Actions)
4. Manually trigger workflow (Actions → Deploy DNS Filters → Run workflow)

### Service Won't Start After Deployment

**Problem:** AdGuard Home fails to start

**Solutions:**
1. Workflow automatically rolls back on failure
2. Check if rollback succeeded in workflow logs
3. Manual rollback:
   ```bash
   ssh deploy@vpn.bethanytim.com -p 33003
   ls -lh /opt/adguardhome/conf/AdGuardHome.yaml.backup.*
   sudo cp /opt/adguardhome/conf/AdGuardHome.yaml.backup.LATEST \
           /opt/adguardhome/conf/AdGuardHome.yaml
   sudo systemctl restart adguardhome
   ```

## Best Practices

### 1. Test Before Deploying to Main

Use dry-run mode to test:

```bash
# Test locally
./scripts/deploy-dns.sh --host=vpn.bethanytim.com --dry-run

# Or use workflow manual trigger with dry_run option
```

### 2. Use Descriptive Commit Messages

Good:
```
Add facebook.com to allowlist for family member
Block distracting-game.com for kids
```

Bad:
```
update
changes
fix
```

### 3. Document Why You Made Changes

```txt
# In dns-allowlist.txt

# Added for work - needed for video conferencing
zoom.us

# Added because kid's homework site was blocked
educational-site.com
```

### 4. Group Related Domains

```txt
# Google services
google.com
googleapis.com
googleusercontent.com

# Microsoft services
microsoft.com
office.com
outlook.com
```

### 5. Review Changes Before Committing

```bash
# See what changed
git diff config/dns-allowlist.txt
git diff config/dns-blocklist.txt

# Review thoroughly before pushing
```

### 6. Keep Backups of Important Changes

```bash
# Download current config before major changes
scp -P 33003 deploy@vpn.bethanytim.com:/opt/adguardhome/conf/AdGuardHome.yaml \
    ~/backups/adguard-$(date +%Y%m%d).yaml
```

## Security Considerations

### SSH Key Security

- ✅ **DO** use a dedicated SSH key for deployment
- ✅ **DO** restrict key to deploy user only
- ✅ **DO** use GitHub's encrypted secrets
- ❌ **DON'T** commit SSH keys to repository
- ❌ **DON'T** share SSH keys publicly

### Domain Validation

The workflow validates domains before deployment to prevent:
- Typos that could break DNS
- Injection attacks
- Invalid configurations

### Automatic Rollback

Failed deployments automatically rollback to prevent:
- DNS service downtime
- Broken configurations
- Service failures

## Integration with Existing Setup

### Works With

- ✅ AdGuard Home default blocklists
- ✅ AdGuard Home web UI (both can be used)
- ✅ Manual SSH configuration
- ✅ Existing user_rules

### Priority Order

1. **GitOps managed rules** (from this workflow)
2. AdGuard Home web UI custom rules
3. Default blocklists

**Note:** GitOps rules take precedence. If you manually add rules via web UI, they may be overwritten on next GitOps deployment.

## Support

### Getting Help

1. Check the [main README](README.md)
2. Check [ADMIN_GUIDE](ADMIN_GUIDE.md)
3. Review workflow logs in GitHub Actions
4. Check AdGuard Home logs via SSH

### Common Resources

- **AdGuard Home documentation:** https://github.com/AdguardTeam/AdGuardHome/wiki
- **GitHub Actions documentation:** https://docs.github.com/en/actions
- **Headscale documentation:** https://headscale.net/

## Examples

### Example 1: Allow Social Media for Adults

```txt
# config/dns-allowlist.txt
# Social media - allowed for parents only
facebook.com
instagram.com
twitter.com
linkedin.com
```

### Example 2: Block Gaming Sites for Kids

```txt
# config/dns-blocklist.txt
# Gaming - blocked during school hours
roblox.com
minecraft.net
epicgames.com
```

### Example 3: Allow Work Tools

```txt
# config/dns-allowlist.txt
# Work collaboration tools
slack.com
zoom.us
teams.microsoft.com
notion.so
```

### Example 4: Block Distracting Sites

```txt
# config/dns-blocklist.txt
# Time-wasting sites
reddit.com
9gag.com
buzzfeed.com
```

## Migration from Manual Configuration

If you were previously managing DNS filters via SSH:

1. **Export current rules:**
   ```bash
   ssh deploy@vpn.bethanytim.com -p 33003
   sudo grep -A 100 "user_rules:" /opt/adguardhome/conf/AdGuardHome.yaml
   ```

2. **Convert to text files:**
   - Lines starting with `@@||` and ending with `^$important` → allowlist
   - Lines starting with `||` and ending with `^` → blocklist
   - Extract domain name between `||` and `^`

3. **Add to repository:**
   ```bash
   # Add extracted domains to files
   nano config/dns-allowlist.txt
   nano config/dns-blocklist.txt
   
   # Commit and push
   git add config/dns-*.txt
   git commit -m "Migrate from manual configuration"
   git push
   ```

4. **Verify deployment:**
   - Check Actions tab for successful deployment
   - Test that domains are still blocked/allowed as expected

---

**Happy DNS filtering! 🛡️**
