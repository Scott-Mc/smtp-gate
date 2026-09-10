## v1.0.2

- Fix: the systemd timer did not fire after `systemctl restart smtp-gate.timer` on a host with a long uptime. Rules were never refreshed, so VMs created after the last run were not blocked. The timer now has `OnActiveSec=30s`.
- Fix: `install.sh` now restarts the timer, so a re-run loads a changed timer unit.
- Docs: the update procedure is now "unpack, then re-run `install.sh`". This avoids the `cp -i` alias prompt on RHEL family hosts.
- Faster interactive `whitelist` on hosts with many VMs.

### Update

```bash
curl -sL https://github.com/Scott-Mc/smtp-gate/releases/latest/download/smtp-gate.tar.gz \
  | tar xz -C /usr/local && /usr/local/smtp-gate/install.sh
```
