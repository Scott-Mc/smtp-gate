# smtp-gate

Block outbound SMTP from VMs at the hypervisor level. Whitelist VMs you authorize.

Built for web hosts, cloud providers, and anyone running customer VMs who needs
to prevent email abuse and protect IP reputation - the same kind of SMTP
restriction used by AWS, DigitalOcean, and Hetzner, but for your own
infrastructure.

![smtp-gate usage](https://github.com/user-attachments/assets/f2841d2d-19f4-4abb-b139-fdabe3ba1216)

## Usage

```
smtp-gate apply                                # block SMTP ports on all VMs
smtp-gate disable                              # remove all rules (unblock everything)
smtp-gate status                               # show current state + whitelisted VMs
smtp-gate whitelist                            # interactive VM picker (shown below)
smtp-gate add-vm  <name> [reason]              # whitelist a VM by name
smtp-gate del-vm  <name>                       # remove a VM from the whitelist
smtp-gate add-mac <aa:bb:cc:dd:ee:ff> [label]  # whitelist a MAC directly
smtp-gate del-mac <aa:bb:cc:dd:ee:ff>          # remove a MAC from the whitelist
smtp-gate ports-set "25,465,587"               # change which ports are blocked
smtp-gate list                                 # show raw whitelist
smtp-gate debug                                # bridge ports, nft table, full config
```

### Whitelist a VM

```bash
smtp-gate add-vm myserver "ID verified"
# ok: whitelisted myserver (52:54:00:12:34:56)
# ok: applied
```

### Interactive whitelist

Pick VMs from a list

![smtp-gate whitelist](https://github.com/user-attachments/assets/f2841d2d-19f4-4abb-b139-fdabe3ba1216)

### Monitor blocked attempts

Blocked packets are logged by default (prefix `SMTPGATE4` / `SMTPGATE6`):

```bash
dmesg | grep SMTPGATE
journalctl -k --grep SMTPGATE
```

## How it works

- nftables bridge-family table with a forward hook (priority -200)
- Matches outbound only: VM tap port → uplink port
- Inbound SMTP to VMs is never affected
- Whitelisted MACs are accepted; everything else is dropped
- A systemd timer re-applies rules every 60s, picking up new or removed VMs
- IPv4 and IPv6

## Install

```bash
git clone https://github.com/Scott-Mc/smtp-gate.git /usr/local/smtp-gate
cd /usr/local/smtp-gate
./install.sh
```

Edit `config/smtp-gate.conf` if your bridge is not `br0`, then:

```bash
smtp-gate apply
```

To update later:

```bash
cd /usr/local/smtp-gate && git pull
```

The systemd service and `/usr/bin/smtp-gate` symlink both point into
`/usr/local/smtp-gate/`, so a `git pull` updates the running script immediately.

### What gets installed

| Path                                         | Purpose                                |
| -------------------------------------------- | -------------------------------------- |
| `/usr/local/smtp-gate/`                      | Application directory (self-contained) |
| `/usr/bin/smtp-gate`                         | Symlink into PATH                      |
| `/usr/local/smtp-gate/config/smtp-gate.conf` | Configuration                          |
| `/usr/local/smtp-gate/config/whitelist.csv`  | Whitelist database                     |
| `/etc/systemd/system/smtp-gate.service`      | One-shot apply service                 |
| `/etc/systemd/system/smtp-gate.timer`        | 60s refresh timer                      |

## Requirements

- Linux with nftables (AlmaLinux 8+/9+/10+, Debian 10+, Ubuntu 20.04+)
- `nft`, `bridge` (iproute2), `ip`
- A Linux bridge (e.g. `br0`) with VM tap interfaces
- A hypervisor CLI for `add-vm` and `whitelist` commands:
  - **KVM/QEMU**: `virsh` (libvirt) — auto-detected
  - **LXC**: `lxc-ls` / `lxc` — stub, not yet implemented
  - **Xen**: `xl` — stub, not yet implemented

Core commands (`apply`, `status`, `disable`, `add-mac`, `del-mac`, `list`,
`ports-set`) work without a hypervisor driver.

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

## Hypervisor drivers

smtp-gate auto-detects the hypervisor by checking which CLI tools are
available. To override, set `HYPERVISOR` in `config/smtp-gate.conf`.

| Driver | CLI tool         | Status                |
| ------ | ---------------- | --------------------- |
| `kvm`  | `virsh`          | Full support          |
| `lxc`  | `lxc-ls` / `lxc` | Stub (detection only) |
| `xen`  | `xl`             | Stub (detection only) |

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
./uninstall.sh
```

Removes the timer, nftables table, and symlink. Config and application
directory are preserved for manual removal.

## License

MIT
