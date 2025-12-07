#!/bin/bash
#
# provision_vps.sh - Ubuntu VPS Provisioning Script for Headscale Exit Node
# Designed for Binary Lane (or any Ubuntu 22.04/24.04 LTS VPS)
#
# Usage:
#   bash provision_vps.sh --ssh-key="ssh-ed25519 AAAA..." --domain="robin-easy.bnr.la"
#
# See README.md for full documentation
#

set -euo pipefail

# Set TERM if not set (for non-interactive SSH sessions)
export TERM="${TERM:-dumb}"
export DEBIAN_FRONTEND=noninteractive

# Error handler
error_handler() {
    local line_no=$1
    local exit_code=$?
    {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ SCRIPT FAILED at line $line_no (exit code: $exit_code)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        [[ -f "$STATE_FILE" ]] && echo "Last completed steps are in: $STATE_FILE"
        echo "Check logs: journalctl -xe"
        echo ""
        echo "For support, provide:"
        echo "  1. This error output"
        echo "  2. Contents of $STATE_FILE"
        echo "  3. Output of: journalctl -xe | tail -50"
        echo ""
        echo "To debug, read the script around line $line_no"
        echo ""
    } >&2
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# Cleanup temporary files on exit
cleanup() {
    rm -f /tmp/get-docker.sh 2>/dev/null || true
    rm -f /tmp/headscale.deb 2>/dev/null || true
}
trap cleanup EXIT

#==============================================================================
# CONFIGURATION DEFAULTS
#==============================================================================

# User Configuration
DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_UID="${DEPLOY_UID:-1000}"
DEPLOY_PASSWORD=""  # Auto-generated if empty

# SSH Configuration
SSH_PORT="${SSH_PORT:-33003}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"

# Headscale Configuration
HEADSCALE_DOMAIN="${HEADSCALE_DOMAIN:-}"
HEADSCALE_PORT="${HEADSCALE_PORT:-8080}"
HEADSCALE_VERSION="${HEADSCALE_VERSION:-0.23.0}"

# Security - fail2ban
ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN:-true}"
FAIL2BAN_BANTIME="${FAIL2BAN_BANTIME:-86400}"  # 24 hours in seconds
FAIL2BAN_MAXRETRY="${FAIL2BAN_MAXRETRY:-5}"
FAIL2BAN_FINDTIME="${FAIL2BAN_FINDTIME:-600}"  # 10 minutes in seconds
FAIL2BAN_WHITELIST_URL="${FAIL2BAN_WHITELIST_URL:-https://gist.githubusercontent.com/turgs/6d471a01fa901146c0ed9e2138f7c902/raw/}"

# System Configuration
TIMEZONE="${TIMEZONE:-UTC}"
SWAP_SIZE="${SWAP_SIZE:-2G}"
ENABLE_UNATTENDED_UPGRADES="${ENABLE_UNATTENDED_UPGRADES:-true}"
ALLOW_AUTO_REBOOT="${ALLOW_AUTO_REBOOT:-false}"
AUTO_REBOOT="${AUTO_REBOOT:-true}"

# Docker
DOCKER_VERSION="${DOCKER_VERSION:-latest}"

#==============================================================================
# PARSE COMMAND LINE ARGUMENTS (overrides environment variables)
#==============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ssh-key=*)
                SSH_PUBLIC_KEY="${1#*=}"
                shift
                ;;
            --ssh-port=*)
                SSH_PORT="${1#*=}"
                shift
                ;;
            --domain=*)
                HEADSCALE_DOMAIN="${1#*=}"
                shift
                ;;
            --deploy-user=*)
                DEPLOY_USER="${1#*=}"
                shift
                ;;
            --swap-size=*)
                SWAP_SIZE="${1#*=}"
                shift
                ;;
            --fail2ban-whitelist-url=*)
                FAIL2BAN_WHITELIST_URL="${1#*=}"
                shift
                ;;
            --headscale-version=*)
                HEADSCALE_VERSION="${1#*=}"
                shift
                ;;
            --no-fail2ban)
                ENABLE_FAIL2BAN="false"
                shift
                ;;
            --no-reboot)
                AUTO_REBOOT="false"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat << 'EOF'
Usage: provision_vps.sh [OPTIONS]

Required:
  None - All parameters are optional!

