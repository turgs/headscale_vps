#!/bin/bash
# Deploy DNS filters to VPS AdGuard Home
# Usage: ./scripts/deploy-dns.sh --host=vpn.example.com [--ssh-key=~/.ssh/id_rsa] [--dry-run]

set -euo pipefail

# Defaults
VPS_HOST="${VPS_HOST:-}"
SSH_KEY="${SSH_KEY:-}"
SSH_PORT="${SSH_PORT:-33003}"
SSH_USER="${SSH_USER:-deploy}"
DRY_RUN="${DRY_RUN:-false}"
CONFIG_PATH="/opt/adguardhome/conf/AdGuardHome.yaml"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host=*) VPS_HOST="${1#*=}"; shift ;;
        --ssh-key=*) SSH_KEY="${1#*=}"; shift ;;
        --ssh-port=*) SSH_PORT="${1#*=}"; shift ;;
        --ssh-user=*) SSH_USER="${1#*=}"; shift ;;
        --dry-run) DRY_RUN="true"; shift ;;
        --help|-h) 
            echo "Usage: $0 --host=HOST [--ssh-key=PATH] [--ssh-port=33003] [--dry-run]"
            exit 0 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[[ -z "$VPS_HOST" ]] && { echo "ERROR: --host required"; exit 1; }

# Setup SSH command
SSH_CMD="ssh -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
[[ -n "$SSH_KEY" ]] && SSH_CMD="$SSH_CMD -i $SSH_KEY"
SSH_CMD="$SSH_CMD $SSH_USER@$VPS_HOST"

# Get file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST="$SCRIPT_DIR/../config/dns-allowlist.txt"
BLOCKLIST="$SCRIPT_DIR/../config/dns-blocklist.txt"

[[ ! -f "$ALLOWLIST" ]] && { echo "ERROR: $ALLOWLIST not found"; exit 1; }
[[ ! -f "$BLOCKLIST" ]] && { echo "ERROR: $BLOCKLIST not found"; exit 1; }

# Parse domains (remove comments and empty lines)
parse_domains() {
    grep -v '^#' "$1" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true
}

ALLOW_DOMAINS=$(parse_domains "$ALLOWLIST")
BLOCK_DOMAINS=$(parse_domains "$BLOCKLIST")

ALLOW_COUNT=$(echo "$ALLOW_DOMAINS" | grep -c '.' || echo "0")
BLOCK_COUNT=$(echo "$BLOCK_DOMAINS" | grep -c '.' || echo "0")

echo "📋 Allowlist: $ALLOW_COUNT domains | Blocklist: $BLOCK_COUNT domains"

# Generate YAML rules
generate_rules() {
    local rules=""
    while IFS= read -r domain; do
        [[ -n "$domain" ]] && rules+="  - '@@||${domain}^\$important'"$'\n'
    done <<< "$ALLOW_DOMAINS"
    while IFS= read -r domain; do
        [[ -n "$domain" ]] && rules+="  - '||${domain}^'"$'\n'
    done <<< "$BLOCK_DOMAINS"
    echo -n "$rules"
}

USER_RULES=$(generate_rules)

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN - Would deploy:"
    echo "$USER_RULES"
    exit 0
fi

# Test SSH
echo "🔌 Testing connection..."
$SSH_CMD "echo 'Connected'" &>/dev/null || { echo "ERROR: SSH failed"; exit 1; }

# Backup, update, and reload
echo "📦 Deploying..."
BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

UPDATE_SCRIPT='
CONFIG="$1"
BACKUP="$2"
sudo cp "$CONFIG" "$BACKUP"
python3 - "$CONFIG" << "PY_EOF"
import sys, re
with open(sys.argv[1], "r") as f: content = f.read()
rules = sys.stdin.read().strip()
content = re.sub(r"(user_rules:)(?:\n\s*-\s*[^\n]+)*", f"user_rules:\n{rules}", content, flags=re.MULTILINE)
with open(sys.argv[1] + ".tmp", "w") as f: f.write(content)
PY_EOF
sudo mv "${CONFIG}.tmp" "$CONFIG"
sudo systemctl restart adguardhome
sleep 2
sudo systemctl is-active --quiet adguardhome || { sudo cp "$BACKUP" "$CONFIG"; sudo systemctl restart adguardhome; exit 1; }
'

if echo "$USER_RULES" | $SSH_CMD "bash -s -- $CONFIG_PATH $BACKUP_PATH" <<< "$UPDATE_SCRIPT"; then
    echo "✅ Deployed successfully (backup: $BACKUP_PATH)"
else
    echo "❌ Deployment failed (rolled back)"
    exit 1
fi
