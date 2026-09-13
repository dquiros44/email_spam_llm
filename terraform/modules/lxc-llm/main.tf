# PLANNED / OFF BY DEFAULT (see enable_llm_node in the root module).
#
# Today, inference runs natively on the Windows host (zeus) in LM Studio,
# with direct access to both GPUs (RTX 3060 Ti + RTX 3060) — see
# docs/architecture.md for why that setup currently outperforms anything
# GPU-passthrough-into-an-LXC would give us, and what it would take to move
# it in-cluster (vGPU licensing / full PCIe passthrough, one GPU dedicated
# to Proxmox instead of the Windows host, etc).
#
# This module provisions a plain CPU container running Ollama as a
# placeholder inference node — useful for small/quantized models or as a
# fallback target, not a replacement for the LM Studio setup yet.

resource "proxmox_virtual_environment_container" "llm_node" {
  node_name    = var.node
  vm_id        = var.vmid
  unprivileged = true
  started      = true

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  features {
    nesting = true
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

}

resource "null_resource" "llm_bootstrap" {
  depends_on = [proxmox_virtual_environment_container.llm_node]

  triggers = {
    vmid = var.vmid
  }

  connection {
    type        = "ssh"
    host        = proxmox_virtual_environment_container.llm_node.ipv4["eth0"]
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    timeout     = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update -y",
      "apt-get install -y curl",
      "curl -fsSL https://ollama.com/install.sh | sh",
      "systemctl enable --now ollama",
    ]
  }
}
