#!/usr/bin/env bash
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "error: run as root" >&2; exit 1; }

systemctl disable --now smtp-gate.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/smtp-gate.timer \
      /etc/systemd/system/smtp-gate.service
systemctl daemon-reload

nft delete table bridge smtp_gate >/dev/null 2>&1 || true

rm -f /usr/bin/smtp-gate

echo "ok: uninstalled"
echo "  install dir preserved: /usr/local/smtp-gate"
echo "  to remove all: rm -rf /usr/local/smtp-gate"