Optional:
  --ssh-key=KEY              SSH public key for deploy user
  --ssh-port=PORT           SSH port (default: 33003)
  --domain=DOMAIN           Domain for Headscale server (e.g., headscale.example.com)
  --deploy-user=USER        Deploy username (default: deploy)
  --swap-size=SIZE          Swap size, e.g., 2G, 4G (default: 2G)
  --headscale-version=VER   Headscale version (default: 0.23.0)
  --fail2ban-whitelist-url=URL  Gist URL for IP whitelist
  --no-fail2ban             Disable fail2ban installation
  --no-reboot               Skip automatic reboot after provisioning
  --help, -h                Show this help message

Examples:
  # Minimal (uses defaults)
  bash provision_vps.sh

  # With custom SSH key
  bash provision_vps.sh --ssh-key="ssh-ed25519 AAAA..."

  # Full options
  bash provision_vps.sh \
    --ssh-key="ssh-ed25519 AAAA..." \
    --ssh-port=33003 \
    --domain="headscale.example.com" \
    --swap-size=4G

EOF
}

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

STATE_FILE="/root/.provision_state"

mark_complete() {
    echo "$1" >> "$STATE_FILE"
}

is_complete() {
    [[ -f "$STATE_FILE" ]] && grep -q "^$1\$" "$STATE_FILE" 2>/dev/null
}

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1"
}

print_warning() {
    echo "⚠️  $1"
}

#==============================================================================
# MAIN SCRIPT
#==============================================================================

