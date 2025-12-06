#!/bin/bash
#
# check_health.sh - Quick health check for Headscale VPS
#
# Usage:
#   bash check_health.sh
#

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_service() {
    local service=$1
    local display_name=$2
    
    echo -n "  $display_name: "
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        return 1
    fi
}

print_stat() {
    local label=$1
    local value=$2
    local warning_threshold=${3:-}
    
    echo -n "  $label: "
    if [[ -n "$warning_threshold" ]] && (( $(echo "$value > $warning_threshold" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${YELLOW}$value${NC}"
    else
        echo -e "${GREEN}$value${NC}"
    fi
}

main() {
    print_header "🏥 Headscale VPS Health Check"
    
    # Check services
    echo ""
    echo "Services Status:"
    check_service "headscale" "Headscale"
    check_service "tailscaled" "Tailscale"
    check_service "adguardhome" "AdGuard Home"
    check_service "docker" "Docker"
    check_service "fail2ban" "fail2ban"
    
    # System resources
    echo ""
    echo "System Resources:"
    
    # CPU load
    load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    print_stat "CPU Load" "$load" "2.0"
    
    # Memory usage
    mem_used=$(free -h | awk '/^Mem:/ {print $3}')
    mem_total=$(free -h | awk '/^Mem:/ {print $2}')
    print_stat "Memory" "$mem_used / $mem_total"
    
    # Disk usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    print_stat "Disk Usage" "$disk_used / $disk_total ($disk_usage%)" "80"
    
    # Uptime
    uptime_val=$(uptime -p)
    print_stat "Uptime" "$uptime_val"
    
    # Network
    echo ""
    echo "Network:"
    
    # Count connected Headscale nodes
    if command -v headscale &>/dev/null; then
        node_count=$(headscale nodes list 2>/dev/null | grep -c "^id:" || echo "0")
        print_stat "Connected Nodes" "$node_count"
    fi
    
    # Check if exit node is advertising
    if tailscale status 2>/dev/null | grep -q "offers exit node"; then
        echo -e "  Exit Node: ${GREEN}✓ Advertising${NC}"
    else
        echo -e "  Exit Node: ${YELLOW}⚠ Not advertising${NC}"
    fi
    
    # Recent activity
    echo ""
    echo "Recent Activity:"
    
    # Headscale errors in last hour
    headscale_errors=$(journalctl -u headscale --since "1 hour ago" --no-pager 2>/dev/null | grep -ci "error" || echo "0")
    if [[ "$headscale_errors" -gt 0 ]]; then
        echo -e "  Headscale Errors (last hour): ${YELLOW}$headscale_errors${NC}"
    else
        echo -e "  Headscale Errors (last hour): ${GREEN}$headscale_errors${NC}"
    fi
    
    # AdGuard Home stats
    if systemctl is-active --quiet adguardhome; then
        echo -e "  AdGuard Home: ${GREEN}✓ Filtering active${NC}"
    fi
    
    # fail2ban bans
    if command -v fail2ban-client &>/dev/null; then
        banned_count=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned:" | awk '{print $4}' || echo "0")
        if [[ "$banned_count" -gt 0 ]]; then
            echo -e "  fail2ban Active Bans: ${YELLOW}$banned_count${NC}"
        else
            echo -e "  fail2ban Active Bans: ${GREEN}$banned_count${NC}"
        fi
    fi
    
    echo ""
    print_header "✅ Health Check Complete"
    echo ""
    echo "For detailed logs:"
    echo "  sudo journalctl -u headscale -n 50"
    echo "  sudo journalctl -u adguardhome -n 50"
    echo ""
    echo "Web Interfaces:"
    echo "  AdGuard Home: http://$(hostname -I | awk '{print $1}'):3000"
    echo ""
}

main "$@"
