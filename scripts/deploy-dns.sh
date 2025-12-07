#!/bin/bash
#
# deploy-dns.sh - Deploy DNS filter configuration to VPS
#
# This script:
# 1. Parses DNS allowlist/blocklist files
# 2. Generates AdGuard Home YAML configuration
# 3. SSH to VPS and updates /opt/adguardhome/conf/AdGuardHome.yaml
# 4. Validates config before applying
# 5. Reloads AdGuard Home service
# 6. Supports rollback on failure
#
# Usage:
#   ./scripts/deploy-dns.sh --host=VPS_HOST [--ssh-key=PATH] [--ssh-port=33003] [--dry-run]
#

set -euo pipefail

# Configuration
VPS_HOST="${VPS_HOST:-}"
SSH_KEY="${SSH_KEY:-}"
SSH_PORT="${SSH_PORT:-33003}"
SSH_USER="${SSH_USER:-deploy}"
DRY_RUN="${DRY_RUN:-false}"
ADGUARD_CONFIG_PATH="/opt/adguardhome/conf/AdGuardHome.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host=*)
                VPS_HOST="${1#*=}"
                shift
                ;;
            --ssh-key=*)
                SSH_KEY="${1#*=}"
                shift
                ;;
            --ssh-port=*)
                SSH_PORT="${1#*=}"
                shift
                ;;
            --ssh-user=*)
                SSH_USER="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

show_usage() {
    cat << 'EOF'
Usage: deploy-dns.sh [OPTIONS]

Deploy DNS filter configuration to VPS.

Options:
  --host=HOST           VPS hostname or IP address (required)
  --ssh-key=PATH        Path to SSH private key (optional)
  --ssh-port=PORT       SSH port (default: 33003)
  --ssh-user=USER       SSH user (default: deploy)
  --dry-run             Show what would be done without making changes
  --help, -h            Show this help message

Environment variables:
  VPS_HOST              Same as --host
  SSH_KEY               Same as --ssh-key
  SSH_PORT              Same as --ssh-port
  SSH_USER              Same as --ssh-user

Examples:
  # Basic usage
  ./scripts/deploy-dns.sh --host=vpn.example.com

  # With SSH key
  ./scripts/deploy-dns.sh --host=vpn.example.com --ssh-key=/path/to/key

  # Dry run
  ./scripts/deploy-dns.sh --host=vpn.example.com --dry-run

  # Using environment variables (for CI/CD)
  export VPS_HOST=vpn.example.com
  export SSH_KEY=/path/to/key
  ./scripts/deploy-dns.sh
EOF
}

# Validate prerequisites
validate_prereqs() {
    # Check for required commands
    for cmd in ssh scp; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
        fi
    done

    # Check VPS_HOST is set
    if [[ -z "$VPS_HOST" ]]; then
        error "VPS host is required. Use --host=HOST or set VPS_HOST environment variable"
    fi

    # Check DNS config files exist
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root="$(cd "$script_dir/.." && pwd)"
    
    ALLOWLIST_FILE="$repo_root/config/dns-allowlist.txt"
    BLOCKLIST_FILE="$repo_root/config/dns-blocklist.txt"

    if [[ ! -f "$ALLOWLIST_FILE" ]]; then
        error "Allowlist file not found: $ALLOWLIST_FILE"
    fi

    if [[ ! -f "$BLOCKLIST_FILE" ]]; then
        error "Blocklist file not found: $BLOCKLIST_FILE"
    fi

    success "Prerequisites validated"
}

