# smtp-gate driver: KVM / QEMU / libvirt (virsh)

driver_detect() {
  command -v virsh >/dev/null 2>&1
}

driver_list_vms() {
  virsh list --name --all 2>/dev/null | sed '/^$/d'
}

driver_vm_macs() {
  local vm="$1"
  virsh domiflist "$vm" 2>/dev/null \
    | awk 'BEGIN{IGNORECASE=1} $0 ~ /bridge/ && $5 ~ /([0-9a-f]{2}:){5}[0-9a-f]{2}/ {print tolower($5)}'
}

# Bulk: emit "vmname,mac" for every domain in one pass.
# Runs virsh domiflist in parallel batches (uses only shell builtins: & and wait).
driver_all_vm_macs() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  local pids=() vm
  while read -r vm; do
    [[ -n "$vm" ]] || continue
    (
      virsh domiflist "$vm" 2>/dev/null \
        | awk -v vm="$vm" 'BEGIN{IGNORECASE=1} $0 ~ /bridge/ && $5 ~ /([0-9a-f]{2}:){5}[0-9a-f]{2}/ {print vm "," tolower($5)}'
    ) > "$tmpdir/$vm" &
    pids+=($!)
    # Limit concurrency to 20
    if (( ${#pids[@]} >= 20 )); then
      wait "${pids[@]}" 2>/dev/null || true
      pids=()
    fi
  done < <(virsh list --name --all 2>/dev/null | sed '/^$/d')
  [[ ${#pids[@]} -gt 0 ]] && { wait "${pids[@]}" 2>/dev/null || true; }

  cat "$tmpdir"/* 2>/dev/null
  return 0
}
