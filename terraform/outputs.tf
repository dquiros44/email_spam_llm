output "n8n_ipv4" {
  description = "DHCP-assigned IPv4 of the n8n container (available after apply, once the guest agent reports it)."
  value       = module.n8n.ipv4_address
}

output "n8n_vmid" {
  value = module.n8n.vmid
}

output "llm_node_ipv4" {
  description = "IPv4 of the optional in-cluster LLM node, if enabled."
  value       = var.enable_llm_node ? module.llm_node[0].ipv4_address : null
}
