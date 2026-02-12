# smtp-gate

Blocks outbound SMTP (ports 25, 465) from VM guests at the hypervisor level
using nftables.  Only authorised VMs can send email.

Built for web hosts and cloud/VPS providers who need to prevent abuse and
protect IP reputation.  Similar to the SMTP restrictions used by AWS,
DigitalOcean, and Hetzner -- outbound mail is blocked by default and
unlocked per-VM after verification.

Does **not** use libvirt nwfilter (avoids the
[slow VM start bug](https://libvirt.org/news.html) in libvirt < 11.6).
Works alongside VirtFusion, UFW, and existing iptables/nft rules.

## How it works

- nftables bridge family table with a forward hook (priority -200)
- Matches only outbound direction: VM tap port to uplink port
- Inbound SMTP to VMs is never affected
- Whitelisted MACs are accepted; everything else is dropped
- A systemd timer re-applies rules every 60s, picking up new/removed VMs
- IPv4 and IPv6

## Requirements

- Linux with nftables (AlmaLinux 8+/9+/10+, Debian 10+, Ubuntu 20.04+)
- `nft`, `bridge` (iproute2), `ip`
- A hypervisor CLI for VM commands (`add-vm`, `whitelist`):
  - **KVM/QEMU**: `virsh` (libvirt) -- auto-detected
  - **LXC**: `lxc-ls` or `lxc` -- stub, not yet implemented
  - **Xen**: `xl` -- stub, not yet implemented
- A Linux bridge (e.g. `br0`) with VM tap interfaces

## Install

```bash
sudo git clone https://github.com/Scott-Mc/smtp-gate.git /usr/local/smtp-gate
cd /usr/local/smtp-gate
sudo ./install.sh
```

Edit `config/smtp-gate.conf` if your bridge is not `br0`, then:

```bash
sudo smtp-gate apply
```

To update later:

```bash
cd /usr/local/smtp-gate && sudo git pull
```

The systemd service and `/usr/bin/smtp-gate` symlink both point into
`/usr/local/smtp-gate/`, so a `git pull` updates the running script immediately.

### What gets installed

| Path | Purpose |
|------|---------|
| `/usr/local/smtp-gate/` | Application directory (self-contained) |
| `/usr/bin/smtp-gate` | Symlink into PATH |
| `/usr/local/smtp-gate/config/smtp-gate.conf` | Configuration |
| `/usr/local/smtp-gate/config/whitelist.csv` | Whitelist database |
| `/etc/systemd/system/smtp-gate.service` | One-shot apply service |
| `/etc/systemd/system/smtp-gate.timer` | 60s refresh timer |

## Usage

```
smtp-gate status                               # active/inactive + whitelisted VMs
smtp-gate apply                                # (re)apply nftables rules
smtp-gate rollback                             # remove all rules (unblock everything)
smtp-gate whitelist                            # interactive VM picker
smtp-gate add-vm  <name> [reason]              # whitelist VM by name
smtp-gate del-vm  <name>                       # remove VM from whitelist
smtp-gate add-mac <aa:bb:cc:dd:ee:ff> [label]  # whitelist MAC directly
smtp-gate del-mac <aa:bb:cc:dd:ee:ff>          # remove MAC from whitelist
smtp-gate ports-set "25,465,587"               # change blocked ports
smtp-gate list                                 # show raw whitelist CSV
smtp-gate debug                                # bridge ports, nft table, full config
```

### Whitelist a VM

```bash
sudo smtp-gate add-vm myserver "ID verified"
# ok: whitelisted myserver (52:54:00:12:34:56)
# ok: applied
```

### Interactive whitelist

```bash
sudo smtp-gate whitelist
```

Lists all VMs with their MAC addresses and whitelist status.  Select
numbers to toggle -- blocked VMs get whitelisted, whitelisted VMs get
removed:

```
  #    STATUS          VM                       MAC
  ---  -------------   ----------------------   -----------------
  1    [blocked]       vm-web-01                52:54:00:aa:bb:cc
  2    [whitelisted]   vm-mail-01               52:54:00:dd:ee:ff
  3    [blocked]       vm-app-03                52:54:00:11:22:33

Toggle numbers (comma-separated), or 'q' to quit: 1,3
ok: whitelisted vm-web-01 (52:54:00:aa:bb:cc)
ok: whitelisted vm-app-03 (52:54:00:11:22:33)
ok: applied
```

### Monitor blocked attempts

When `LOG_DROPS=1` (default), blocked packets are logged with prefix
`SMTPGATE4` / `SMTPGATE6`:

```bash
dmesg | grep SMTPGATE
journalctl -k --grep SMTPGATE
```

## Configuration

`/usr/local/smtp-gate/config/smtp-gate.conf`:

```bash
BRIDGE="br0"            # bridge to protect
BLOCKED_PORTS="25,465"  # ports to block outbound
LOG_DROPS="1"           # log dropped packets (0 to disable)
LOG_RATE="5/second"     # log rate limit
LOG_BURST="50"          # log burst allowance
# UPLINK_REGEX="..."    # override uplink interface detection
# HYPERVISOR="kvm"      # override auto-detection (kvm, lxc, xen)
```

## Whitelist format

`/usr/local/smtp-gate/config/whitelist.csv`:

```
# vmname,mac,added_at,added_by,reason
myserver,52:54:00:12:34:56,2025-06-15T10:30:45+00:00,admin,ID_verified
```

## Hypervisor drivers

smtp-gate uses a modular driver system for hypervisor-specific operations
(listing VMs, resolving MAC addresses).  Drivers live in the `drivers/`
directory.

| Driver | CLI tool | Status |
|--------|----------|--------|
| `kvm`  | `virsh`  | Full support |
| `lxc`  | `lxc-ls` / `lxc` | Stub (detection only) |
| `xen`  | `xl`     | Stub (detection only) |

On startup, smtp-gate auto-detects the hypervisor by checking which CLI
tools are available.  To skip auto-detection, set `HYPERVISOR` in
`config/smtp-gate.conf`:

```bash
HYPERVISOR="kvm"
```

Core commands (`apply`, `add-mac`, `del-mac`, `list`, `status`, `rollback`,
`ports-set`) work without a driver.  Only `add-vm` and `whitelist` require
a loaded driver.

### Writing a new driver

Create `drivers/<name>.sh` with three functions:

```bash
driver_detect()        # return 0 if this hypervisor is available
driver_list_vms()      # print all VM names, one per line
driver_vm_macs <vm>    # print MAC addresses for a VM, one per line
```

## Uninstall

```bash
cd /usr/local/smtp-gate
sudo ./uninstall.sh
```

Removes the timer, nftables table, and symlink.  Config and application
directory are preserved for manual removal.

## License

MIT
