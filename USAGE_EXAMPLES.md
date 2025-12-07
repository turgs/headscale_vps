# 1Password CLI Integration - Usage Examples

This document provides practical examples of using the 1Password CLI integration for your Headscale VPS.

## Quick Start (3 Steps)

### Step 1: Setup 1Password CLI

```bash
# Install 1Password CLI (macOS)
brew install 1password-cli

# Install sshpass (macOS)
brew install hudochenkov/sshpass/sshpass

# Sign in to 1Password
eval $(op signin)
```

### Step 2: Store Your Password

In 1Password app:
1. Create a Secure Note
2. Title: `BinaryLane VPN Headscale Tailscale`
3. Add field: `root Password`
4. Save your VPS root password

### Step 3: Provision Your VPS

```bash
# Clone the repository
git clone https://github.com/turgs/headscale_vps.git
cd headscale_vps

# Run provisioning with 1Password
./provision_vps_1password.sh --domain="robin-easy.bnr.la"
```

That's it! No manual password typing required.

## Common Use Cases

### Use Case 1: Initial VPS Setup with All Options

```bash
# Full provisioning with SSH key, domain, and custom swap
./provision_vps_1password.sh \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="robin-easy.bnr.la" \
  --swap-size=4G
```

### Use Case 2: Quick SSH Access to Root

```bash
# Source the helper functions
source scripts/1password-helper.sh

# SSH to root account
ssh_with_1password root@103.100.37.13

# Or run a single command
run_remote_with_1password root@103.100.37.13 "df -h"
```

### Use Case 3: Running Remote Commands

```bash
source scripts/1password-helper.sh

# Check system status
run_remote_with_1password root@103.100.37.13 "systemctl status headscale"

# Update packages
run_remote_with_1password root@103.100.37.13 "apt-get update && apt-get upgrade -y"

# View logs
run_remote_with_1password root@103.100.37.13 "journalctl -u headscale -n 50"
```

### Use Case 4: Custom 1Password Configuration

If your 1Password setup is different:

```bash
# Set custom item and field names
export OP_ITEM_NAME="My VPS Passwords"
export OP_FIELD_NAME="Binary Lane Root"
export VPS_HOST="root@YOUR_IP_ADDRESS"

# Use normally
./provision_vps_1password.sh
```

### Use Case 5: Testing Before Provisioning

```bash
# Test that password retrieval works
source scripts/1password-helper.sh
get_password_from_1password "BinaryLane VPN Headscale Tailscale" "root Password"

# Test SSH connection
ssh_with_1password root@103.100.37.13 "echo 'Connection successful!'"
```

## Comparison: With vs Without 1Password

### ❌ Without 1Password CLI (Manual)

```bash
# You have to type password every time
ssh root@103.100.37.13 'bash -s' < <(curl -fsSL ...) 
# Password: [you type it manually]

ssh root@103.100.37.13 "apt-get update"
# Password: [you type it again]

ssh root@103.100.37.13 "journalctl -u headscale"
# Password: [you type it again]
```

### ✅ With 1Password CLI (Automated)

```bash
# One-time setup
eval $(op signin)

# Provision - no password typing!
./provision_vps_1password.sh --domain="robin-easy.bnr.la"

# Commands - no password typing!
source scripts/1password-helper.sh
run_remote_with_1password root@103.100.37.13 "apt-get update"
run_remote_with_1password root@103.100.37.13 "journalctl -u headscale"
```

## Advanced Workflows

### Workflow 1: Automated Provisioning Script

Create a custom script `auto-provision.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Configuration
export OP_ITEM_NAME="BinaryLane VPN Headscale Tailscale"
export OP_FIELD_NAME="root Password"

# Sign in to 1Password
eval $(op signin)

# Provision VPS
./provision_vps_1password.sh \
  --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
  --domain="robin-easy.bnr.la" \
  --swap-size=4G

echo "✅ Provisioning complete!"
echo "⏰ Waiting for reboot (3 minutes)..."
sleep 180

# Test connection to deploy user (after reboot)
ssh deploy@robin-easy.bnr.la -p 33003 "echo '✅ Deploy user accessible'"

echo "🎉 Setup complete! Your VPS is ready."
```

### Workflow 2: Batch Commands

Run multiple commands in sequence:

```bash
#!/bin/bash
source scripts/1password-helper.sh

commands=(
  "apt-get update"
  "systemctl status headscale"
  "headscale nodes list"
  "journalctl -u headscale -n 20"
)

for cmd in "${commands[@]}"; do
  echo "Running: $cmd"
  run_remote_with_1password root@103.100.37.13 "$cmd"
  echo "---"
done
```

### Workflow 3: Maintenance Script

Create `maintenance.sh`:

