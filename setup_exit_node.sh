#!/bin/bash
#
# setup_exit_node.sh - Helper script to configure VPS as Headscale exit node
#
# Run this script on the VPS after provision_vps.sh completes
#
# Usage:
#   bash setup_exit_node.sh
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

main() {
    print_header "🌐 Setting up Headscale Exit Node"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo "This script needs sudo privileges for some commands."
        echo "You may be prompted for your password."
        echo ""
    fi
    
    # Step 1: Check Headscale is running
    print_info "Checking Headscale service..."
    if sudo systemctl is-active --quiet headscale; then
        print_success "Headscale service is running"
    else
        print_warning "Headscale service is not running. Starting it..."
        sudo systemctl start headscale
        sleep 2
    fi
    
    # Step 2: List existing users
    print_header "📋 Existing Headscale Users"
    if sudo headscale users list 2>/dev/null | grep -q "No users"; then
        print_info "No users found. You need to create one."
        echo ""
        read -p "Enter username to create (e.g., myuser): " username
        
        if [[ -n "$username" ]]; then
            sudo headscale users create "$username"
            print_success "User '$username' created"
        else
            print_warning "No username provided. Skipping user creation."
            username=""
        fi
    else
        sudo headscale users list
        echo ""
        read -p "Enter username to use (or press Enter to create new): " username
        
        if [[ -z "$username" ]]; then
            read -p "Enter new username: " new_username
            if [[ -n "$new_username" ]]; then
                sudo headscale users create "$new_username"
                username="$new_username"
                print_success "User '$username' created"
            fi
        fi
    fi
    
    # Step 3: Generate pre-auth key
    if [[ -n "$username" ]]; then
        print_header "🔑 Generating Pre-Auth Key"
        
        print_info "Generating reusable pre-auth key..."
        PREAUTH_KEY=$(sudo headscale preauthkeys create --user "$username" --reusable --expiration 24h 2>&1 | grep -oE '[a-f0-9]{64}' || true)
        
        if [[ -n "$PREAUTH_KEY" ]]; then
            print_success "Pre-auth key generated"
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Your Pre-Auth Key (save this!):${NC}"
            echo ""
            echo -e "${YELLOW}$PREAUTH_KEY${NC}"
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
        else
            print_warning "Failed to generate pre-auth key. Try manually:"
            echo "  sudo headscale preauthkeys create --user $username --reusable --expiration 24h"
        fi
    fi
    
    # Step 4: Connect VPS as exit node
    print_header "🚀 Connecting VPS as Exit Node"
    
    # Get server URL from Headscale config
    SERVER_URL=$(sudo grep "server_url:" /etc/headscale/config.yaml | awk '{print $2}' || echo "")
    
    if [[ -z "$SERVER_URL" ]]; then
        # Fallback to localhost
        SERVER_URL="http://127.0.0.1:8080"
    fi
    
    print_info "Server URL: $SERVER_URL"
    
    # Check if Tailscale is already connected
    if sudo tailscale status &>/dev/null; then
        print_warning "Tailscale is already connected"
        sudo tailscale status
        echo ""
        read -p "Do you want to reconnect? (y/N): " reconnect
        if [[ "$reconnect" != "y" && "$reconnect" != "Y" ]]; then
            print_info "Keeping existing connection"
        else
            sudo tailscale down
        fi
    fi
    
    # Connect if key is available
    if [[ -n "${PREAUTH_KEY:-}" ]]; then
        print_info "Connecting to Headscale as exit node..."
        
        if sudo tailscale up --login-server="$SERVER_URL" --authkey="$PREAUTH_KEY" --advertise-exit-node --accept-routes; then
            print_success "VPS connected as exit node!"
            echo ""
            sudo tailscale status
        else
            print_warning "Failed to connect. Try manually:"
            echo "  sudo tailscale up --login-server=$SERVER_URL --authkey=YOUR_KEY --advertise-exit-node"
        fi
    else
        print_info "To connect manually, run:"
        echo ""
        echo "  sudo tailscale up --login-server=$SERVER_URL --authkey=YOUR_KEY --advertise-exit-node"
        echo ""
    fi
    
    # Step 5: Approve exit node (if needed)
    print_header "✅ Final Steps"
    
    print_info "To approve this VPS as an exit node, run:"
    echo ""
    echo "  sudo headscale routes list"
    echo "  sudo headscale routes enable -r <route-id>"
    echo ""
    
    print_info "To connect client devices:"
    echo ""
    echo "  1. Install Tailscale on your device"
    echo "  2. Connect: sudo tailscale up --login-server=$SERVER_URL"
    echo "  3. Use exit node: sudo tailscale set --exit-node <vps-hostname>"
    echo ""
    
    print_success "Setup complete!"
}

main "$@"