main() {
    parse_args "$@"
    
    print_header "🚀 Starting VPS Provisioning for Headscale (Binary Lane)"
    
    print_info "Configuration:"
    print_info "  Deploy User: $DEPLOY_USER"
    print_info "  SSH Port: $SSH_PORT"
    print_info "  Headscale Version: $HEADSCALE_VERSION"
    [[ -n "$HEADSCALE_DOMAIN" ]] && print_info "  Domain: $HEADSCALE_DOMAIN"
    print_info "  Swap Size: $SWAP_SIZE"
    print_info "  fail2ban: $ENABLE_FAIL2BAN"
    echo ""
    
    # Pre-flight checks
    if [[ $EUID -ne 0 ]]; then
        echo "❌ This script must be run as root"
        exit 1
    fi
    
    # Update system
    if ! is_complete "system_update"; then
        print_header "📦 Updating System Packages"
        apt-get update -qq
        apt-get upgrade -y -qq
        mark_complete "system_update"
        print_success "System packages updated"
    else
        print_info "Skipping system update (already done)"
    fi
    
    # Install base packages
    if ! is_complete "base_packages"; then
        print_header "📦 Installing Base Packages"
        apt-get install -y -qq \
            curl \
            wget \
            git \
            vim \
            htop \
            ufw \
            fail2ban \
            unattended-upgrades \
            apt-transport-https \
            ca-certificates \
            software-properties-common \
            gnupg \
            lsb-release \
            sqlite3 \
            jq
        mark_complete "base_packages"
        print_success "Base packages installed"
    else
        print_info "Skipping base packages (already done)"
    fi
    
    # Configure timezone
    if ! is_complete "timezone"; then
        print_header "🕐 Setting Timezone"
        timedatectl set-timezone "$TIMEZONE"
        mark_complete "timezone"
        print_success "Timezone set to $TIMEZONE"
    else
        print_info "Skipping timezone (already done)"
    fi
    
    # Create swap
    if ! is_complete "swap"; then
        print_header "💾 Creating Swap Space"
        
        if [[ ! -f /swapfile ]]; then
            # Validate and parse swap size (e.g., 2G -> 2048M)
            if [[ ! "$SWAP_SIZE" =~ ^[0-9]+G$ ]]; then
                print_warning "Invalid swap size format: $SWAP_SIZE (expected format: 2G, 4G, etc.)"
                SWAP_SIZE="2G"
                print_info "Using default: $SWAP_SIZE"
            fi
            swap_mb=$(($(echo "$SWAP_SIZE" | sed 's/G//') * 1024))
            
            fallocate -l "${swap_mb}M" /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            
            # Make permanent
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
            fi
            
            # Optimize for containers
            sysctl vm.swappiness=10
            if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
                echo "vm.swappiness=10" >> /etc/sysctl.conf
            fi
            
            print_success "Swap space created: $SWAP_SIZE"
        else
            print_info "Swap file already exists"
        fi
        
        mark_complete "swap"
    else
        print_info "Skipping swap (already done)"
    fi
    
    # Create deploy user
    if ! is_complete "deploy_user"; then
        print_header "👤 Creating Deploy User"
        
        if ! id "$DEPLOY_USER" &>/dev/null; then
            useradd -m -u "$DEPLOY_UID" -s /bin/bash "$DEPLOY_USER"
            
            # Generate password if not provided
            if [[ -z "$DEPLOY_PASSWORD" ]]; then
                DEPLOY_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            fi
            
            echo "$DEPLOY_USER:$DEPLOY_PASSWORD" | chpasswd
            
            # Add to sudo group
            usermod -aG sudo "$DEPLOY_USER"
            
            print_success "Deploy user created: $DEPLOY_USER"
            print_info "Password: $DEPLOY_PASSWORD (save this!)"
        else
            print_info "Deploy user already exists"
        fi
        
        mark_complete "deploy_user"
    else
        print_info "Skipping deploy user (already done)"
    fi
    
    # Setup SSH keys
    if ! is_complete "ssh_keys"; then
        print_header "🔑 Setting Up SSH Keys"
        
        # Try to get SSH key from various sources
        if [[ -z "$SSH_PUBLIC_KEY" ]]; then
            # Try root's authorized_keys
            if [[ -f /root/.ssh/authorized_keys ]]; then
                SSH_PUBLIC_KEY=$(head -n 1 /root/.ssh/authorized_keys)
                print_info "Using SSH key from root's authorized_keys"
            # Try whitelist URL (WARNING: only use trusted sources)
            elif [[ -n "$FAIL2BAN_WHITELIST_URL" ]]; then
                print_warning "Fetching SSH key from external URL - ensure this is a trusted source!"
                SSH_PUBLIC_KEY=$(curl -fsSL "$FAIL2BAN_WHITELIST_URL" | grep "^ssh-" | head -n 1 || true)
                if [[ -n "$SSH_PUBLIC_KEY" ]]; then
                    print_info "Using SSH key from whitelist URL"
                    # Validate SSH key format using ssh-keygen if available
                    if command -v ssh-keygen &> /dev/null; then
                        # Write to temp file for validation
                        echo "$SSH_PUBLIC_KEY" > /tmp/test_key.pub
                        if ! ssh-keygen -l -f /tmp/test_key.pub &>/dev/null; then
                            print_warning "SSH key validation failed, skipping"
                            SSH_PUBLIC_KEY=""
                        fi
                        rm -f /tmp/test_key.pub
                    else
                        # Fallback to basic regex validation
                        if [[ ! "$SSH_PUBLIC_KEY" =~ ^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\ [A-Za-z0-9+/=]+(\s|$) ]]; then
                            print_warning "SSH key format looks suspicious, skipping"
                            SSH_PUBLIC_KEY=""
                        fi
                    fi
                fi
            fi
        fi
        
        if [[ -n "$SSH_PUBLIC_KEY" ]]; then
            # Setup for deploy user
            mkdir -p "/home/$DEPLOY_USER/.ssh"
            echo "$SSH_PUBLIC_KEY" > "/home/$DEPLOY_USER/.ssh/authorized_keys"
            chmod 700 "/home/$DEPLOY_USER/.ssh"
            chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys"
            chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
            
            print_success "SSH key configured for $DEPLOY_USER"
        else
            print_warning "No SSH key provided - password authentication will be required"
        fi
        
        mark_complete "ssh_keys"
    else
        print_info "Skipping SSH keys (already done)"
    fi
    
    # Install Docker
    if ! is_complete "docker"; then
        print_header "🐳 Installing Docker"
        
        if ! command -v docker &> /dev/null; then
            # Add Docker's official GPG key
            # Note: Using Docker's official apt repository with GPG signing
            # For maximum security, verify the fingerprint: 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            
            # Add the repository to Apt sources
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
              tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update -qq
            apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            
            # Add deploy user to docker group
            usermod -aG docker "$DEPLOY_USER"
            
            # Configure Docker logging
            mkdir -p /etc/docker
            cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
            systemctl restart docker
            
            print_success "Docker installed and configured"
        else
            print_info "Docker already installed"
        fi
        
        mark_complete "docker"
    else
        print_info "Skipping Docker (already done)"
    fi
    
    # Install AdGuard Home for DNS filtering
    if ! is_complete "adguard"; then
        print_header "🛡️  Installing AdGuard Home (DNS Filtering)"
        
        # Free up port 53 (disable systemd-resolved stub)
        print_info "Configuring DNS ports..."
        mkdir -p /etc/systemd/resolved.conf.d
        cat > /etc/systemd/resolved.conf.d/adguardhome.conf <<EOF
[Resolve]
DNS=127.0.0.1
DNSStubListener=no
EOF
        systemctl restart systemd-resolved
        
        # Create AdGuard Home directory
        mkdir -p /opt/adguardhome/work /opt/adguardhome/conf
        
        # Download and install AdGuard Home
        print_info "Downloading AdGuard Home..."
        ADGUARD_VERSION="v0.107.52"  # Latest stable version
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) ADGUARD_ARCH="amd64" ;;
            aarch64) ADGUARD_ARCH="arm64" ;;
            armv7l) ADGUARD_ARCH="armv7" ;;
            *) ADGUARD_ARCH="amd64" ;;
        esac
        
        wget -q "https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADGUARD_VERSION}/AdGuardHome_linux_${ADGUARD_ARCH}.tar.gz" \
            -O /tmp/adguard.tar.gz
        
        tar -xzf /tmp/adguard.tar.gz -C /opt/
        rm -f /tmp/adguard.tar.gz
        
        # Create initial configuration with RethinkDNS-style blocking
        print_info "Configuring AdGuard Home with ad/tracking/porn blocking..."
        cat > /opt/adguardhome/conf/AdGuardHome.yaml <<'ADGUARD_EOF'
