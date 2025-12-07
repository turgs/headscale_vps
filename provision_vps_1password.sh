#!/bin/bash
#
# provision_vps_1password.sh - Provision VPS using 1Password for root password
#
# This script uses 1Password CLI to automatically fetch the root password
# and provision the VPS without manual password entry.
#
# Prerequisites:
#   - 1Password CLI installed and signed in: eval $(op signin)
#   - sshpass installed: sudo apt-get install sshpass
#   - Password stored in 1Password secure note "BinaryLane VPN Headscale Tailscale" 
#     with field "root Password"
#
# Usage:
#   bash provision_vps_1password.sh [provision_vps.sh arguments]
#
# Examples:
#   # Basic provisioning
#   bash provision_vps_1password.sh
#
#   # With domain
#   bash provision_vps_1password.sh --domain="robin-easy.bnr.la"
#
#   # With SSH key
#   bash provision_vps_1password.sh --ssh-key="$(cat ~/.ssh/id_ed25519.pub)"
#
#   # Full options
#   bash provision_vps_1password.sh \
#     --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
#     --domain="robin-easy.bnr.la"
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the 1Password helper functions
source "$SCRIPT_DIR/scripts/1password-helper.sh"

# Configuration
VPS_HOST="${VPS_HOST:-root@103.100.37.13}"

# Show usage
show_usage() {
    cat << 'EOF'
Usage: provision_vps_1password.sh [OPTIONS]

This script provisions your VPS using the root password from 1Password.

Prerequisites:
  • 1Password CLI (op) installed and signed in
  • sshpass installed (for password automation)
  • Password stored in 1Password

1Password Setup:
  1. Create a Secure Note in 1Password
  2. Name it: "BinaryLane VPN Headscale Tailscale"
  3. Add a field: "root Password"
  4. Save your root password in that field

Options:
  All options from provision_vps.sh are supported:
  
  --ssh-key=KEY         Your SSH public key
  --ssh-port=PORT       SSH port (default: 33003)
  --domain=DOMAIN       Domain for Headscale (enables HTTPS)
  --deploy-user=USER    Deploy username (default: deploy)
  --swap-size=SIZE      Swap size (default: 2G)
  --no-reboot           Skip automatic reboot
  --help, -h            Show this help

Examples:
  # Basic provisioning
  ./provision_vps_1password.sh

  # With domain (recommended)
  ./provision_vps_1password.sh --domain="robin-easy.bnr.la"

  # With SSH key and domain
  ./provision_vps_1password.sh \
    --ssh-key="$(cat ~/.ssh/id_ed25519.pub)" \
    --domain="robin-easy.bnr.la"

Environment Variables:
  VPS_HOST          Host to connect to (default: root@103.100.37.13)
  OP_ITEM_NAME      1Password item name (default: "BinaryLane VPN Headscale Tailscale")
  OP_FIELD_NAME     1Password field name (default: "root Password")

EOF
}

# Parse arguments for help
for arg in "$@"; do
    if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
        show_usage
        exit 0
    fi
done

# Main execution
main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔐 VPS Provisioning with 1Password Authentication"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check prerequisites
    echo "📋 Checking prerequisites..."
    check_1password_cli || exit 1
    check_sshpass || exit 1
    check_1password_signin || exit 1
    echo "✅ All prerequisites met"
    echo ""
    
    # Get password (validate it exists)
    echo "🔑 Retrieving password from 1Password..."
    local password
    password=$(get_password_from_1password "$OP_ITEM_NAME" "$OP_FIELD_NAME") || exit 1
    echo "✅ Password retrieved successfully"
    echo ""
    
    # Run provisioning
    echo "🚀 Starting VPS provisioning..."
    echo "Host: $VPS_HOST"
    echo "Arguments: $*"
    echo ""
    
    provision_vps_with_1password "$VPS_HOST" "$@"
    
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Provisioning completed successfully!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Next Steps:"
        echo "  1. Wait 2-3 minutes for VPS to reboot"
        echo "  2. SSH with: ssh deploy@robin-easy.bnr.la -p 33003"
        echo "  3. Run exit node setup: curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/setup_exit_node.sh | bash"
        echo ""
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Provisioning failed with exit code: $exit_code"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
    
    exit $exit_code
}

main "$@"
