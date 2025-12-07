# 1Password CLI Integration Guide

This guide explains how to use 1Password CLI to automatically authenticate with your VPS root password, eliminating manual password entry.

## Why Use 1Password CLI?

- **Security**: Store root password securely in 1Password vault
- **Convenience**: No more manual password typing
- **Automation**: Enable scripted workflows without exposing passwords
- **Auditability**: Track password access through 1Password logs

## Prerequisites

### 1. Install 1Password CLI

**macOS:**
```bash
brew install 1password-cli
```

**Linux (Debian/Ubuntu):**
```bash
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list

sudo apt update && sudo apt install 1password-cli
```

**Windows:**
```powershell
winget install 1Password.CLI
```

**Verify installation:**
```bash
op --version
```

### 2. Install sshpass

`sshpass` is required to pass passwords to SSH non-interactively.

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install sshpass
```

**macOS:**
```bash
# Option 1: Using Homebrew tap
brew install hudochenkov/sshpass/sshpass

# Option 2: If above fails, compile from source
# Download from: https://sourceforge.net/projects/sshpass/
```

**Windows:**
```powershell
# sshpass is not available on Windows
# Alternative: Use WSL2 (Windows Subsystem for Linux) or Git Bash with Linux tools
```

## Setup Steps

### Step 1: Sign In to 1Password CLI

```bash
# Sign in to your 1Password account
eval $(op signin)

# This will prompt for your 1Password credentials
# The session will be valid for 30 minutes by default
```

### Step 2: Create Secure Note in 1Password

You can do this via 1Password app or CLI:

**Option A: Using 1Password App (Recommended)**

1. Open 1Password app
2. Click "+" to create new item
3. Select "Secure Note"
4. Set title: `BinaryLane VPN Headscale Tailscale`
5. Add a new field:
   - Label: `root Password`
   - Type: Password or Concealed
   - Value: Your root password from Binary Lane
6. Save the item

**Option B: Using 1Password CLI**

```bash
# Create secure note with password field
op item create \
  --category="Secure Note" \
  --title="BinaryLane VPN Headscale Tailscale" \
  --vault="Private" \
  "root Password[password]=YOUR_ROOT_PASSWORD_HERE"
```

### Step 3: Verify Password Retrieval

Test that you can retrieve the password:

```bash
op item get "BinaryLane VPN Headscale Tailscale" --fields "root Password"
```

If this displays your password, you're ready to go!

## Usage

### Method 1: Using the Wrapper Script (Easiest)

The repository includes `provision_vps_1password.sh` which handles everything:

```bash
# Basic provisioning
./provision_vps_1password.sh

# With domain (recommended)
./provision_vps_1password.sh --domain="robin-easy.bnr.la"

# With SSH key and domain
./provision_vps_1password.sh \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="robin-easy.bnr.la"

# All provision_vps.sh options are supported
./provision_vps_1password.sh --swap-size=4G --no-reboot
```

### Method 2: Using Helper Functions

For custom workflows, source the helper script:

```bash
# Load 1Password helper functions
source scripts/1password-helper.sh

# SSH to VPS
ssh_with_1password root@103.100.37.13

# Run remote command
run_remote_with_1password root@103.100.37.13 "apt-get update"

# Provision VPS
provision_vps_with_1password root@103.100.37.13 --domain="robin-easy.bnr.la"
```

### Method 3: Manual Integration

For one-off commands:

```bash
# Get password from 1Password
ROOT_PASSWORD=$(op item get "BinaryLane VPN Headscale Tailscale" --fields "root Password")

# Use with sshpass
sshpass -p "$ROOT_PASSWORD" ssh root@103.100.37.13
```

## Examples

### Example 1: Initial VPS Provisioning

```bash
# Sign in to 1Password (if not already signed in)
eval $(op signin)

# Run provisioning with 1Password
./provision_vps_1password.sh \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="robin-easy.bnr.la"
```

### Example 2: Quick SSH Access

```bash
# Load helper functions
source scripts/1password-helper.sh

# SSH to root
ssh_with_1password root@103.100.37.13

# Or with custom commands
ssh_with_1password root@103.100.37.13 "df -h"
```

### Example 3: Running Remote Commands

```bash
# Load helper functions
source scripts/1password-helper.sh

# Check server status
run_remote_with_1password root@103.100.37.13 "systemctl status headscale"

# Install updates
run_remote_with_1password root@103.100.37.13 "apt-get update && apt-get upgrade -y"
```

### Example 4: Custom Configuration

If your 1Password setup is different:

```bash
# Use custom item/field names
export OP_ITEM_NAME="My VPS Credentials"
export OP_FIELD_NAME="password"

