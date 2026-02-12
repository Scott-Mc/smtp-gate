# smtp-gate driver: LXC (stub)

driver_detect() {
  command -v lxc-ls >/dev/null 2>&1 || command -v lxc >/dev/null 2>&1
}

driver_list_vms() {
  echo "error: LXC driver not yet implemented" >&2
  return 1
}

driver_vm_macs() {
  echo "error: LXC driver not yet implemented" >&2
  return 1
}
