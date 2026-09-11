resource "proxmox_virtual_environment_container" "n8n" {
  node_name   = var.node
  vm_id       = var.vmid
  unprivileged = true
  started     = true

  operating_system {
    template_file_id = var.template_file_id
    type              = "debian"
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

  # Docker-in-LXC needs nesting; keyctl avoids some systemd/docker quirks.
  features {
    nesting = true
    keyctl  = true
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

  timezone = var.timezone
}

# Bootstraps Docker + docker-compose and brings up n8n once the container
# has an IP. Idempotent (safe to re-run via `terraform apply` /
# `terraform taint` on this resource).
resource "null_resource" "n8n_bootstrap" {
  depends_on = [proxmox_virtual_environment_container.n8n]

  triggers = {
    vmid = var.vmid
  }

  connection {
    type        = "ssh"
    host        = proxmox_virtual_environment_container.n8n.initialization[0].ip_config[0].ipv4[0].address
    user        = "root"
    private_key = null # uses ssh-agent / default identity, per the injected public key
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update -y",
      "apt-get install -y ca-certificates curl gnupg",
      "install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc",
      "chmod a+r /etc/apt/keyrings/docker.asc",
      "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable' > /etc/apt/sources.list.d/docker.list",
      "apt-get update -y",
      "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
      "mkdir -p /opt/n8n",
      "cat > /opt/n8n/docker-compose.yml <<'EOF'\nservices:\n  n8n:\n    image: docker.n8n.io/n8nio/n8n\n    restart: unless-stopped\n    ports:\n      - \"5678:5678\"\n    environment:\n      - GENERIC_TIMEZONE=America/Chicago\n      - TZ=America/Chicago\n      - N8N_SECURE_COOKIE=false\n    volumes:\n      - n8n_data:/home/node/.n8n\nvolumes:\n  n8n_data:\nEOF",
      "cd /opt/n8n && docker compose up -d",
    ]
  }
}