# Then use normally
./provision_vps_1password.sh
```

## Troubleshooting

### Error: "1Password CLI (op) is not installed"

**Solution:** Install 1Password CLI following the prerequisites section.

### Error: "Not signed in to 1Password CLI"

**Solution:** 
```bash
eval $(op signin)
```

If your session expired, sign in again.

### Error: "sshpass is not installed"

**Solution:** Install sshpass following the prerequisites section.

On macOS, if homebrew tap fails, you may need to compile from source or use an alternative method.

### Error: "Could not retrieve password from 1Password"

**Causes:**
1. Item name doesn't match exactly
2. Field name doesn't match exactly
3. Item is in a different vault

**Solution:**
```bash
# List all items to find yours
op item list

# Get item details
op item get "BinaryLane VPN Headscale Tailscale"

# Verify field name matches exactly (case-sensitive)
# Update your secure note if needed
```

### Error: "Permission denied (publickey,password)"

**Causes:**
1. Wrong password stored in 1Password
2. Password authentication disabled on server
3. Wrong username

**Solution:**
1. Verify the password in 1Password is correct
2. Check server's SSH configuration allows password authentication
3. Ensure you're using the correct username (typically `root` for initial setup)

### Session Timeout

1Password CLI sessions expire after 30 minutes by default.

**Solution:**
```bash
# Re-authenticate when session expires
eval $(op signin)

# Or increase session duration (in seconds)
eval $(op signin --session-duration 3600)  # 1 hour
```

## Security Considerations

### Best Practices

1. **Use Session Management**: Never store 1Password master password in scripts
2. **Limit Session Duration**: Use shorter session durations for sensitive operations
3. **Regular Password Rotation**: Change VPS passwords periodically
4. **Audit Access**: Review 1Password activity logs regularly
5. **Secure Your Workstation**: Enable disk encryption and screen lock

### Important Security Trade-offs

⚠️ **SSH Host Key Verification**: The helper scripts use `StrictHostKeyChecking=no` for convenience in automated workflows. This means:
- **Trade-off**: Easier automation but vulnerable to man-in-the-middle attacks
- **Risk**: An attacker could intercept your connection on first connect
- **Mitigation**: Only use on trusted networks, or manually verify host keys first
- **Production Alternative**: Pre-populate `~/.ssh/known_hosts` with your VPS's host key

⚠️ **Script Source Verification**: The provisioning downloads scripts from GitHub without checksum verification:
- **Trade-off**: Simpler setup but relies on GitHub's security
- **Risk**: If the repository is compromised, malicious code could be executed
- **Mitigation**: Review scripts before running, use specific commit hashes instead of 'main'
- **Production Alternative**: Clone the repository and run scripts locally

### When NOT to Use Password Authentication

After initial provisioning, you should:
1. Use SSH key authentication (not passwords)
2. Disable password authentication for non-root users
3. Keep root password authentication as emergency access only

The provision script automatically:
- Creates `deploy` user with SSH key authentication
- Disables password authentication for `deploy` user
- Keeps root password authentication (for emergency recovery)

### Alternative: SSH Key from 1Password

For even better security, you can store SSH keys in 1Password:

```bash
# Store SSH private key in 1Password
op item create \
  --category="SSH Key" \
  --title="VPS Deploy Key" \
  --vault="Private" \
  "private key=$(cat ~/.ssh/id_ed25519)"

# Retrieve and use
op item get "VPS Deploy Key" --fields "private key" > /tmp/deploy_key
chmod 600 /tmp/deploy_key
ssh -i /tmp/deploy_key deploy@robin-easy.bnr.la -p 33003
rm /tmp/deploy_key
```

## FAQ

### Q: Is this secure?

**A:** Yes, when used properly:
- Password never stored in plaintext on disk
- Transmitted over encrypted SSH connection
- 1Password provides strong encryption and access controls
- Session tokens expire automatically

However, SSH key authentication is more secure for routine access.

### Q: Can I use this in CI/CD?

**A:** Yes, with 1Password Service Accounts:
- Create a service account in 1Password
- Use service account token in CI/CD
- Grant minimal permissions needed

See: https://developer.1password.com/docs/service-accounts/

### Q: What if I don't want to use 1Password?

**A:** You can still use the original scripts:
```bash
# Manual SSH
ssh root@103.100.37.13

# Manual provisioning
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

### Q: Can I use other password managers?

**A:** Yes! The helper script can be adapted:
- LastPass CLI: `lpass show --password "item-name"`
- Bitwarden CLI: `bw get password "item-id"`
- Pass: `pass show "path/to/password"`

Modify `scripts/1password-helper.sh` to use your preferred tool.

## Additional Resources

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [1Password CLI GitHub](https://github.com/1Password/op-cli)
- [SSH Best Practices](https://www.ssh.com/academy/ssh/security)
- [sshpass Documentation](https://linux.die.net/man/1/sshpass)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify prerequisites are installed
3. Test manual password retrieval first
4. Open an issue with details about your environment and error messages

---

**Security Notice**: Never commit passwords, private keys, or 1Password session tokens to Git repositories.