bind_host: 127.0.0.1
bind_port: 3000
users:
  - name: admin
    password: $2a$10$Z5IqVj.qWzQ3Y8yCzXnW/OxQCKGHxW3wH0hKqL8RMH8kL5YbH4F/e  # changeme
dns:
  bind_hosts:
    - 127.0.0.1
  port: 53
  ratelimit: 0
  upstream_dns:
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  fallback_dns:
    - 1.0.0.1
  upstream_mode: load_balance
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: true
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: true
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  filtering_enabled: true
  filters_update_interval: 24
  parental_enabled: false
  safe_search:
    enabled: false
  safebrowsing_enabled: true
  safebrowsing_cache_size: 1048576
  safesearch_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  rewrites: []
  blocked_services:
    schedule:
      time_zone: UTC
    ids: []
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: https://big.oisd.nl/
    name: OISD Blocklist Big
    id: 3
  - enabled: true
    url: https://blocklistproject.github.io/Lists/porn.txt
    name: The Block List Project - Porn
    id: 4
  - enabled: true
    url: https://blocklistproject.github.io/Lists/tracking.txt
    name: The Block List Project - Tracking
    id: 5
  - enabled: true
    url: https://blocklistproject.github.io/Lists/malware.txt
    name: The Block List Project - Malware
    id: 6
whitelist_filters: []
user_rules:
  - '@@||youtube.com^$important'
  - '@@||googlevideo.com^$important'
  - '@@||ytimg.com^$important'
  - '@@||ggpht.com^$important'
dhcp:
  enabled: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 28
ADGUARD_EOF
        
        # Create systemd service
        cat > /etc/systemd/system/adguardhome.service <<'SYSTEMD_EOF'
[Unit]
Description=AdGuard Home DNS server
After=network.target
StartLimitIntervalSec=5
StartLimitBurst=10

