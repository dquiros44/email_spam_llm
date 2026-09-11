# Setup

## Prerequisites

- A Proxmox VE node reachable over the network, with an API token that has
  rights to create containers (`PVEVMAdmin` or similar on the target
  storage/pool — a scoped token, not full root, for anything beyond a
  homelab).
- A Debian 12 LXC template already downloaded on the node's `local`
  storage (`pveam download local debian-12-standard_12.12-1_amd64.tar.zst`).
- Terraform >= 1.7.
- An SSH key pair for guest access.
- LM Studio running on a machine with GPU(s), serving on `0.0.0.0:1234`
  (Settings → Developer → Local Server → bind to `0.0.0.0`, not
  `127.0.0.1`), with at least one model loaded.

## 1. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `proxmox_endpoint` — your Proxmox API URL
- `proxmox_api_token` — `user@realm!token-name=uuid` (never commit this —
  the file is gitignored, but double-check before pushing)
- `ssh_public_key` — your public key, for guest login

## 2. Provision

```bash
terraform init
terraform plan
terraform apply
```

This creates the `n8n` LXC, installs Docker inside it, and starts n8n via
`docker compose`. Grab the container's IP from the output:

```bash
terraform output n8n_ipv4
```

n8n is reachable at `http://<n8n_ipv4>:5678`.

## 3. Point n8n at the local LLM

In n8n, the HTTP Request node (or OpenAI-compatible credential) should
target `http://<lm-studio-host>:1234/v1/chat/completions` — see
`docs/architecture.md` for the full request shape used by the email-triage
workflow.

## 4. Import the workflow

Once `n8n/workflows/email-triage.json` exists (see
`n8n/workflows/README.md`), import it via n8n's UI (Workflows → Import from
File) or `n8n import:workflow`.

## Tearing down

```bash
terraform destroy
```
