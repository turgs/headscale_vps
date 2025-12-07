# Split Tunneling Guide

Split tunneling allows you to route only specific traffic through your VPN while keeping other traffic on your normal internet connection. This is useful for:

- **Better performance**: Only route what you need through the VPN
- **Access local resources**: Keep access to local network devices (printers, NAS, etc.)
- **Selective blocking**: Use VPN's ad/porn blocking only for specific devices or apps

## Understanding Split Tunneling vs Full Tunnel

### Full Tunnel (Exit Node)
All internet traffic goes through the VPN:
```
Your Device → VPN → Internet
```

### Split Tunnel
Only specific traffic goes through the VPN:
```
Some Traffic → VPN → Internet
Other Traffic → Direct → Internet
```

---

## Option 1: Per-Device Split Tunneling (Simplest)

This is the easiest approach for families - choose which devices use the VPN.

### Setup

1. **Devices that need protection** (kids' devices, work laptop):
   - Enable exit node in Tailscale settings
   - These devices get ad/porn blocking and privacy

2. **Devices that don't need VPN** (Smart TV, gaming console):
   - Don't enable exit node
   - These devices use regular internet

### How to Enable/Disable Exit Node

#### Windows
1. Right-click Tailscale icon in system tray
2. Click "Exit Node"
3. Select your VPS or "None" to disable

#### Android/iOS
1. Open Tailscale app
2. Tap the three dots → "Use exit node"
3. Select your VPS or "None" to disable

#### macOS/Linux
```bash
# Enable exit node
sudo tailscale set --exit-node YOUR_VPS_HOSTNAME

# Disable exit node
sudo tailscale set --exit-node=
```

---

## Option 2: Subnet Routing (Advanced)

Route only specific IP ranges through the VPN. This requires some networking knowledge.

### Use Cases
- Route only work network traffic through VPN
- Access home network remotely
- Route specific country's IPs through VPN

### Setup

This is complex and requires configuring subnets on both client and server. See Tailscale documentation for details: https://tailscale.com/kb/1019/subnets/

---

## Option 3: DNS-Based Routing (Partial Solution)

Use AdGuard Home's DNS to block ads/porn without routing all traffic through VPN.

### How It Works
Your device connects to the VPN but doesn't use it as exit node. It only uses the VPN's DNS server for ad/porn blocking.

### Setup

1. Connect to VPN **without** enabling exit node:
   ```bash
   # Don't include --advertise-exit-node or --exit-node flags
   sudo tailscale up --login-server=https://robin-easy.bnr.la
   ```

2. Your device will automatically use the VPN's DNS (AdGuard Home) for:
   - Ad blocking
   - Tracking protection  
   - Porn blocking

3. But your internet traffic goes directly to websites (no VPN routing)

### Pros
- ✅ Still get ad/porn blocking
- ✅ Full internet speed (no VPN overhead)
- ✅ Access to local network devices

### Cons
- ❌ No IP address masking
- ❌ ISP can still see which sites you visit

---

## For Non-Technical Family Members

Here's what you can tell your 70-year-old family members:

### Simple Instructions

**To turn VPN ON (full protection):**
1. Look for the Tailscale icon near your clock (looks like a network symbol)
2. Right-click it
3. Click "Exit Node"
4. Click on the name of your VPN server
5. Done! All your internet now goes through the VPN

**To turn VPN OFF:**
1. Right-click Tailscale icon
2. Click "Exit Node"  
3. Click "None"
4. Done! Back to normal internet

**When should VPN be ON?**
- When you want ad blocking
- When you want safe browsing
- When on public WiFi

**When can VPN be OFF?**
- When watching Netflix/streaming (some sites block VPNs)
- When playing online games (to reduce lag)
- When at home on trusted WiFi

---

## Website-Specific Routing (Complex)

Routing specific websites (like Facebook, YouTube) through VPN is **very complex** because:

1. **Multiple domains**: Facebook uses dozens of domains:
   - facebook.com
   - fbcdn.net
   - facebook.net
   - instagram.com (owned by Facebook)
   - whatsapp.com (owned by Facebook)
   - ... and 50+ more

2. **CDNs**: Services like YouTube use Content Delivery Networks with thousands of IP addresses that change constantly

3. **Apps vs websites**: Mobile apps may not respect VPN routing rules

### Alternative: Use Per-Device Method Instead

Instead of routing specific websites, route specific **devices**:

- **Kid's phone/tablet**: Always use VPN (exit node enabled)
- **Parent's devices**: VPN optional (can toggle on/off)
- **Smart TV**: Never use VPN (exit node disabled)

This is much simpler and works reliably!

---

## Managing ACLs (Access Control)

ACLs control which users can access which devices in your VPN network.

### Simple Per-User Management

1. **SSH into your VPS:**
   ```bash
   ssh deploy@robin-easy.bnr.la -p 33003
   ```

2. **Edit the ACL file:**
   ```bash
   sudo nano /etc/headscale/acl.yaml
   ```

3. **Add or modify users:**
   ```yaml
   groups:
     group:family:
       - mom
       - dad
       - child1
       - child2
   ```

4. **Apply changes:**
   ```bash
   sudo systemctl reload headscale
   ```

### Example ACL Configurations

#### Allow kids to only access internet (no other family devices)
```yaml
acls:
  - action: accept
    src:
      - child1
      - child2
    dst:
      - tag:exit-node:*  # Only access exit node (internet)
```

#### Block specific users from each other
```yaml
acls:
  - action: drop  # Block access
    src:
      - child1
    dst:
      - mom:*
      - dad:*
```

### After Editing ACL

Always reload Headscale to apply changes:
```bash
sudo systemctl reload headscale
```

---

## Recommended Setup for Families

### Best Practice Configuration

1. **Create users for each family member:**
   ```bash
   sudo headscale users create mom
   sudo headscale users create dad
   sudo headscale users create child1
   ```

2. **Each person gets their own pre-auth key:**
   ```bash
   sudo headscale preauthkeys create --user mom --reusable --expiration 720h
   sudo headscale preauthkeys create --user child1 --reusable --expiration 720h
   ```

3. **Kids' devices:**
   - Always connected to VPN
   - Exit node always enabled (full tunnel)
   - Gets ad/porn blocking automatically

4. **Adult devices:**
   - Connected to VPN
   - Exit node can be toggled on/off (split tunnel capability)
   - Choose when to use VPN protection

5. **Shared devices** (Smart TV, game consoles):
   - Not connected to VPN at all
   - Or connected without exit node enabled

### Visual Setup

```
┌─────────────────┐
│  Kid's Phone    │─────► VPN (Exit Node ON) ──► Internet
│  [child1]       │        ↓ Ad/Porn Blocking
└─────────────────┘

┌─────────────────┐
│  Mom's Laptop   │─────► VPN (Exit Node: Toggle)
│  [mom]          │        Can switch ON/OFF as needed
└─────────────────┘

┌─────────────────┐
│  Smart TV       │─────► Direct Internet
│  [not on VPN]   │        No VPN connection
└─────────────────┘
```

---

## Troubleshooting

### Exit node not working?
```bash
# On VPS, check routes
sudo headscale routes list

# Enable route if needed
sudo headscale routes enable -r <route-id>
```

### Can't access local network printer/NAS?
You're in full tunnel mode. Either:
1. Disable exit node temporarily
2. Add subnet routes for your local network
3. Use split tunnel (DNS-only mode)

### Some websites not loading?
Some sites block VPN traffic. Temporarily disable exit node for those sites by turning off the exit node feature.

### DNS not blocking ads?
Make sure you're connected to VPN (even if not using as exit node). Check:
```bash
# On your device
tailscale status

# Should show connected status
```

---

## Summary

- **Easiest for families**: Per-device split tunneling (kids always on VPN, adults toggle as needed)
- **ACL management**: Edit `/etc/headscale/acl.yaml` and reload Headscale
- **Website-specific routing**: Not recommended (too complex). Use per-device instead.
- **Quick toggle**: Right-click Tailscale icon → Exit Node → On/Off

For more help, see:
- README.md (main documentation)
- QUICKSTART.md (initial setup)
- Headscale ACL docs: https://headscale.net/policy-acls/
