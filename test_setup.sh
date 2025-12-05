#!/bin/bash
#
# test_setup.sh - Test script to verify Headscale VPS setup
#
# Usage:
#   bash test_setup.sh [SERVER_IP] [SSH_PORT]
#
# Examples:
#   bash test_setup.sh 192.168.1.100
#   bash test_setup.sh 192.168.1.100 33003
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="${1:-}"
SSH_PORT="${2:-33003}"
SSH_USER="${3:-deploy}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_test() {
    echo -n "  Testing: $1 ... "
    ((TESTS_TOTAL++))
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
    [[ -n "${1:-}" ]] && echo -e "    ${RED}Error: $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}"
    echo -e "    ${YELLOW}$1${NC}"
}

show_usage() {
    cat << EOF
Usage: test_setup.sh [SERVER_IP] [SSH_PORT] [SSH_USER]

Arguments:
  SERVER_IP   IP address of the VPS (required)
  SSH_PORT    SSH port (default: 33003)
  SSH_USER    SSH user (default: deploy)

Examples:
  bash test_setup.sh 192.168.1.100
  bash test_setup.sh 192.168.1.100 33003 deploy

EOF
    exit 1
}

run_ssh_command() {
    local cmd="$1"
    # Use accept-new instead of no to avoid MITM attacks while still being automated
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" "${SSH_USER}@${SERVER_IP}" "$cmd" 2>/dev/null
}

test_connectivity() {
    print_test "Network connectivity to $SERVER_IP"
    if ping -c 1 -W 2 "$SERVER_IP" &>/dev/null; then
        print_pass
    else
        print_fail "Cannot ping server"
        return 1
    fi
}

test_ssh_connection() {
    print_test "SSH connection on port $SSH_PORT"
    if run_ssh_command "echo ok" &>/dev/null; then
        print_pass
    else
        print_fail "Cannot connect via SSH"
        return 1
    fi
}

test_headscale_installed() {
    print_test "Headscale installation"
    if run_ssh_command "command -v headscale" &>/dev/null; then
        print_pass
        
        # Get version
        version=$(run_ssh_command "headscale version 2>/dev/null | head -n1" || echo "unknown")
        echo -e "    ${BLUE}Version: $version${NC}"
    else
        print_fail "Headscale not installed"
        return 1
    fi
}

test_headscale_service() {
    print_test "Headscale service status"
    if run_ssh_command "sudo systemctl is-active headscale" | grep -q "active"; then
        print_pass
    else
        print_fail "Headscale service not running"
        return 1
    fi
}

test_headscale_port() {
    print_test "Headscale API accessibility (port 8080)"
    if curl -s --connect-timeout 5 "http://${SERVER_IP}:8080" &>/dev/null || \
       curl -s --connect-timeout 5 "http://${SERVER_IP}:8080/health" &>/dev/null; then
        print_pass
    else
        print_fail "Cannot connect to Headscale API"
        return 1
    fi
}

test_tailscale_installed() {
    print_test "Tailscale installation"
    if run_ssh_command "command -v tailscale" &>/dev/null; then
        print_pass
        
        # Get version
        version=$(run_ssh_command "tailscale version 2>/dev/null | head -n1" || echo "unknown")
        echo -e "    ${BLUE}Version: $version${NC}"
    else
        print_fail "Tailscale not installed"
        return 1
    fi
}

test_docker_installed() {
    print_test "Docker installation"
    if run_ssh_command "command -v docker" &>/dev/null; then
        print_pass
        
        # Get version
        version=$(run_ssh_command "docker --version" || echo "unknown")
        echo -e "    ${BLUE}$version${NC}"
    else
        print_fail "Docker not installed"
        return 1
    fi
}

test_adguard_installed() {
    print_test "AdGuard Home installation"
    if run_ssh_command "test -f /opt/AdGuardHome/AdGuardHome" &>/dev/null; then
        print_pass
    else
        print_fail "AdGuard Home not installed"
        return 1
    fi
}

test_adguard_service() {
    print_test "AdGuard Home service status"
    if run_ssh_command "sudo systemctl is-active adguardhome" | grep -q "active"; then
        print_pass
    else
        print_fail "AdGuard Home service not running"
        return 1
    fi
}

