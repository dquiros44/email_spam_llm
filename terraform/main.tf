provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

module "n8n" {
  source = "./modules/lxc-n8n"

  node                 = var.proxmox_node
  hostname             = var.n8n_hostname
  vmid                 = var.n8n_vmid
  cores                = var.n8n_cores
  memory_mb            = var.n8n_memory_mb
  disk_gb              = var.n8n_disk_gb
  network_bridge       = var.network_bridge
  ssh_public_key       = var.ssh_public_key
  ssh_private_key_path = var.ssh_private_key_path
}

module "llm_node" {
  source = "./modules/lxc-llm"
  count  = var.enable_llm_node ? 1 : 0

  node                 = var.proxmox_node
  hostname             = var.llm_hostname
  vmid                 = var.llm_vmid
  cores                = var.llm_cores
  memory_mb            = var.llm_memory_mb
  disk_gb              = var.llm_disk_gb
  network_bridge       = var.network_bridge
  ssh_public_key       = var.ssh_public_key
  ssh_private_key_path = var.ssh_private_key_path
}
