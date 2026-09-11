variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://10.10.10.20:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!token-name=uuid'. Set via TF_VAR_proxmox_api_token or terraform.tfvars (gitignored) — never commit this."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API (true for a self-signed homelab cert)."
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Target Proxmox node name."
  type        = string
  default     = "cronos"
}

variable "network_bridge" {
  description = "Proxmox bridge to attach guest NICs to."
  type        = string
  default     = "vmbr0"
}

variable "ssh_public_key" {
  description = "SSH public key injected into guests for management access."
  type        = string
}

# --- n8n LXC ---

variable "n8n_hostname" {
  type    = string
  default = "n8n"
}

variable "n8n_vmid" {
  type    = number
  default = 110
}

variable "n8n_cores" {
  type    = number
  default = 2
}

variable "n8n_memory_mb" {
  type    = number
  default = 2048
}

variable "n8n_disk_gb" {
  type    = number
  default = 16
}

# --- LLM node (planned) ---

variable "enable_llm_node" {
  description = "Whether to provision the in-cluster LLM node. Off by default — inference currently runs on the Windows host GPUs."
  type        = bool
  default     = false
}

variable "llm_hostname" {
  type    = string
  default = "llm-node"
}

variable "llm_vmid" {
  type    = number
  default = 111
}

variable "llm_cores" {
  type    = number
  default = 4
}

variable "llm_memory_mb" {
  type    = number
  default = 8192
}

variable "llm_disk_gb" {
  type    = number
  default = 40
}
