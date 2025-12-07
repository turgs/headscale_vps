# GitHub Actions Setup Guide

This guide explains how to set up GitHub Actions for automated deployment to your VPS.

## Overview

The repository uses GitHub Actions to automatically deploy DNS filter changes to your VPS when you commit changes to:
- `config/dns-allowlist.txt`
- `config/dns-blocklist.txt`

## Required GitHub Secrets

To enable automated deployments, you need to configure the following secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

### 1. VPS_HOST
**Description:** The hostname or domain of your VPS  
**Value:** `robin-easy.bnr.la` (or `103.100.37.13` if using IP)  
**Usage:** Specifies where to deploy the DNS filters

### 2. VPS_SSH_KEY
**Description:** The private SSH key for authenticating to your VPS  
**Value:** The **entire contents** of your private SSH key file (e.g., `~/.ssh/id_ed25519`)  
**Format:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
...
(full key content)
...
-----END OPENSSH PRIVATE KEY-----
```
**Usage:** Used by the deploy workflow to SSH into the VPS as the `deploy` user

**⚠️ Important:** 
- This should be the **private key** (not the public key)
- The corresponding **public key** must be in `/home/deploy/.ssh/authorized_keys` on the VPS
- The provision script automatically adds your public key during initial setup

### 3. VPS_SSH_PORT (Optional)
**Description:** The SSH port for your VPS  
**Value:** `33003`  
**Default:** `33003` (if not set)  
**Usage:** Custom SSH port configured by the provision script for security

### 4. VPS_SSH_USER (Optional)
**Description:** The SSH user for deployments  
**Value:** `deploy`  
**Default:** `deploy` (if not set)  
**Usage:** The non-root user created by the provision script

### 5. VPS_ROOT_PASSWORD (For Initial Provisioning Only)
**Description:** The root password provided by Binary Lane  
**Value:** The password from Binary Lane's VPS details page  
**Usage:** Used only for initial SSH access before the provision script runs  
**Note:** After provisioning, all access uses SSH keys with the `deploy` user

## Initial VPS Provisioning Workflow

Here's how to automate the initial VPS setup:

### Step 1: Generate SSH Key Pair
```bash
# On your local machine
ssh-keygen -t ed25519 -C "headscale-vps-deploy" -f ~/.ssh/headscale_vps_deploy
```

This creates:
- Private key: `~/.ssh/headscale_vps_deploy`
- Public key: `~/.ssh/headscale_vps_deploy.pub`

### Step 2: Add SSH Keys to GitHub Secrets

1. Add the **private key** as `VPS_SSH_KEY`:
```bash
cat ~/.ssh/headscale_vps_deploy
# Copy the entire output and add as VPS_SSH_KEY secret
```

2. Get the **public key** for provisioning:
```bash
cat ~/.ssh/headscale_vps_deploy.pub
# You'll use this in the provision command
```

### Step 3: Run Provision Script

From your local machine, provision the VPS:

```bash
# Using the domain (recommended)
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/headscale_vps_deploy.pub)" \
  --domain="robin-easy.bnr.la"

# Or using IP only
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh) \
  --ssh-key="$(cat ~/.ssh/headscale_vps_deploy.pub)"
```

**What this does:**
1. Creates the `deploy` user with UID 1000
2. Adds your public key to `/home/deploy/.ssh/authorized_keys`
3. Configures SSH on port 33003
4. Installs and configures Headscale, AdGuard Home, and other services
5. Reboots the VPS

### Step 4: Verify SSH Access

After the VPS reboots (2-3 minutes):

```bash
ssh -i ~/.ssh/headscale_vps_deploy deploy@robin-easy.bnr.la -p 33003