[Service]
Type=simple
User=root
WorkingDirectory=/opt/AdGuardHome
ExecStart=/opt/AdGuardHome/AdGuardHome --no-check-update -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF
        
        # Enable and start AdGuard Home
        systemctl daemon-reload
        systemctl enable adguardhome
        systemctl start adguardhome
        
        # Wait for service to start
        sleep 3
        
        if systemctl is-active --quiet adguardhome; then
            print_success "AdGuard Home installed and started"
            print_info "Web UI: http://$(curl -s ifconfig.me):3000 (username: admin, password: changeme)"
            print_warning "IMPORTANT: Change the default password after setup!"
        else
            print_warning "AdGuard Home service failed to start"
            journalctl -u adguardhome -n 20
        fi
        
        mark_complete "adguard"
    else
        print_info "Skipping AdGuard Home (already done)"
    fi
    
    # Install Headscale
    if ! is_complete "headscale"; then
        print_header "🔷 Installing Headscale"
        
        if ! command -v headscale &> /dev/null; then
            # Detect architecture
            ARCH=$(dpkg --print-architecture)
            
            # Download Headscale
            print_info "Downloading Headscale v${HEADSCALE_VERSION}..."
            
            # Download package
            wget -q --show-progress \
                "https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_linux_${ARCH}.deb" \
                -O /tmp/headscale.deb
            
            # Download checksums for verification (if available)
            if wget -q "https://github.com/juanfont/headscale/releases/download/v${HEADSCALE_VERSION}/headscale_${HEADSCALE_VERSION}_checksums.txt" \
                -O /tmp/headscale_checksums.txt 2>/dev/null; then
                
                # Verify checksum if sha256sum is available in the checksums file
                expected_hash=$(grep "headscale_${HEADSCALE_VERSION}_linux_${ARCH}.deb" /tmp/headscale_checksums.txt | awk '{print $1}' || true)
                if [[ -n "$expected_hash" ]]; then
                    actual_hash=$(sha256sum /tmp/headscale.deb | awk '{print $1}')
                    if [[ "$actual_hash" == "$expected_hash" ]]; then
                        print_success "Checksum verified"
                    else
                        print_warning "Checksum verification failed! Proceeding anyway (manual verification recommended)"
                    fi
                fi
                rm -f /tmp/headscale_checksums.txt
            else
                print_warning "Checksums not available for verification"
            fi
            
            # Install
            apt-get install -y /tmp/headscale.deb
            rm -f /tmp/headscale.deb
            
            print_success "Headscale installed"
        else
            print_info "Headscale already installed"
        fi
        
        # Configure Headscale
        print_info "Configuring Headscale..."
        
        # Create config directory
        mkdir -p /etc/headscale
        
        # Determine server URL based on domain
        if [[ -n "$HEADSCALE_DOMAIN" ]]; then
            SERVER_URL="https://${HEADSCALE_DOMAIN}"
        else
            # Use server's public IP
            SERVER_IP=$(curl -s ifconfig.me || echo "0.0.0.0")
            SERVER_URL="http://${SERVER_IP}:${HEADSCALE_PORT}"
        fi
        
        # Create ACL policy file
        cat > /etc/headscale/acl.yaml <<'ACLEOF'
# Headscale ACL Policy
# This file controls access between nodes in your network
# Edit this file and run 'sudo systemctl reload headscale' to apply changes

# ACLs define which users can access which resources
acls:
  # Allow all users to access their own devices
  - action: accept
    src:
      - "*"
    dst:
      - "*:*"

# Groups can be defined to manage users together
groups:
  group:admins:
    - admin

# TagOwners define who can apply tags to nodes
tagOwners:
  tag:exit-node:
    - group:admins

# SSH access control (optional)
ssh:
  - action: accept
    src:
      - "*"
    dst:
      - "*"
    users:
      - autogroup:nonroot
      - root

# Host definitions for easy reference
hosts: {}

# Auto-approvers for exit nodes
autoApprovers:
  routes:
    0.0.0.0/0:
      - tag:exit-node
    "::/0":
      - tag:exit-node
ACLEOF
        
        # Create config file
        cat > /etc/headscale/config.yaml <<EOF
server_url: ${SERVER_URL}
listen_addr: 127.0.0.1:${HEADSCALE_PORT}
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key

ip_prefixes:
  - fd7a:115c:a1e0::/48
  - 100.64.0.0/10

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
database:
  type: sqlite3
  sqlite:
    path: /var/lib/headscale/db.sqlite

# ACL policy file for access control
policy:
  path: /etc/headscale/acl.yaml

acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
tls_cert_path: ""
tls_key_path: ""

log:
  format: text
  level: info

