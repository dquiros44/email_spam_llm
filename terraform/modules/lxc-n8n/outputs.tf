output "ipv4_address" {
  value = proxmox_virtual_environment_container.n8n.ipv4["eth0"]
}

output "vmid" {
  value = proxmox_virtual_environment_container.n8n.vm_id
}
