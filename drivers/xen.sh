# smtp-gate driver: Xen (stub)

driver_detect() {
  command -v xl >/dev/null 2>&1
}

driver_list_vms() {
  echo "error: Xen driver not yet implemented" >&2
  return 1
}

driver_vm_macs() {
  echo "error: Xen driver not yet implemented" >&2
  return 1
}