# Or with IP
ssh -i ~/.ssh/headscale_vps_deploy deploy@103.100.37.13 -p 33003
```

If this works, your GitHub Actions deployments will also work!

## Automated Deployments

Once secrets are configured, deployments happen automatically:

1. **Edit DNS filters** on GitHub:
   - Go to `config/dns-allowlist.txt` or `config/dns-blocklist.txt`
   - Click "Edit" (pencil icon)
   - Make your changes
   - Commit directly to `main` branch

2. **GitHub Actions automatically**:
   - Detects the file changes
   - Connects to your VPS via SSH
   - Updates AdGuard Home configuration
   - Restarts AdGuard Home service
   - Verifies the service is running

3. **View deployment status**:
   - Go to "Actions" tab in GitHub
   - Click on the latest "Deploy DNS Filters" workflow run
   - See the deployment logs and status

## Manual Deployment (Alternative)

If you prefer to deploy manually:

```bash
# From your local machine with the repo cloned
cd headscale_vps

./scripts/deploy-dns.sh \
  --host=robin-easy.bnr.la \
  --ssh-key=~/.ssh/headscale_vps_deploy \
  --ssh-port=33003 \
  --ssh-user=deploy
```

## Troubleshooting

### Deployment Fails with "Permission denied"

**Problem:** GitHub Actions can't SSH into the VPS

**Solutions:**
1. Verify `VPS_SSH_KEY` secret contains the **private key** (not public)
2. Verify the public key is in `/home/deploy/.ssh/authorized_keys` on VPS:
   ```bash
   ssh root@103.100.37.13  # Use root with password
   cat /home/deploy/.ssh/authorized_keys
   ```
3. Check SSH key permissions on VPS:
   ```bash
   sudo chmod 700 /home/deploy/.ssh
   sudo chmod 600 /home/deploy/.ssh/authorized_keys
   sudo chown -R deploy:deploy /home/deploy/.ssh
   ```

### Deployment Fails with "Connection refused"

**Problem:** Wrong host, port, or firewall blocking connection

**Solutions:**
1. Verify `VPS_HOST` secret is correct (robin-easy.bnr.la or 103.100.37.13)
2. Verify `VPS_SSH_PORT` is 33003
3. Check VPS firewall allows port 33003:
   ```bash
   ssh root@103.100.37.13
   sudo ufw status
   # Should show: 33003/tcp ALLOW Anywhere
   ```

### How to Rotate SSH Keys

If you need to change the SSH key:

1. Generate new key pair:
   ```bash
   ssh-keygen -t ed25519 -C "headscale-vps-deploy-new" -f ~/.ssh/headscale_vps_deploy_new
   ```

2. Add new public key to VPS:
   ```bash
   ssh -p 33003 deploy@robin-easy.bnr.la
   echo "YOUR_NEW_PUBLIC_KEY" >> ~/.ssh/authorized_keys
   ```

3. Update `VPS_SSH_KEY` secret in GitHub with new private key

4. Test deployment

5. Remove old key from VPS if desired

## Security Notes

- **Never commit private keys** to the repository
- **Never share private keys** in issues or pull requests
- **Use SSH keys only** - password authentication is disabled for the `deploy` user
- **Limit VPS_SSH_KEY access** - only repository admins should access secrets
- **Rotate keys periodically** - change SSH keys every 6-12 months
- **Monitor Actions logs** - review deployment logs for unusual activity

## VPS Configuration Reference

Current VPS details (see `config/vps-config.txt`):
- **Provider:** Binary Lane
- **Domain:** robin-easy.bnr.la (provided by Binary Lane)
- **IP:** 103.100.37.13
- **SSH Port:** 33003
- **Deploy User:** deploy
- **Root User:** root (password from Binary Lane)

## Workflow File Reference

The deployment workflow is defined in `.github/workflows/deploy-dns.yml`

**Trigger:** Push to `main` branch with changes to DNS filter files  
**Runner:** ubuntu-latest  
**Permissions:** Read repository contents only  
**Steps:**
1. Checkout repository
2. Setup SSH key from secret
3. Run `scripts/deploy-dns.sh` with configuration

You can manually trigger the workflow from the Actions tab using the "Run workflow" button.