```bash
#!/bin/bash
source scripts/1password-helper.sh

# Update system
echo "📦 Updating system packages..."
run_remote_with_1password root@103.100.37.13 "apt-get update && apt-get upgrade -y"

# Check services
echo "🔍 Checking service status..."
run_remote_with_1password root@103.100.37.13 "systemctl status headscale adguardhome"

# View recent logs
echo "📋 Recent logs..."
run_remote_with_1password root@103.100.37.13 "journalctl -u headscale -n 50"

echo "✅ Maintenance complete!"
```

## Troubleshooting

### Issue: "Session expired"

```bash
# Solution: Re-authenticate
eval $(op signin)

# Or use longer session
eval $(op signin --session-duration 3600)  # 1 hour
```

### Issue: "Password not found"

```bash
# Verify item exists
op item list | grep "BinaryLane"

# Get item details
op item get "BinaryLane VPN Headscale Tailscale"

# Test password retrieval
source scripts/1password-helper.sh
get_password_from_1password "BinaryLane VPN Headscale Tailscale" "root Password"
```

### Issue: "sshpass not found" (macOS)

```bash
# Install from Homebrew tap
brew install hudochenkov/sshpass/sshpass

# Or compile from source if tap doesn't work
```

### Issue: Connection refused

```bash
# Check you're using the right host
export VPS_HOST="root@YOUR_ACTUAL_IP"

# Test network connectivity
ping YOUR_ACTUAL_IP

# Test SSH without password automation
ssh root@YOUR_ACTUAL_IP
```

## Security Best Practices

1. **Session Management**
   ```bash
   # Use short sessions for sensitive operations
   eval $(op signin --session-duration 600)  # 10 minutes
   ```

2. **After Initial Setup**
   ```bash
   # Switch to SSH keys (more secure than passwords)
   ssh-copy-id deploy@robin-easy.bnr.la -p 33003
   
   # Use key-based auth going forward
   ssh deploy@robin-easy.bnr.la -p 33003
   ```

3. **Verify Before Running**
   ```bash
   # Always review scripts before piping to bash
   curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh | less
   ```

## Integration with Other Tools

### With Git Hooks

Add to `.git/hooks/pre-push`:

```bash
#!/bin/bash
# Test VPS is accessible before pushing
source scripts/1password-helper.sh
run_remote_with_1password root@103.100.37.13 "echo 'VPS OK'" || {
  echo "❌ VPS not accessible"
  exit 1
}
```

### With Cron Jobs

```bash
# Daily maintenance (after setting up service account)
0 2 * * * cd /path/to/headscale_vps && ./maintenance.sh >> /var/log/vps-maintenance.log 2>&1
```

### With Ansible/Automation

```yaml
# ansible playbook
- name: Provision VPS with 1Password
  shell: |
    cd /path/to/headscale_vps
    eval $(op signin)
    ./provision_vps_1password.sh --domain="{{ vps_domain }}"
```

## Tips and Tricks

### Tip 1: Shell Alias for Quick Access

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias vpsssh='source ~/headscale_vps/scripts/1password-helper.sh && ssh_with_1password root@103.100.37.13'
alias vpsrun='source ~/headscale_vps/scripts/1password-helper.sh && run_remote_with_1password root@103.100.37.13'
```

Then use:
```bash
vpsssh
vpsrun "systemctl status headscale"
```

### Tip 2: Pre-signin for Multiple Operations

```bash
# Sign in once for multiple operations
eval $(op signin)

# Run multiple commands without re-authenticating
./provision_vps_1password.sh
source scripts/1password-helper.sh
ssh_with_1password root@103.100.37.13
run_remote_with_1password root@103.100.37.13 "df -h"
```

### Tip 3: Use Environment Files

Create `.env`:
```bash
OP_ITEM_NAME="BinaryLane VPN Headscale Tailscale"
OP_FIELD_NAME="root Password"
VPS_HOST="root@103.100.37.13"
```

Load before use:
```bash
source .env
./provision_vps_1password.sh
```

## Next Steps

After successful provisioning:

1. **Change AdGuard Home password**
   ```bash
   # Visit http://robin-easy.bnr.la:3000
   # Login: admin / changeme
   # Settings → Change Password
   ```

2. **Create Headscale users**
   ```bash
   ssh deploy@robin-easy.bnr.la -p 33003
   sudo headscale users create myuser
   sudo headscale preauthkeys create --user myuser --reusable --expiration 24h
   ```

3. **Setup exit node**
   ```bash
   ssh deploy@robin-easy.bnr.la -p 33003
   curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/setup_exit_node.sh | bash
   ```

For complete documentation, see [1PASSWORD_SETUP.md](1PASSWORD_SETUP.md).
