#!/usr/bin/env bash
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "error: run as root" >&2; exit 1; }

INSTALL_DIR="/usr/local/smtp-gate"
BIN_LINK="/usr/bin/smtp-gate"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SVC_SRC="$REPO_DIR/systemd/smtp-gate.service"
TMR_SRC="$REPO_DIR/systemd/smtp-gate.timer"
SVC_DST="/etc/systemd/system/smtp-gate.service"
TMR_DST="/etc/systemd/system/smtp-gate.timer"

CFG_DIR="/etc/smtp-gate"
CFG_EX="$REPO_DIR/config/config.example"
WL_EX="$REPO_DIR/config/whitelist.csv.example"

for f in "$REPO_DIR/smtp-gate" "$SVC_SRC" "$TMR_SRC"; do
  [[ -f "$f" ]] || { echo "error: missing $f" >&2; exit 1; }
done

# Copy repo to /usr/local/smtp-gate (or update in place if already there)
if [[ "$REPO_DIR" != "$INSTALL_DIR" ]]; then
  mkdir -p "$INSTALL_DIR"
  cp -a "$REPO_DIR"/. "$INSTALL_DIR"/
fi
chmod 0755 "$INSTALL_DIR/smtp-gate"

# Symlink into PATH
ln -sf "$INSTALL_DIR/smtp-gate" "$BIN_LINK"

# Config (preserve existing)
install -d -m 0750 "$CFG_DIR"
[[ -f "$CFG_DIR/config" ]]        || install -m 0640 "$CFG_EX" "$CFG_DIR/config"
[[ -f "$CFG_DIR/whitelist.csv" ]] || install -m 0640 "$WL_EX"  "$CFG_DIR/whitelist.csv"

# Systemd units
install -m 0644 "$INSTALL_DIR/systemd/smtp-gate.service" "$SVC_DST"
install -m 0644 "$INSTALL_DIR/systemd/smtp-gate.timer"   "$TMR_DST"

systemctl daemon-reload
systemctl enable --now smtp-gate.timer

echo "ok: installed to $INSTALL_DIR"
echo "  command: smtp-gate"
echo "  config:  $CFG_DIR/config"
echo "  timer:   systemctl status smtp-gate.timer"
echo "  update:  cd $INSTALL_DIR && git pull"
