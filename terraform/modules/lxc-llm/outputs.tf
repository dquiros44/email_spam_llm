output "ipv4_address" {
  value = proxmox_virtual_environment_container.llm_node.ipv4["eth0"]
}

output "vmid" {
  value = proxmox_virtual_environment_container.llm_node.vm_id
}