dns_config:
  override_local_dns: true
  nameservers:
    # AdGuard Home running on localhost (installed by this script)
    # Provides ad/tracking/porn blocking with custom allow/deny lists
    - 127.0.0.1
  domains: []
  magic_dns: true
  base_domain: headscale.net

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
EOF

        # Create data directory
        mkdir -p /var/lib/headscale
        
        # Enable and start Headscale
        systemctl enable headscale
        systemctl restart headscale
        
        # Wait for service to start
        sleep 3
        
        if systemctl is-active --quiet headscale; then
            print_success "Headscale configured and started"
            print_info "Server URL: $SERVER_URL"
        else
            print_warning "Headscale service failed to start"
            journalctl -u headscale -n 20
        fi
        
        mark_complete "headscale"
    else
        print_info "Skipping Headscale (already done)"
    fi
    
    # Install Caddy (reverse proxy for HTTPS)
    if ! is_complete "caddy"; then
        print_header "🔒 Installing Caddy (HTTPS Reverse Proxy)"
        
        if ! command -v caddy &> /dev/null; then
            # Add Caddy's official repository
            print_info "Adding Caddy repository..."
            apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
                gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
                tee /etc/apt/sources.list.d/caddy-stable.list
            
            apt-get update -qq
            apt-get install -y -qq caddy
            
            print_success "Caddy installed"
        else
            print_info "Caddy already installed"
        fi
        
        # Configure Caddy if domain is provided
        if [[ -n "$HEADSCALE_DOMAIN" ]]; then
            print_info "Configuring Caddy for HTTPS with domain: $HEADSCALE_DOMAIN"
            
            # Create Caddyfile
            cat > /etc/caddy/Caddyfile <<CADDYEOF
# Caddy configuration for Headscale
# Automatic HTTPS with Let's Encrypt

${HEADSCALE_DOMAIN} {
    # Reverse proxy to Headscale
    reverse_proxy 127.0.0.1:${HEADSCALE_PORT} {
        # Preserve headers for Headscale
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Enable compression
    encode gzip
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent clickjacking
        X-Frame-Options "DENY"
        # Prevent content-type sniffing
        X-Content-Type-Options "nosniff"
        # Remove server header
        -Server
    }
    
    # Access logging
    log {
        output file /var/log/caddy/headscale-access.log
        format json
    }
}
CADDYEOF
            
            # Create log directory
            mkdir -p /var/log/caddy
            chown caddy:caddy /var/log/caddy
            
            # Reload Caddy
            systemctl enable caddy
            systemctl restart caddy
            
            # Wait for Caddy to start
            sleep 3
            
            if systemctl is-active --quiet caddy; then
                print_success "Caddy configured with HTTPS for $HEADSCALE_DOMAIN"
                print_info "Caddy will automatically obtain Let's Encrypt certificate"
                print_warning "Ensure DNS A record for $HEADSCALE_DOMAIN points to this server!"
            else
                print_warning "Caddy service failed to start"
                journalctl -u caddy -n 20
            fi
        else
            print_info "No domain provided, skipping Caddy configuration"
            print_info "Headscale will use HTTP on port $HEADSCALE_PORT"
        fi
        
        mark_complete "caddy"
    else
        print_info "Skipping Caddy (already done)"
    fi
    
    # Install Tailscale (for exit node)
    if ! is_complete "tailscale"; then
        print_header "🌐 Installing Tailscale"
        
        if ! command -v tailscale &> /dev/null; then
            # Add Tailscale's official repository
            # Using Tailscale's official apt repository with GPG signing
            print_info "Adding Tailscale repository..."
            curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | \
                tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
            curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list | \
                tee /etc/apt/sources.list.d/tailscale.list
            
            apt-get update -qq
            apt-get install -y -qq tailscale
            
            print_success "Tailscale installed"
        else
            print_info "Tailscale already installed"
        fi
        
        mark_complete "tailscale"
    else
        print_info "Skipping Tailscale (already done)"
    fi
    
    # Enable IP forwarding for exit node
    if ! is_complete "ip_forwarding"; then
        print_header "🔀 Enabling IP Forwarding"
        
        # Enable IPv4 forwarding
        sysctl -w net.ipv4.ip_forward=1
        sysctl -w net.ipv6.conf.all.forwarding=1
        
        # Make permanent
        cat > /etc/sysctl.d/99-headscale.conf <<EOF
# IP Forwarding for Headscale exit node
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1

