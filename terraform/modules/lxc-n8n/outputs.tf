output "ipv4_address" {
  value = proxmox_virtual_environment_container.n8n.initialization[0].ip_config[0].ipv4[0].address
}

output "vmid" {
  value = proxmox_virtual_environment_container.n8n.vm_id
}