# Parse DNS config files
parse_dns_files() {
    info "Parsing DNS configuration files..."

    # Parse allowlist (remove comments and empty lines)
    ALLOWLIST_DOMAINS=$(grep -v '^#' "$ALLOWLIST_FILE" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    
    # Parse blocklist (remove comments and empty lines)
    BLOCKLIST_DOMAINS=$(grep -v '^#' "$BLOCKLIST_FILE" | grep -v '^[[:space:]]*$' | sed 's/[[:space:]]*#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)

    # Count domains
    ALLOWLIST_COUNT=$(echo "$ALLOWLIST_DOMAINS" | grep -c '.' || echo "0")
    BLOCKLIST_COUNT=$(echo "$BLOCKLIST_DOMAINS" | grep -c '.' || echo "0")

    info "Found $ALLOWLIST_COUNT domains in allowlist"
    info "Found $BLOCKLIST_COUNT domains in blocklist"

    if [[ $ALLOWLIST_COUNT -eq 0 && $BLOCKLIST_COUNT -eq 0 ]]; then
        warn "No domains found in either list. Nothing to deploy."
    fi

    success "DNS files parsed successfully"
}

# Build SSH command with optional key
build_ssh_cmd() {
    local ssh_cmd="ssh -p $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY"
    fi
    
    ssh_cmd="$ssh_cmd -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    
    echo "$ssh_cmd $SSH_USER@$VPS_HOST"
}

# Build SCP command with optional key
build_scp_cmd() {
    local scp_cmd="scp -P $SSH_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_cmd="$scp_cmd -i $SSH_KEY"
    fi
    
    scp_cmd="$scp_cmd -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    
    echo "$scp_cmd"
}

# Generate user_rules for AdGuard Home
generate_user_rules() {
    local rules=()
    
    # Add allowlist domains
    if [[ -n "$ALLOWLIST_DOMAINS" ]]; then
        while IFS= read -r domain; do
            if [[ -n "$domain" ]]; then
                rules+=("  - '@@||${domain}^\$important'")
            fi
        done <<< "$ALLOWLIST_DOMAINS"
    fi
    
    # Add blocklist domains
    if [[ -n "$BLOCKLIST_DOMAINS" ]]; then
        while IFS= read -r domain; do
            if [[ -n "$domain" ]]; then
                rules+=("  - '||${domain}^'")
            fi
        done <<< "$BLOCKLIST_DOMAINS"
    fi
    
    # Output rules as YAML array
    printf '%s\n' "${rules[@]}"
}

# Backup current config on VPS
backup_config() {
    info "Creating backup of current AdGuard Home configuration..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local backup_path="${ADGUARD_CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would backup: $ADGUARD_CONFIG_PATH -> $backup_path"
        return 0
    fi
    
    if $ssh_cmd "sudo cp $ADGUARD_CONFIG_PATH $backup_path" 2>/dev/null; then
        success "Backup created: $backup_path"
        echo "$backup_path"
    else
        error "Failed to create backup"
    fi
}

# Deploy configuration to VPS
deploy_config() {
    info "Deploying DNS configuration to VPS..."
    
    local ssh_cmd=$(build_ssh_cmd)
    local user_rules=$(generate_user_rules)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would deploy the following rules:"
        echo "user_rules:"
        echo "$user_rules"
        return 0
    fi
    
    # Create temporary script to update YAML on VPS
    local update_script=$(cat << 'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

CONFIG_FILE="$1"
TEMP_FILE="${CONFIG_FILE}.tmp"

# Read new user_rules from stdin
NEW_RULES=$(cat)

# Use Python to safely update YAML (preserving structure)
python3 - "$CONFIG_FILE" "$TEMP_FILE" << 'PYTHON_EOF'
import sys
import re

config_file = sys.argv[1]
temp_file = sys.argv[2]

# Read new rules from stdin
new_rules = sys.stdin.read().strip()

# Read the current config
with open(config_file, 'r') as f:
    content = f.read()

# Find and replace the user_rules section
# Pattern matches: user_rules: followed by lines starting with "  - "
pattern = r'(user_rules:)(?:\n\s*-\s*[^\n]+)*'

replacement = 'user_rules:\n' + new_rules

# Replace the user_rules section
new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

# Write to temp file
with open(temp_file, 'w') as f:
    f.write(new_content)

print("Configuration updated successfully")
PYTHON_EOF

# Move temp file to config file
sudo mv "$TEMP_FILE" "$CONFIG_FILE"
sudo chown root:root "$CONFIG_FILE"
sudo chmod 644 "$CONFIG_FILE"

echo "Config file updated"
SCRIPT_EOF
)
    
    # Execute update on VPS
    # We pipe user_rules to the update script which runs remotely via SSH
    info "Updating AdGuard Home configuration..."
    
    # Create a temporary file to hold the update script for better error handling
    local temp_script="/tmp/adguard-update-$$.sh"
    echo "$update_script" > "$temp_script"
    
    # Execute: Send update script via SSH and pipe user_rules to it
    if echo "$user_rules" | $ssh_cmd "bash -s -- $ADGUARD_CONFIG_PATH" < "$temp_script"; then
        rm -f "$temp_script"
        success "Configuration updated on VPS"
    else
        rm -f "$temp_script"
        error "Failed to update configuration"
    fi
}

# Validate AdGuard Home configuration
validate_config() {
    info "Validating AdGuard Home configuration..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would validate configuration"
        return 0
    fi
    
    # Try to parse the YAML with Python
    local validate_script=$(cat << 'SCRIPT_EOF'
#!/bin/bash
CONFIG_FILE="$1"

python3 << 'PYTHON_EOF'
import sys
import yaml

try:
    with open(sys.argv[1], 'r') as f:
        config = yaml.safe_load(f)
    
    # Basic validation checks
    if 'user_rules' not in config:
        print("ERROR: user_rules section missing")
        sys.exit(1)
    
    if not isinstance(config['user_rules'], list):
        print("ERROR: user_rules must be a list")
        sys.exit(1)
    
    print(f"Valid configuration with {len(config['user_rules'])} user rules")
    sys.exit(0)
except yaml.YAMLError as e:
    print(f"ERROR: Invalid YAML - {e}")
    sys.exit(1)
except Exception as e:
    print(f"ERROR: Validation failed - {e}")
    sys.exit(1)
PYTHON_EOF
SCRIPT_EOF
)
    
    if $ssh_cmd "bash -s -- $ADGUARD_CONFIG_PATH" <<< "$validate_script" 2>&1; then
        success "Configuration is valid"
    else
        error "Configuration validation failed"
    fi
}

# Reload AdGuard Home service
reload_service() {
    info "Reloading AdGuard Home service..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY RUN] Would reload AdGuard Home service"
        return 0
    fi
    
    if $ssh_cmd "sudo systemctl restart adguardhome" 2>&1; then
        # Wait for service to start
        sleep 3
        
        # Check if service is running
        if $ssh_cmd "sudo systemctl is-active --quiet adguardhome" 2>&1; then
            success "AdGuard Home service reloaded successfully"
        else
            error "AdGuard Home service failed to start after reload"
        fi
    else
        error "Failed to reload AdGuard Home service"
    fi
}

# Rollback to backup
rollback() {
    local backup_path="$1"
    
    warn "Rolling back to previous configuration..."
    
    local ssh_cmd=$(build_ssh_cmd)
    
    if $ssh_cmd "sudo cp $backup_path $ADGUARD_CONFIG_PATH && sudo systemctl restart adguardhome" 2>&1; then
        success "Rollback completed"
    else
        error "Rollback failed! Manual intervention required."
    fi
}

# Main function
main() {
    parse_args "$@"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  DNS Filter Deployment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Running in DRY RUN mode - no changes will be made"
        echo ""
    fi
    
    # Validate prerequisites
    validate_prereqs
    
    # Parse DNS files
    parse_dns_files
    
    # Test SSH connection
    info "Testing SSH connection to $VPS_HOST..."
    local ssh_cmd=$(build_ssh_cmd)
    if ! $ssh_cmd "echo 'Connection successful'" &>/dev/null; then
        error "Cannot connect to VPS via SSH. Check host, port, and credentials."
    fi
    success "SSH connection successful"
    
    # Create backup
    local backup_path
    backup_path=$(backup_config)
    
    # Deploy configuration
    if deploy_config; then
        # Validate new configuration
        if validate_config; then
            # Reload service
            if reload_service; then
                echo ""
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                success "Deployment completed successfully!"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                info "DNS filter configuration updated on $VPS_HOST"
                info "Allowlist: $ALLOWLIST_COUNT domains"
                info "Blocklist: $BLOCKLIST_COUNT domains"
                [[ -n "$backup_path" ]] && info "Backup: $backup_path"
                echo ""
            else
                # Rollback on service reload failure
                [[ -n "$backup_path" ]] && rollback "$backup_path"
                error "Service reload failed"
            fi
        else
            # Rollback on validation failure
            [[ -n "$backup_path" ]] && rollback "$backup_path"
            error "Configuration validation failed"
        fi
    else
        error "Configuration deployment failed"
    fi
}

# Run main function
main "$@"