# Network tuning
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.inotify.max_user_watches=524288
EOF
        sysctl -p /etc/sysctl.d/99-headscale.conf
        
        print_success "IP forwarding enabled"
        
        mark_complete "ip_forwarding"
    else
        print_info "Skipping IP forwarding (already done)"
    fi
    
    # Configure NAT/iptables for exit node
    if ! is_complete "nat_rules"; then
        print_header "🔥 Configuring NAT Rules"
        
        # Get primary network interface
        PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        
        # Add NAT masquerading rule
        if ! iptables -t nat -C POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE 2>/dev/null; then
            iptables -t nat -A POSTROUTING -o "$PRIMARY_IFACE" -j MASQUERADE
            print_success "NAT masquerading configured on $PRIMARY_IFACE"
        else
            print_info "NAT rule already exists"
        fi
        
        # Save iptables rules
        apt-get install -y -qq iptables-persistent
        netfilter-persistent save
        
        mark_complete "nat_rules"
    else
        print_info "Skipping NAT rules (already done)"
    fi
    
    # Configure SSH
    if ! is_complete "ssh_config"; then
        print_header "🔒 Configuring SSH"
        
        # Backup original config
        if [[ ! -f /etc/ssh/sshd_config.bak ]]; then
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        fi
        
        # Configure SSH settings
        cat > /etc/ssh/sshd_config.d/99-custom.conf <<EOF
# Custom SSH configuration for Headscale VPS

Port ${SSH_PORT}

# Root login with password (emergency access)
PermitRootLogin yes

# Deploy user: key-only authentication
Match User ${DEPLOY_USER}
    PubkeyAuthentication yes
    PasswordAuthentication no

# Connection keep-alive
ClientAliveInterval 60
ClientAliveCountMax 3

# Security
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30
EOF

        # Test SSH config
        sshd -t
        
        # Restart SSH (careful!)
        systemctl restart sshd
        
        print_success "SSH configured on port $SSH_PORT"
        print_warning "Make sure to test SSH on new port before closing this session!"
        
        mark_complete "ssh_config"
    else
        print_info "Skipping SSH config (already done)"
    fi
    
    # Configure UFW firewall
    if ! is_complete "firewall"; then
        print_header "🛡️  Configuring Firewall"
        
        # Reset UFW to default
        ufw --force reset
        
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH
        ufw allow "$SSH_PORT"/tcp comment 'SSH'
        
        # Allow HTTP/HTTPS (for Caddy/Let's Encrypt)
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        
        # Allow Headscale port only if not using domain (no Caddy proxy)
        if [[ -z "$HEADSCALE_DOMAIN" ]]; then
            ufw allow "$HEADSCALE_PORT"/tcp comment 'Headscale'
            print_info "Headscale port $HEADSCALE_PORT opened (direct access)"
        else
            print_info "Headscale port $HEADSCALE_PORT not opened (using Caddy proxy)"
        fi
        
        # Allow AdGuard Home Web UI
        ufw allow 3000/tcp comment 'AdGuard Home UI'
        
        # Allow Tailscale DERP
        ufw allow 3478/udp comment 'Tailscale STUN'
        ufw allow 41641/udp comment 'Tailscale'
        
        # Enable UFW
        ufw --force enable
        
        print_success "Firewall configured and enabled"
        ufw status
        
        mark_complete "firewall"
    else
        print_info "Skipping firewall (already done)"
    fi
    
    # Configure fail2ban
    if [[ "$ENABLE_FAIL2BAN" == "true" ]] && ! is_complete "fail2ban"; then
        print_header "🚫 Configuring fail2ban"
        
        # Create local jail configuration
        cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = ${FAIL2BAN_BANTIME}
findtime = ${FAIL2BAN_FINDTIME}
maxretry = ${FAIL2BAN_MAXRETRY}

[sshd]
enabled = true
port    = ${SSH_PORT}
logpath = /var/log/auth.log
EOF

        # Create whitelist update script if URL provided
        if [[ -n "$FAIL2BAN_WHITELIST_URL" ]]; then
            print_warning "Using external whitelist URL - ensure this is a trusted source!"
            cat > /usr/local/bin/update-fail2ban-whitelist.sh <<'EOFSCRIPT'
#!/bin/bash
# Security note: Only use this with trusted whitelist sources
# Fetching IPs from untrusted sources could allow attackers to bypass fail2ban

WHITELIST_URL="${1}"
WHITELIST_FILE="/etc/fail2ban/jail.d/00-whitelist.conf"

if [[ -z "$WHITELIST_URL" ]]; then
    exit 0
