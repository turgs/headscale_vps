#!/bin/bash
#
# manage_dns_filtering.sh - Manage AdGuard Home DNS filtering allow/deny lists
#
# Usage:
#   bash manage_dns_filtering.sh allow example.com
#   bash manage_dns_filtering.sh deny badsite.com
#   bash manage_dns_filtering.sh list
#

set -uo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG_FILE="/opt/adguardhome/conf/AdGuardHome.yaml"

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

show_usage() {
    cat << 'EOF'
Usage: manage_dns_filtering.sh <command> [domain]

Commands:
  allow <domain>    Allow a domain (whitelist) - bypasses all blocking
  deny <domain>     Block a domain (blacklist) - always blocks
  list              List all custom allow/deny rules
  reset             Reset to default configuration
  reload            Reload AdGuard Home configuration

Examples:
  # Allow YouTube (if it's being blocked)
  bash manage_dns_filtering.sh allow youtube.com

  # Block a specific site
  bash manage_dns_filtering.sh deny badsite.com

  # List all custom rules
  bash manage_dns_filtering.sh list

EOF
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_adguard() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "AdGuard Home not found. Run provision_vps.sh first."
        exit 1
    fi
    
    if ! systemctl is-active --quiet adguardhome; then
        print_warning "AdGuard Home is not running. Starting it..."
        systemctl start adguardhome
        sleep 2
    fi
}

add_allow_rule() {
    local domain="$1"
    
    print_info "Adding allow rule for: $domain"
    
    # AdGuard Home whitelist format: @@||domain^$important
    local rule="@@||${domain}^$important"
    
    # Check if rule already exists
    if grep -q "@@||${domain}" "$CONFIG_FILE" 2>/dev/null; then
        print_warning "Domain $domain is already in the allow list"
        return
    fi
    
    # Add to user_rules section
    if grep -q "user_rules:" "$CONFIG_FILE"; then
        # Insert after user_rules: line
        sed -i "/user_rules:/a\  - '$rule'" "$CONFIG_FILE"
        print_success "Added $domain to allow list"
    else
        print_error "Could not find user_rules section in config"
        return 1
    fi
    
    # Reload AdGuard Home
    systemctl restart adguardhome
    sleep 2
    print_success "AdGuard Home reloaded"
}

add_deny_rule() {
    local domain="$1"
    
    print_info "Adding deny rule for: $domain"
    
    # AdGuard Home block format: ||domain^
    local rule="||${domain}^"
    
    # Check if rule already exists
    if grep -q "||${domain}^" "$CONFIG_FILE" 2>/dev/null; then
        print_warning "Domain $domain is already in the deny list"
        return
    fi
    
    # Add to user_rules section
    if grep -q "user_rules:" "$CONFIG_FILE"; then
        sed -i "/user_rules:/a\  - '$rule'" "$CONFIG_FILE"
        print_success "Added $domain to deny list"
    else
        print_error "Could not find user_rules section in config"
        return 1
    fi
    
    # Reload AdGuard Home
    systemctl restart adguardhome
    sleep 2
    print_success "AdGuard Home reloaded"
}

list_rules() {
    print_header "Custom DNS Filtering Rules"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found"
        return 1
    fi
    
    print_info "Allow List (Whitelisted domains):"
    grep "@@||" "$CONFIG_FILE" | sed 's/.*@@||//; s/\^.*//' | sed 's/^/  - /' || echo "  (none)"
    
    echo ""
    print_info "Deny List (Blocked domains):"
    grep "||.*^" "$CONFIG_FILE" | grep -v "@@||" | sed 's/.*||//; s/\^.*//' | sed 's/^/  - /' || echo "  (none)"
    
    echo ""
}

reload_config() {
    print_info "Reloading AdGuard Home configuration..."
    systemctl restart adguardhome
    sleep 2
    
    if systemctl is-active --quiet adguardhome; then
        print_success "AdGuard Home reloaded successfully"
    else
        print_error "Failed to reload AdGuard Home"
        journalctl -u adguardhome -n 20
    fi
}

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
    fi
    
    check_root
    check_adguard
    
    local command="$1"
    
    case "$command" in
        allow)
            if [[ $# -lt 2 ]]; then
                print_error "Domain required"
                show_usage
            fi
            add_allow_rule "$2"
            ;;
        deny)
            if [[ $# -lt 2 ]]; then
                print_error "Domain required"
                show_usage
            fi
            add_deny_rule "$2"
            ;;
        list)
            list_rules
            ;;
        reload)
            reload_config
            ;;
        reset)
            print_warning "Reset functionality not yet implemented"
            print_info "To reset, re-run provision_vps.sh"
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            ;;
    esac
}

main "$@"
