variable "node" {
  type = string
}

variable "hostname" {
  type = string
}

variable "vmid" {
  type = number
}

variable "cores" {
  type = number
}

variable "memory_mb" {
  type = number
}

variable "disk_gb" {
  type = number
}

variable "network_bridge" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

variable "storage" {
  description = "Proxmox storage id for the container rootfs."
  type        = string
  default     = "local-lvm"
}

variable "template_file_id" {
  description = "Volume id of the LXC template to clone (Debian 12 standard, downloaded on the 'local' storage)."
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "timezone" {
  type    = string
  default = "America/Chicago"
}
