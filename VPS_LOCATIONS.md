# VPS Location Selection Guide

Choosing the right VPS location is crucial for balancing performance, latency, and access to region-specific content. This guide helps you make the best choice for your needs.

---

## 🌏 Quick Recommendations

### For Brisbane, Australia Users

#### Best for General Performance & Speed
**Singapore** ✅ (Recommended)
- **Latency**: 80-120ms from Brisbane
- **Speed**: Excellent (typically 250+ Mbps on 250/100 NBN)
- **Providers**: HostHatch, Vultr, DigitalOcean, Linode
- **Best for**: Day-to-day VPN use, torrenting, general browsing

**Why Singapore?**
- Closest major data center hub to Australia
- Excellent network peering with Australian ISPs
- High-quality infrastructure
- Good balance of latency and speed for 250/100 NBN connections

#### Best for UK Content Access (BBC iPlayer, ITV, etc.)
**London, UK** ✅ (For UK streaming)
- **Latency**: 280-320ms from Brisbane
- **Speed**: Good (100-200 Mbps, limited by distance)
- **Providers**: HostHatch (UK), Hetzner (Germany/UK), OVH (UK)
- **Best for**: BBC iPlayer, ITV Hub, Channel 4, UK banking

**Scotland & Other UK Regions**
- **Latency**: Similar to London (280-320ms)
- **Speed**: Good (100-200 Mbps)
- **Providers**: Various UK-region providers
- **Note**: For BBC iPlayer access, **any UK location works** (England, Scotland, Wales, Northern Ireland)
- **Important**: Ireland is NOT part of the UK and does not work for UK content services

---

## 🤔 Trade-offs: Performance vs. Geographic Access

### Option 1: Singapore VPS (Optimal Performance)
✅ **Pros:**
- Lowest latency (~100ms)
- Best speeds on your 250/100 NBN
- Smooth browsing, gaming, video calls
- Great for general daily VPN use

❌ **Cons:**
- Cannot access UK-only services (BBC iPlayer, ITV, etc.)
- Shows Singapore IP address

### Option 2: UK/Europe VPS (Content Access)
✅ **Pros:**
- Access to UK streaming services (BBC iPlayer, ITV Hub, etc.)
- Access to UK banking/services
- Shows UK IP address

❌ **Cons:**
- Higher latency (~300ms) - noticeable delays
- Slower speeds (100-200 Mbps vs. 200-250 Mbps)
- Not ideal for gaming or video calls
- Longer distance = more hops = potential reliability issues

### Option 3: Multiple VPS Servers (Best of Both Worlds)
✅ **Best Solution:**
1. **Primary**: Singapore VPS for daily use
2. **Secondary**: UK VPS for streaming UK content

**How it works:**
- Use Singapore VPS by default (best performance)
- Switch to UK exit node when watching BBC iPlayer
- Costs: ~$3-5/month per VPS (total $6-10/month)

**Setup:**
```bash
# On your device, list available exit nodes
tailscale exit-node list

# Switch to UK VPS for BBC iPlayer
tailscale set --exit-node uk-vps-hostname

# Switch back to Singapore VPS for daily use
tailscale set --exit-node singapore-vps-hostname
```

---

## 🌍 Location Comparison Table

| Location | Latency from Brisbane | Speed on 250/100 NBN | UK Content Access | Best For |
|----------|----------------------|---------------------|-------------------|----------|
| **Singapore** | 80-120ms | Excellent (200-250 Mbps) | ❌ No | Daily VPN, torrenting, general browsing |
| **Tokyo** | 100-140ms | Excellent (180-230 Mbps) | ❌ No | Alternative to Singapore |
| **Sydney** | 5-20ms | Excellent (240+ Mbps) | ❌ No | Best latency, but defeats privacy purpose |
| **London** | 280-320ms | Good (100-200 Mbps) | ✅ Yes | BBC iPlayer, UK banking |
| **Frankfurt** | 270-310ms | Good (110-200 Mbps) | ❌ No | EU content, GDPR compliance |
| **Los Angeles** | 150-190ms | Good (150-220 Mbps) | ❌ No | US content, middle ground |
| **New York** | 200-240ms | Good (120-180 Mbps) | ❌ No | US content, higher latency |

---

## 🎬 BBC iPlayer & UK Streaming Services

### Important Notes for UK Content Access

**Geographic Requirements:**
- BBC iPlayer, ITV Hub, Channel 4, etc. require a **UK IP address**
- **Any UK region works**: England, Scotland, Wales, Northern Ireland
- **Ireland does NOT work** - Since Brexit, Ireland is EU-only and not considered UK for content licensing

**Best UK Locations:**
1. **London** - Most reliable, best network peering
2. **Manchester** - Good alternative
3. **Edinburgh/Glasgow (Scotland)** - Works perfectly for BBC iPlayer
4. **Belfast (Northern Ireland)** - Also works, but fewer VPS providers

**VPS Providers with UK Locations:**
- **HostHatch**: London, UK
- **Hetzner**: UK locations available
- **OVH**: London, UK
- **Vultr**: London, UK
- **DigitalOcean**: London, UK
- **Linode**: London, UK

**Note**: Only UK-based servers work for BBC iPlayer. Germany (Hetzner Falkenstein) and US locations (Ashburn) will NOT work.

### Does BBC iPlayer Work?

✅ **Works with UK VPS**
- UK IP address is sufficient
- No special configuration needed
- Works with Headscale VPN as exit node

