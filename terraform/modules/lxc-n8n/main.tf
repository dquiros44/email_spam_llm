resource "proxmox_virtual_environment_container" "n8n" {
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

  # Docker-in-LXC needs nesting; keyctl avoids some systemd/docker quirks.
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
    host        = proxmox_virtual_environment_container.n8n.ipv4["eth0"]
    user        = "root"
    private_key = file(var.ssh_private_key_path)
    timeout     = "3m"
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
      "apt-get install -y openssl",
      "mkdir -p /opt/n8n/certs",
      "CONTAINER_IP=$(hostname -I | awk '{print $1}'); openssl req -x509 -nodes -days 825 -newkey rsa:2048 -keyout /opt/n8n/certs/key.pem -out /opt/n8n/certs/cert.pem -subj \"/CN=n8n.local\" -addext \"subjectAltName=IP:$CONTAINER_IP,DNS:localhost\"",
      "chmod 644 /opt/n8n/certs/key.pem /opt/n8n/certs/cert.pem",
      "mkdir -p /opt/n8n",
      "cat > /opt/n8n/docker-compose.yml <<'EOF'\nservices:\n  n8n:\n    image: docker.n8n.io/n8nio/n8n\n    restart: unless-stopped\n    ports:\n      - \"5678:5678\"\n    environment:\n      - N8N_PROTOCOL=https\n      - N8N_SSL_KEY=/certs/key.pem\n      - N8N_SSL_CERT=/certs/cert.pem\n      - GENERIC_TIMEZONE=America/Chicago\n      - TZ=America/Chicago\n    volumes:\n      - n8n_data:/home/node/.n8n\n      - /opt/n8n/certs:/certs:ro\nvolumes:\n  n8n_data:\nEOF",
      "cd /opt/n8n && docker compose up -d --force-recreate",
    ]
  }
}
