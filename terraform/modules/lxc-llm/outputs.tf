output "ipv4_address" {
  value = proxmox_virtual_environment_container.llm_node.initialization[0].ip_config[0].ipv4[0].address
}

output "vmid" {
  value = proxmox_virtual_environment_container.llm_node.vm_id
}
