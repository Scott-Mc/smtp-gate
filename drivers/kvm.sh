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
