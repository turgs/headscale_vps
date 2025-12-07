#!/bin/bash
#
# 1password-helper.sh - Helper script to retrieve passwords from 1Password CLI
#
# This script fetches the root password from 1Password and uses it with sshpass
# to automate SSH connections without manual password entry.
#
# Prerequisites:
#   - 1Password CLI (op) must be installed: https://developer.1password.com/docs/cli/get-started
#   - sshpass must be installed: sudo apt-get install sshpass (Linux) or brew install sshpass (Mac)
#   - You must be signed in to 1Password CLI: eval $(op signin)
#
# Configuration:
#   - The script expects a secure note named "BinaryLane VPN Headscale Tailscale"
#   - The note should have a field named "root Password" containing the root password
#
# Usage:
#   source scripts/1password-helper.sh
#   ssh_with_1password root@103.100.37.13 [additional ssh args]
#   run_remote_with_1password root@103.100.37.13 "command to run"
#

set -euo pipefail

# Configuration
OP_ITEM_NAME="${OP_ITEM_NAME:-BinaryLane VPN Headscale Tailscale}"
OP_FIELD_NAME="${OP_FIELD_NAME:-root Password}"

# Check if 1Password CLI is installed
check_1password_cli() {
    if ! command -v op &> /dev/null; then
        echo "❌ Error: 1Password CLI (op) is not installed" >&2
        echo "Install it from: https://developer.1password.com/docs/cli/get-started" >&2
        return 1
    fi
}

# Check if sshpass is installed
check_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        echo "❌ Error: sshpass is not installed" >&2
        echo "" >&2
        echo "Install it with:" >&2
        echo "  • Linux: sudo apt-get install sshpass" >&2
        echo "  • macOS: brew install hudochenkov/sshpass/sshpass" >&2
        echo "  • macOS (alternative): Install from source or use expect-based solution" >&2
        return 1
    fi
}

# Check if signed in to 1Password CLI
check_1password_signin() {
    if ! op account list &> /dev/null; then
        echo "❌ Error: Not signed in to 1Password CLI" >&2
        echo "" >&2
        echo "Sign in with:" >&2
        echo "  eval \$(op signin)" >&2
        return 1
    fi
}

# Get password from 1Password
get_password_from_1password() {
    local item_name="$1"
    local field_name="$2"
    
    # Try to get password
    local password
    password=$(op item get "$item_name" --fields "$field_name" 2>/dev/null || echo "")
    
    if [[ -z "$password" ]]; then
        echo "❌ Error: Could not retrieve password from 1Password" >&2
        echo "" >&2
        echo "Make sure you have:" >&2
        echo "  • A secure note named: '$item_name'" >&2
        echo "  • A field named: '$field_name'" >&2
        echo "" >&2
        echo "You can create it in 1Password with:" >&2
        echo "  1. Create a Secure Note in 1Password" >&2
        echo "  2. Name it: '$item_name'" >&2
        echo "  3. Add a field named: '$field_name'" >&2
        echo "  4. Save your root password in that field" >&2
        return 1
    fi
    
    echo "$password"
}

# SSH with password from 1Password
ssh_with_1password() {
    check_1password_cli || return 1
    check_sshpass || return 1
    check_1password_signin || return 1
    
    local password
    password=$(get_password_from_1password "$OP_ITEM_NAME" "$OP_FIELD_NAME") || return 1
    
    # Use sshpass to provide password to SSH
    # -o StrictHostKeyChecking=accept-new to avoid interactive prompt for new hosts
    SSHPASS="$password" sshpass -e ssh -o StrictHostKeyChecking=accept-new "$@"
}

# Run remote command with password from 1Password
run_remote_with_1password() {
    check_1password_cli || return 1
    check_sshpass || return 1
    check_1password_signin || return 1
    
    local host="$1"
    shift
    local command="$*"
    
    local password
    password=$(get_password_from_1password "$OP_ITEM_NAME" "$OP_FIELD_NAME") || return 1
    
    # Use sshpass to provide password to SSH
    SSHPASS="$password" sshpass -e ssh -o StrictHostKeyChecking=accept-new "$host" "$command"
}

# Provision VPS with password from 1Password
provision_vps_with_1password() {
    check_1password_cli || return 1
    check_sshpass || return 1
    check_1password_signin || return 1
    
    local host="${1:-root@103.100.37.13}"
    shift || true
    
    local password
    password=$(get_password_from_1password "$OP_ITEM_NAME" "$OP_FIELD_NAME") || return 1
    
    echo "🚀 Provisioning VPS with password from 1Password..."
    echo "Host: $host"
    echo ""
    
    # Download and run provision script with password authentication
    SSHPASS="$password" sshpass -e ssh -o StrictHostKeyChecking=accept-new "$host" 'bash -s' "$@" < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
}

# Export functions for use in other scripts
export -f check_1password_cli
export -f check_sshpass
export -f check_1password_signin
export -f get_password_from_1password
export -f ssh_with_1password
export -f run_remote_with_1password
export -f provision_vps_with_1password
