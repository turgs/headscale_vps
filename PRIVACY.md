# Privacy & Security Guide for Headscale VPN

This document provides an honest, non-hyperbolic assessment of what this Headscale VPN setup can and cannot do for your privacy and security.

---

## 🎯 What This VPN Actually Does

### ✅ What It DOES Protect Against

1. **Local Network Surveillance**
   - Prevents coffee shop/hotel WiFi operators from seeing your unencrypted traffic
   - Protects against local network attackers (Man-in-the-Middle on public WiFi)
   - Hides your browsing from others on the same local network

2. **ISP-Level Visibility**
   - Your home/mobile ISP cannot see what websites you visit (only that you're connected to your VPS)
   - Your ISP cannot inject ads or tracking into your traffic
   - Your ISP cannot throttle specific services (they only see encrypted VPN traffic)

3. **Geo-Location Bypass**
   - Your traffic appears to originate from your VPS location
   - Can access region-restricted content if VPS is in the right location
   - Useful for accessing services while traveling

4. **Basic Content Filtering**
   - Built-in AdGuard Home blocks ads, trackers, and malicious domains
   - DNS-level filtering prevents family members from accessing adult content
   - Reduces tracking across devices

### ❌ What It DOES NOT Protect Against

1. **VPS Provider Visibility**
   - Your VPS provider (HostHatch, Vultr, etc.) can see ALL your traffic
   - They know your real IP address (you paid them with your payment method)
   - They can be compelled to log or hand over data by law enforcement
   - **This is not anonymous**

2. **HTTPS Content**
   - VPN cannot see inside HTTPS connections (neither can ISP or VPS provider without MITM)
   - Website operators still know you visited them (though from VPS IP, not yours)
   - Login credentials, cookies, and browser fingerprinting still identify you

3. **Government-Level Surveillance**
   - Advanced traffic analysis can identify VPN usage patterns
   - State-level actors can correlate traffic at entry and exit points
   - Not suitable for protecting against targeted government surveillance

4. **Application-Level Tracking**
   - Apps and websites can still track you via cookies, accounts, fingerprinting
   - Google/Facebook/etc. still know who you are when you log in
   - Device identifiers (advertising IDs) still track you

---

## 🌍 VPS Provider & Location Considerations

### Recommended Providers

Both **HostHatch** and **Vultr** are reasonable choices for this use case:

#### HostHatch
- ✅ Good bandwidth (1 Gbps typical)
- ✅ Affordable pricing
- ✅ Multiple global locations
- ⚠️ Some locations may be in Five Eyes countries (see below)
- ⚠️ Smaller company = potentially less legal resistance to data requests

#### Vultr
- ✅ More established provider with global presence
- ✅ Good performance and uptime
- ✅ More locations to choose from
- ⚠️ US-based company (subject to US legal jurisdiction)
- ⚠️ Potentially more expensive

### Location Selection: Japan vs Singapore vs Others

**For Speed:**
- Choose the location **geographically closest** to your actual location
- Japan: Good for East Asia, Australia, West Coast US
- Singapore: Good for Southeast Asia, India, Australia
- Europe: Good for Europe, Middle East, Africa
- US East: Good for Americas, Europe

**For Privacy:**
Neither Japan nor Singapore are part of Five Eyes, but both have their own surveillance frameworks:

- **Japan**: Not in Five Eyes, but has intelligence sharing agreements with US
- **Singapore**: Not in Five Eyes, but has strict cybersecurity laws and government oversight
- **Switzerland**: Often recommended for privacy (not in Five Eyes, strong privacy laws)
- **Iceland**: Strong privacy laws, minimal surveillance agreements
- **Romania**: Outside major surveillance alliances, good privacy laws

**Reality Check:**
- For family use and basic privacy, location matters less than you might think
- Your VPS provider can be compelled by law regardless of location
- If avoiding government surveillance is critical, a single VPN is insufficient

### Five Eyes Jurisdictions

**Five Eyes Countries (Strongest Intelligence Sharing):**
- United States
- United Kingdom
- Canada
- Australia
- New Zealand

**Nine Eyes (adds):**
- Denmark
- France
- Netherlands
- Norway

**Fourteen Eyes (adds):**
- Germany
- Belgium
- Italy
- Spain
- Sweden

**What This Means:**
- VPS in these countries may have data more easily shared with member intelligence agencies
- However, legal data requests can reach ANY country via mutual legal assistance treaties (MLATs)
- For casual privacy, this is not a major concern
- For high-security needs, a VPN alone is insufficient regardless of jurisdiction

---

## 🚫 Censorship & Deep Packet Inspection

### Can This Bypass Government Censorship?

**Maybe, but not reliably:**

1. **Basic DNS Blocking**: ✅ **Yes, bypasses this**
   - If your government blocks sites via DNS (like some ISPs), this VPN helps
   - Your traffic uses VPS's DNS (AdGuard Home), not censored DNS

2. **IP Address Blocking**: ✅ **Yes, bypasses this**
   - If specific IPs are blocked, routing through VPS hides your destination

3. **Deep Packet Inspection (DPI)**: ⚠️ **Partially, with limitations**
   - WireGuard (Tailscale's protocol) traffic looks relatively normal
   - It uses UDP and can be mistaken for other UDP traffic
   - However, WireGuard has identifiable packet patterns
   - Sophisticated DPI can detect and block WireGuard specifically

4. **Advanced Censorship**: ❌ **No, not effective**
   - China's Great Firewall can detect and block WireGuard
   - Some countries actively probe and fingerprint VPN protocols
   - If your government is actively hostile to VPNs, this is not sufficient

### Does Traffic Look Like Normal HTTPS?

**No**, WireGuard/Tailscale traffic is UDP-based and does NOT look like HTTPS:

- HTTPS is TCP-based on port 443
- WireGuard is UDP-based (typically port 41641, but configurable)
- Packet timing and size patterns are different
- DPI can distinguish VPN traffic from regular HTTPS

**To appear like HTTPS**, you'd need:
- A tunnel-over-HTTPS solution (like V2Ray, Shadowsocks, or Obfuscation plugins)
- More complexity and potential performance overhead
- **This setup does NOT provide this**

---

## ⚠️ Single VPN Usage Risks

### Is Using One VPN 100% of the Time Risky?

**Yes, there are some risks and trade-offs:**

1. **Behavioral Pattern Detection**
   - If all your traffic always goes through one IP, it's an identifiable pattern
   - Websites might flag or block VPN IPs
   - Your VPS IP could get blacklisted by services detecting datacenter IPs

2. **Single Point of Failure**
   - If your VPS goes down, your entire family loses internet
   - If VPS provider has an outage, everyone is affected
   - VPS compromise exposes all family traffic

3. **Performance Bottleneck**
   - All traffic limited by VPS bandwidth
   - Added latency for all connections
   - Can slow down video calls, gaming, streaming

4. **Service Blocks**
   - Netflix, Hulu, banking apps may block datacenter IPs
   - Some services detect and prevent VPN usage
   - May require whitelisting or split tunneling

### 10 Family Members Using This 100% of the Time

**Considerations for family deployment:**

1. **Bandwidth**: 
   - 10 users with 1 Gbps VPS = ~100 Mbps per user (theoretical)
   - Practical throughput will be less
   - Fine for browsing, may struggle with multiple 4K streams

2. **Detectability**:
   - Large consistent data volume from one IP is unusual
   - Pattern analysis could identify this as a VPN or proxy
   - However, for casual usage this is not a major concern

3. **Attribution**:
   - If one family member's activity draws attention, ALL users' traffic may be examined
   - VPS provider knows your identity (payment, contact info)
   - Not suitable if any family member has high-risk activities

4. **Practical Recommendation**:
   - ✅ Good for: Ad blocking, basic privacy, parental controls, geo-unblocking
   - ⚠️ Consider split-tunneling for: Gaming, video calls, local services
   - ❌ Not suitable for: Anonymity, avoiding state-level surveillance, high-risk activities

---

## 🛡️ Recommendations to Improve Security Posture

While the basic setup is secure, here are additional steps to enhance security:

### 1. Enable HTTPS for Headscale (Recommended)

The default setup uses HTTP (port 8080), which exposes your control plane traffic:

```bash
# Option A: Use Caddy reverse proxy (easiest)
sudo apt install -y caddy

# Create Caddyfile
sudo tee /etc/caddy/Caddyfile <<EOF
your-domain.com {
    reverse_proxy localhost:8080
}
EOF

sudo systemctl restart caddy
```

**Why**: Encrypts your control server connections, prevents MITM attacks on client authentication

### 2. Use Domain Name Instead of IP

Instead of `http://YOUR_IP:8080`, use a proper domain:

- Enables HTTPS with valid certificates
- Looks less suspicious (no bare IP addresses)
- Allows certificate pinning for additional security

### 3. Implement Access Control Lists (ACLs)

By default, all Headscale nodes can see each other. Restrict this:

```bash
sudo nano /etc/headscale/config.yaml
```

Add ACL policy to the config file to restrict inter-node communication.

**Important**: ACL configuration is complex and security-critical. See official documentation: https://headscale.net/ref/acls/

Example to restrict peer-to-peer communication (only allow internet access):
```yaml
# First define groups in the config
groups:
  group:family:
    - user1
    - user2

# Define tags (tags are applied to nodes)
tagOwners:
  tag:exit-node:
    - user1

# Then define ACL rules
acls:
  - action: accept
    src: ["group:family"]
    dst: ["autogroup:internet:*"]  # autogroup:internet allows internet access
  - action: accept
    src: ["tag:exit-node"]
    dst: ["*:*"]
```

Note: Replace `user1`, `user2` with your actual Headscale users created via `headscale users create <username>`

**Why**: Limits damage if one device is compromised

### 4. Regular Security Updates

```bash
# Setup automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Why**: Keeps your VPS protected against known vulnerabilities

### 5. Enable Audit Logging

```bash
# View Headscale logs in real-time
sudo journalctl -u headscale -f

# Configure log retention in journald
sudo nano /etc/systemd/journald.conf
# Uncomment and set: SystemMaxUse=500M
# Then restart: sudo systemctl restart systemd-journald
```

For more detailed logging, edit Headscale config:
```bash
sudo nano /etc/headscale/config.yaml
```

Add or modify the log section:
```yaml
log:
  level: info  # Options: trace, debug, info, warn, error
  format: text # Options: json, text
```

Then restart Headscale: `sudo systemctl restart headscale`

**Why**: Helps detect suspicious activity or compromise

### 6. Implement Rate Limiting

Configure firewall rules to limit connection attempts:

```bash
# Limit incoming connections to prevent DDoS
sudo ufw limit 8080/tcp
sudo ufw limit 33003/tcp
```

**Why**: Prevents brute force and DoS attacks

### 7. Monitor VPS Resource Usage

Set up alerts for unusual patterns:
- Sudden bandwidth spikes
- Unusual connection patterns
- High CPU usage (potential cryptomining)

**Why**: Early detection of compromise or abuse

### 8. Use Strong Pre-Auth Keys

```bash
# First, ensure you have a Headscale user created:
# sudo headscale users create myuser

# Generate short-lived, non-reusable keys when possible
# Replace 'myuser' with your actual Headscale username
sudo headscale preauthkeys create --user myuser --expiration 1h

# Don't use --reusable for production
# For one-time device registration, omit --reusable flag
```

**Why**: Limits exposure if a key is leaked

### 9. Consider Split Tunneling

Don't route ALL traffic through VPN:

```bash
# On clients, exclude local traffic and trusted services
# Run 'tailscale status' to see your VPS node name (not IP address)
# Use the node name shown there (e.g., 'vps-hostname' or 'ubuntu-server')
# Example: tailscale up --exit-node=my-vps-hostname --exit-node-allow-lan-access

tailscale up --exit-node=YOUR_VPS_NODE_NAME --exit-node-allow-lan-access

# Or use route-based policies to exclude specific subnets
```

**Why**: Reduces exposure, improves performance, decreases suspicion

### 10. Backup Configuration Regularly

```bash
# Backup Headscale data
sudo tar -czf headscale-backup-$(date +%Y%m%d).tar.gz \
  /etc/headscale/ \
  /var/lib/headscale/

# Store backups off-VPS
```

**Why**: Enables quick recovery if VPS is compromised or lost

---

## 🔍 Threat Model Assessment

Before deploying, honestly assess your threat model:

### Low Threat (Casual Privacy)
**Use Case**: Avoid ISP tracking, block ads, parental controls, public WiFi protection

**This Setup**: ✅ **Appropriate**
- Sufficient for keeping browsing private from local networks and ISP
- Good for content filtering for family
- Adequate for accessing geo-blocked content

**Additional Needs**: None, you're good

### Medium Threat (Journalism, Activism, Business)
**Use Case**: Protect sensitive communications, avoid targeted surveillance, business confidentiality

**This Setup**: ⚠️ **Insufficient Alone**
- Single VPN provides limited protection
- VPS provider is a weak point
- No anonymity layer

**Additional Needs**:
- Use Tor for anonymity-critical activities
- End-to-end encrypted messaging (Signal, etc.)
- Consider VPN chains or multi-hop setups
- Use separate device for sensitive activities

### High Threat (State-Level Adversaries)
**Use Case**: Political dissidence, whistleblowing, investigative journalism in hostile countries

**This Setup**: ❌ **Not Suitable**
- Single VPS is easily traced to you
- Traffic analysis can defeat simple VPNs
- No protection against targeted surveillance

**Use Instead**:
- Tor Browser for anonymity
- Tails OS for secure computing
- Air-gapped devices for sensitive data
- Professional security consultation

---

## 📊 Real-World Privacy Summary

**For the family use case described (10 users, daily use):**

✅ **You ARE protected from:**
- Local network snooping (coffee shops, hotels, etc.)
- ISP tracking your browsing habits
- ISP throttling specific services
- Basic content you don't want family accessing (via AdGuard Home)
- Some geo-restrictions

⚠️ **You are PARTIALLY protected from:**
- Websites knowing your real IP (they see VPS IP, but can still track you via cookies/accounts)
- Censorship (depends on sophistication of censorship)
- Traffic pattern analysis (requires advanced adversaries)

❌ **You are NOT protected from:**
- Your VPS provider seeing your traffic
- Government requests to your VPS provider
- Advanced traffic analysis and correlation attacks
- Application-level tracking (Google, Facebook, etc. still track you)
- Targeted surveillance by state-level actors

**Bottom Line for Family Use:**
This setup is **excellent** for:
- Improving privacy on public/untrusted networks
- Ad and content blocking
- Parental controls
- Basic ISP avoidance
- Reasonable price/performance balance

This setup is **NOT sufficient** for:
- True anonymity
- Protection against determined government surveillance
- High-security/high-risk activities
- Circumventing sophisticated censorship (e.g., China's GFW)

---

## 🎓 Further Reading

**To learn more about VPN privacy:**
- EFF's Surveillance Self-Defense Guide: https://ssd.eff.org/
- Tor Project Documentation: https://www.torproject.org/docs
- IVPN Privacy Guides: https://www.ivpn.net/privacy-guides/ (educational, not endorsement)

**For threat modeling:**
- EFF's Threat Modeling Guide: https://ssd.eff.org/en/module/your-security-plan
- OWASP Threat Modeling: https://owasp.org/www-community/Threat_Modeling

**WireGuard/Tailscale security:**
- WireGuard Protocol Whitepaper: https://www.wireguard.com/papers/wireguard.pdf
- Tailscale Security Model: https://tailscale.com/security/

*Note: External links may change over time. Verify sources independently.*

---

## ❓ FAQ

**Q: Is this more private than a commercial VPN like NordVPN or ExpressVPN?**

A: Mixed. 
- ✅ You control the infrastructure (no third-party VPN provider)
- ✅ You know exactly what's running
- ❌ VPS provider still sees everything (same problem, different vendor)
- ❌ You're more easily identifiable (VPS is traceable to you)
- ❌ Commercial VPNs have more legal resources and "no-log" policies (though trust is required)

**Q: Can I use this in China or Iran?**

A: Unlikely to work reliably. These countries actively detect and block VPN protocols including WireGuard. You'd need obfuscation layers not included in this setup.

**Q: Will this protect me if I torrent copyrighted content?**

A: No. Your VPS provider will receive DMCA notices and can terminate your service. Additionally, you paid for the VPS, so you're easily identifiable. This is not anonymous.

**Q: Can I chain this with Tor for better anonymity?**

A: Yes, but be cautious with the order:
- **VPN → Tor**: Your ISP knows you use Tor, but not what you access
- **Tor → VPN**: Better for accessing VPN-required services via Tor, but complex setup

For most users, using Tor alone when anonymity is needed is simpler and sufficient.

**Q: What if my VPS provider logs everything?**

A: Assume they do. All VPS providers can log, and many do for operational reasons. Some jurisdictions require logging. If this is a concern, you need a different approach (Tor, or paid VPN with no-log policy).

**Q: Is HostHatch in Japan better than Vultr in the US for privacy?**

A: Marginally, but both can be compelled by legal requests. Japan is not in Five Eyes but cooperates with US law enforcement. For casual use, location matters less than you think. For high-security needs, neither is sufficient.

**Q: Should I use this 24/7 or split tunnel?**

A: For family use with 10 people, consider split tunneling:
- Route sensitive browsing through VPN
- Allow local services, gaming, video calls direct
- This improves performance and reduces detectability

---

## ⚖️ Legal Disclaimer

This document is for educational purposes. Using VPN technology is legal in most jurisdictions, but:

- Check your local laws regarding VPN usage
- Respect your VPS provider's Terms of Service
- Don't use this for illegal activities
- The authors are not responsible for misuse

**Remember**: Privacy is not the same as permission to break laws. Use responsibly.

---

## 🆘 Getting Help

If you have questions about privacy, security, or threat modeling:

1. **For technical issues**: [GitHub Issues](https://github.com/turgs/headscale_vps/issues)
2. **For privacy advice**: [EFF](https://www.eff.org/), [Privacy Guides](https://www.privacyguides.org/)
3. **For serious threats**: Consult a security professional

**Remember**: If you're facing serious threats, seek professional help. Don't rely solely on DIY solutions.

---

*This document aims to be honest and realistic about VPN capabilities without hype or overselling.*