❌ **Common Issues:**
- Some providers' IPs are blocked (VPS providers used by many VPNs)
- Solution: Choose less popular VPS providers or residential proxy services

---

## 💡 Recommendations for Your Scenario

Based on your situation (Brisbane-based, UK heritage family, 250/100 NBN):

### Recommended Setup

**Option A: Single VPS (Budget: ~$3-5/month)**
- Choose **UK VPS** (London or Scotland) if UK content access is your primary goal
- Accept higher latency (~300ms) for all VPN traffic
- Still usable for general browsing and streaming

**Option B: Dual VPS (Budget: ~$6-10/month)** ⭐ **Best Choice**
1. **Primary**: Singapore VPS (daily use, best performance)
2. **Secondary**: UK VPS (switch to this for BBC iPlayer)
3. Switch between them easily with Tailscale commands

**Option C: Singapore + Streaming Service**
- Use Singapore VPS for daily VPN
- Subscribe to UK streaming services if available internationally
- Or use smart DNS services for specific streaming

---

## 🚀 Quick Setup for Multiple VPS

**Security Note**: Before running any remote scripts, you should review them first:
```bash
# Inspect the provision script
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh | less
```

### 1. Provision First VPS (Singapore)
```bash
ssh root@SINGAPORE_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

### 2. Setup Exit Node
```bash
ssh deploy@SINGAPORE_IP -p 33003
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/setup_exit_node.sh | bash
```

### 3. Provision Second VPS (UK)
```bash
ssh root@UK_IP 'bash -s' < <(curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/provision_vps.sh)
```

### 4. Setup Exit Node
```bash
ssh deploy@UK_IP -p 33003
curl -fsSL https://raw.githubusercontent.com/turgs/headscale_vps/main/setup_exit_node.sh | bash
```

### 5. Switch Between Exit Nodes
```bash
# Use Singapore (default, best performance)
tailscale set --exit-node singapore-vps-hostname

# Switch to UK for BBC iPlayer
tailscale set --exit-node uk-vps-hostname

# List available exit nodes
tailscale exit-node list
```

---

## 🏢 Recommended VPS Providers

### Budget-Friendly ($3-5/month)
- **HostHatch**: Good performance, multiple locations, budget-friendly
- **RackNerd**: Cheap, good for secondary VPS
- **Hetzner**: Excellent value, Germany-based

### Premium Performance ($5-10/month)
- **Vultr**: Reliable, many locations
- **DigitalOcean**: Easy to use, good documentation
- **Linode**: Excellent support, reliable

### Enterprise-Grade ($10+/month)
- **AWS Lightsail**: Integrated with AWS services
- **Google Cloud**: High performance
- **Azure**: Microsoft ecosystem integration

---

## 📊 Latency Testing

Before committing to a VPS location, test latency:

```bash
# Test latency to Singapore
ping -c 10 singapore.hosthatch.com

# Test latency to London
ping -c 10 london.hosthatch.com

# Use mtr for detailed path analysis
mtr -r -c 10 singapore.hosthatch.com
mtr -r -c 10 london.hosthatch.com
```

**Expected latencies from Brisbane:**
- Singapore: 80-120ms
- London: 280-320ms
- Los Angeles: 150-190ms
- Tokyo: 100-140ms

---

## ❓ FAQ

### Q: Will 300ms latency to UK VPS be noticeable?
**A:** Yes, but manageable:
- Web browsing: Slight delay loading pages
- Streaming (BBC iPlayer): No issues (buffering handles latency)
- Gaming: Noticeable lag (not recommended for gaming)
- Video calls: Slight audio delay

### Q: Can I use Singapore VPS to access BBC iPlayer?
**A:** No, BBC iPlayer requires a UK IP address. You need a UK-based VPS.

### Q: Does Scotland VPS work for BBC iPlayer?
**A:** Yes! Any UK location (England, Scotland, Wales, N. Ireland) works for BBC iPlayer.

### Q: How much does running two VPS cost?
**A:** $6-10/month total (2 × $3-5/month). Budget providers like HostHatch or RackNerd are ~$3/month each.

### Q: Can I share the VPN with family?
**A:** Yes! They connect to the same Headscale server and can choose which exit node to use.

### Q: Will my ISP (NBN) know I'm using a VPN?
**A:** They'll see encrypted traffic to your VPS IP, but won't see what you're accessing.

---

## 🎯 Final Recommendation for Brisbane Users

### For General Use + UK Content Access:

**Recommended: Dual VPS Setup** 🏆

1. **Primary VPS**: Singapore (HostHatch, $3-5/month)
   - Daily VPN use
   - Best performance on your 250/100 NBN
   - Low latency (~100ms)

2. **Secondary VPS**: London, UK (HostHatch, $3-5/month)
   - Switch to this for BBC iPlayer
   - Access UK banking, services
   - Accept higher latency (~300ms) when needed

**Total Cost**: $6-10/month for both
**Setup Time**: 20-30 minutes total
**Flexibility**: Switch between regions as needed

This gives you the best of both worlds without compromising on either performance or content access!

---

## 📚 Additional Resources

- [README.md](README.md) - Main documentation
- [QUICKSTART.md](QUICKSTART.md) - Setup guide
- [Headscale Documentation](https://headscale.net/)
- [Tailscale Exit Nodes](https://tailscale.com/kb/1103/exit-nodes/)

---

**Need help?** Open an issue on [GitHub](https://github.com/turgs/headscale_vps/issues) with your specific use case!