test_ip_forwarding() {
    print_test "IP forwarding enabled"
    ipv4=$(run_ssh_command "sysctl net.ipv4.ip_forward" | grep -oE '[0-9]+$')
    ipv6=$(run_ssh_command "sysctl net.ipv6.conf.all.forwarding" | grep -oE '[0-9]+$')
    
    if [[ "$ipv4" == "1" ]] && [[ "$ipv6" == "1" ]]; then
        print_pass
    else
        print_fail "IP forwarding not properly configured (IPv4: $ipv4, IPv6: $ipv6)"
        return 1
    fi
}

test_firewall() {
    print_test "UFW firewall status"
    if run_ssh_command "sudo ufw status" | grep -q "Status: active"; then
        print_pass
        
        # Show important rules
        echo -e "    ${BLUE}Firewall rules:${NC}"
        run_ssh_command "sudo ufw status numbered" | grep -E "(22/tcp|33003|8080|80|443)" | while read line; do
            echo -e "    ${BLUE}  $line${NC}"
        done
    else
        print_fail "Firewall not active"
        return 1
    fi
}

test_fail2ban() {
    print_test "fail2ban service"
    if run_ssh_command "sudo systemctl is-active fail2ban" | grep -q "active"; then
        print_pass
    else
        print_skip "fail2ban may not be installed or configured"
    fi
}

test_swap() {
    print_test "Swap space configured"
    swap=$(run_ssh_command "free -h | grep Swap | awk '{print \$2}'")
    
    if [[ "$swap" != "0B" ]] && [[ -n "$swap" ]]; then
        print_pass
        echo -e "    ${BLUE}Swap size: $swap${NC}"
    else
        print_fail "No swap configured"
        return 1
    fi
}

test_deploy_user() {
    print_test "Deploy user exists and has docker access"
    if run_ssh_command "groups | grep docker" &>/dev/null; then
        print_pass
    else
        print_fail "Deploy user not in docker group"
        return 1
    fi
}

test_nat_rules() {
    print_test "NAT masquerading rules"
    if run_ssh_command "sudo iptables -t nat -L POSTROUTING -v" | grep -q "MASQUERADE"; then
        print_pass
    else
        print_fail "NAT rules not configured"
        return 1
    fi
}

# Main test execution
main() {
    if [[ -z "$SERVER_IP" ]]; then
        show_usage
    fi
    
    print_header "🧪 Testing Headscale VPS Setup"
    echo "Server: ${SERVER_IP}:${SSH_PORT}"
    echo "User: ${SSH_USER}"
    echo ""
    
    # Run all tests
    test_connectivity || exit 1
    test_ssh_connection || exit 1
    
    print_header "📦 Software Installation"
    test_headscale_installed
    test_tailscale_installed
    test_docker_installed
    test_adguard_installed
    
    print_header "🔷 Headscale Service"
    test_headscale_service
    test_headscale_port
    
    print_header "🛡️  DNS Filtering (AdGuard Home)"
    test_adguard_service
    
    print_header "🌐 Network Configuration"
    test_ip_forwarding
    test_nat_rules
    
    print_header "🔒 Security"
    test_firewall
    test_fail2ban
    
    print_header "⚙️  System Configuration"
    test_swap
    test_deploy_user
    
    # Summary
    print_header "📊 Test Summary"
    echo ""
    echo "  Total Tests:  $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed:       $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ All tests passed! Your Headscale VPS is ready.${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Create a Headscale user:"
        echo "     ssh ${SSH_USER}@${SERVER_IP} -p ${SSH_PORT} sudo headscale users create myuser"
        echo ""
        echo "  2. Generate a pre-auth key:"
        echo "     ssh ${SSH_USER}@${SERVER_IP} -p ${SSH_PORT} sudo headscale preauthkeys create --user myuser --reusable"
        echo ""
        echo "  3. Connect the VPS as an exit node:"
        echo "     ssh ${SSH_USER}@${SERVER_IP} -p ${SSH_PORT} sudo tailscale up --login-server http://${SERVER_IP}:8080 --authkey YOUR_KEY --advertise-exit-node"
        echo ""
        exit 0
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ Some tests failed. Please review the errors above.${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        exit 1
    fi
}

main "$@"