fi

# Fetch whitelist IPs with timeout and validation
IPS=$(timeout 10 curl -fsSL "$WHITELIST_URL" 2>/dev/null | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort -u)

# Validate IPs - basic sanity check
if [[ -z "$IPS" ]]; then
    # Keep existing whitelist if fetch fails
    exit 0
fi

# Additional validation: ensure IPs are reasonable
VALID_IPS=""
while IFS= read -r ip; do
    # Validate IP format and octets (0-255)
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Check each octet is 0-255
        valid=true
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                valid=false
                break
            fi
        done
        if [[ "$valid" == "true" ]]; then
            VALID_IPS="${VALID_IPS}${ip}"$'\n'
        fi
    fi
done <<< "$IPS"

if [[ -z "$VALID_IPS" ]]; then
    exit 0
fi

# Create whitelist config
cat > "$WHITELIST_FILE" <<EOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
$(echo "$VALID_IPS" | awk '{print "           " $0}')
EOF

# Reload fail2ban
systemctl reload fail2ban 2>/dev/null || true
EOFSCRIPT
            chmod +x /usr/local/bin/update-fail2ban-whitelist.sh
            
            # Initial run
            /usr/local/bin/update-fail2ban-whitelist.sh "$FAIL2BAN_WHITELIST_URL"
            
            # Setup cron job for hourly updates
            (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/update-fail2ban-whitelist.sh '$FAIL2BAN_WHITELIST_URL'") | crontab -
            
            print_info "fail2ban whitelist updates configured (verify whitelist source is trusted!)"
        fi
        
        # Enable and start fail2ban
        systemctl enable fail2ban
        systemctl restart fail2ban
        
        print_success "fail2ban configured and started"
        
        mark_complete "fail2ban"
    else
        if [[ "$ENABLE_FAIL2BAN" != "true" ]]; then
            print_info "Skipping fail2ban (disabled)"
        else
            print_info "Skipping fail2ban (already done)"
        fi
    fi
    
    # Configure unattended upgrades
    if [[ "$ENABLE_UNATTENDED_UPGRADES" == "true" ]] && ! is_complete "unattended_upgrades"; then
        print_header "🔄 Configuring Unattended Upgrades"
        
        cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "${ALLOW_AUTO_REBOOT}";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF

        cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

        systemctl enable unattended-upgrades
        systemctl restart unattended-upgrades
        
        print_success "Unattended upgrades configured"
        
        mark_complete "unattended_upgrades"
    else
        print_info "Skipping unattended upgrades"
    fi
    
    # Final summary
    print_header "✅ Provisioning Complete!"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 IMPORTANT INFORMATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔑 Deploy User: $DEPLOY_USER"
    if [[ -n "$DEPLOY_PASSWORD" ]]; then
        echo "🔒 Deploy Password: $DEPLOY_PASSWORD"
    fi
    echo ""
    echo "🌐 SSH Access:"
    echo "   ssh $DEPLOY_USER@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
    echo ""
    echo "🔷 Headscale:"
    if [[ -n "$HEADSCALE_DOMAIN" ]]; then
        echo "   Server URL: http://${HEADSCALE_DOMAIN}:${HEADSCALE_PORT}"
    else
        echo "   Server URL: http://$(curl -s ifconfig.me):${HEADSCALE_PORT}"
    fi
    echo ""
    echo "📝 Next Steps:"
    echo "   1. Test SSH on port $SSH_PORT BEFORE closing this session"
    echo "   2. ⚠️  CHANGE ADGUARD HOME PASSWORD at http://$(curl -s ifconfig.me):3000"
    echo "      (Login: admin / changeme) - DO THIS IMMEDIATELY!"
    echo "   3. Create Headscale user: sudo headscale users create myuser"
    echo "   4. Generate pre-auth key: sudo headscale preauthkeys create --user myuser --reusable"
    echo "   5. Configure VPS as exit node (see README.md)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ "$AUTO_REBOOT" == "true" ]]; then
        print_warning "System will reboot in 10 seconds..."
        echo "Press Ctrl+C to cancel reboot"
        sleep 10
        
        print_info "Rebooting system..."
        reboot
    else
        print_info "Reboot skipped (use --no-reboot flag)"
        print_warning "Manual reboot recommended to apply all changes"
    fi
}

# Run main function
main "$@"
