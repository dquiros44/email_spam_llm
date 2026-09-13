# Project context for Claude

This file is project memory — read it first in this repo. It records what
actually exists, where it lives, and what to watch out for. It is **not**
aspirational documentation; if something here looks stale, verify against
the live systems before trusting it (dates are noted so you can judge).

Last verified: **2026-09-13**.

## What this project is

A homelab that classifies incoming Gmail as important/spam/normal using a
**local LLM** (no email content leaves the LAN), routed through **n8n**,
with the n8n host provisioned by **Terraform** on **Proxmox**. Built as a
resume/portfolio piece — see `README.md` for the pitch, `docs/architecture.md`
for design rationale and the GPU-tuning writeup.

## Physical topology

| Machine | Role | Address |
|---|---|---|
| **zeus** | Windows 11 Pro desktop. Dual GPU: RTX 3060 Ti (8GB) + RTX 3060 (12GB). Runs LM Studio (the inference server) and this Claude Code session. | LAN `10.10.10.202`, Tailscale `100.120.9.81` |
| **cronos** | Proxmox VE 9.2.4 host, single node. | `10.10.10.20`, web UI `:8006` |
| **LXC 110** (`n8n`) | Debian 12 container on `cronos`, runs n8n via Docker. **This project's guest.** | DHCP-assigned, was `10.10.10.109` as of 2026-09-13 — **verify with `pct list` / `pct exec 110 -- ip -4 addr show eth0`, it can change on reboot** |
| LXC 103 (`jobscan`) | A **different, unrelated project** (job-listing collector) also living on `cronos`. Don't touch it. | `10.10.10.233` |

## How to reach things

- **SSH to Proxmox**: `ssh root@10.10.10.20` — already works from `zeus`, key `~/.ssh/id_ed25519` is pre-authorized. No setup needed. (See the `proxmox-ssh-access` memory file in Claude's persistent memory on this machine for the same fact, kept in sync with this doc.)
- **SSH into the n8n container from zeus**: `ssh root@10.10.10.20 "pct exec 110 -- <command>"` — there's no need to SSH into the container directly; go through Proxmox's `pct exec`.
- **n8n web UI**: `https://<container-ip>:5678` — HTTPS with a **self-signed cert** (expect a browser warning, click through). Login is whatever owner account was set up in n8n itself, not tracked here.
- **LM Studio API** (the classifier backend): `http://10.10.10.202:1234/v1/...` — OpenAI-compatible. Bound to `0.0.0.0`, reachable from the LAN. Requires a Windows Firewall rule (see Gotchas).
- **Proxmox API** (for Terraform): token lives in `C:\Users\Zeus\.config\homelab-api\env.ps1` on `zeus` (`PVE_URL`, `PVE_TOKEN_ID`, `PVE_TOKEN_SECRET`, `PVE_NODE`). **Never `cat` this file or paste its contents anywhere** — read it programmatically if needed, or ask the human to fill `terraform.tfvars` themselves.
- **GitHub**: `gh` CLI already authenticated as `dquiros44` on this machine. Repo: `https://github.com/dquiros44/email_spam_llm`, public.

## What's actually running right now

- **n8n**: one workflow, internal name `llm`, exported to `n8n/workflows/email-triage.json`. **Active/Published** — polls Gmail every minute. Pipeline: Gmail Trigger → Code (build prompt) → HTTP Request (LM Studio) → Code (parse JSON) → Switch → Gmail (add label: `AI-Important` / `AI-Spam` / `AI-Sorted`).
- **LM Studio**: multiple models downloaded (see `lms ls`); daily-driver classifier is `llama-3.2-3b-instruct-uncensored-i1` (IQ4_XS imatrix quant, ~180 tok/s tuned). GPU split strategy is set to **priority-order, RTX 3060 Ti first** (`hardware-config.json`) — this is the one config that works well for both small models (fit entirely on the Ti) and large ones (overflow to the 3060). MSI Afterburner is applied: core +120, memory +1200/+1700, undervolt curve flattened at ~1900MHz/900mV.

## Known gotchas (read before touching things)

1. **LM Studio must actually be running** for the n8n pipeline to work — it doesn't auto-start on Windows boot. If email triage silently stops, check this first: `curl http://10.10.10.202:1234/v1/models` from anywhere on the LAN.
2. **Model auto-unload TTL**: as of last check, the loaded model has a **1-hour idle TTL** — LM Studio will unload it after an hour of no requests, and the *next* email won't get classified until it reloads (a few seconds delay, not a failure, but worth knowing). Reload with `--ttl 0` if you want it to never auto-unload:
   ```bash
   C:/Users/Zeus/.lmstudio/bin/lms.exe load llama-3.2-3b-instruct-uncensored-i1 --context-length 4096 --parallel 1 --ttl 0 -y
   ```
3. **Reloading via LM Studio's GUI resets `parallel` to 4 and context to 8192**, undoing the tuned ~180 tok/s config (drops to ~100). Always reload via the `lms` CLI with explicit flags (above), never via the GUI's "reload" unless you also fix Parallel=1 there manually. **Never pass `--gpu max`** — it overrides the GPU split config and forces the slow card.
4. **Windows Firewall blocks LAN access to LM Studio by default.** The fix (already applied, but if rebuilt from scratch):
   ```powershell
   New-NetFirewallRule -DisplayName "LM Studio LAN" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1234 -Profile Private,Domain
   ```
   Must be run from an **elevated** PowerShell.
5. **Terraform + this Proxmox provider (`bpg/proxmox`) quirks hit during setup:**
   - Each module needs its own `required_providers` block declaring `bpg/proxmox`, or it silently defaults to the legacy `hashicorp/proxmox` provider.
   - `keyctl` in the container `features` block fails with 403 — Proxmox restricts it to `root@pam` regardless of API token privilege level. Only `nesting` is settable via API token.
   - The container's real IP is `proxmox_virtual_environment_container.X.ipv4["eth0"]` (a map) — **not** `initialization[0].ip_config[0].ipv4[0].address`, which just echoes back the literal `"dhcp"` string you configured.
   - The `remote-exec` provisioner's SSH connection needs an explicit `private_key = file(...)` — there's no working SSH agent to fall back on in this environment.
6. **Gmail OAuth2 credential setup has two Google-side restrictions**, not n8n's fault:
   - Redirect URI must be `https://`, not `http://` (n8n is set up with a self-signed cert for this reason — the browser will show "not secure," that's fine, Google only checks the URL scheme, not cert trust).
   - Google also **rejects bare IP addresses** as redirect hosts (must be `localhost` or a real domain with a public TLD). Worked around by registering `https://localhost:5678/rest/oauth2-credential/callback` and doing the one-time "Connect my account" click through an SSH local port-forward:
     ```bash
     ssh -L 5678:<container-ip>:5678 root@10.10.10.20
     ```
     then browsing to `https://localhost:5678` on `zeus` just for that one step. The stored OAuth token works from any URL afterward.
7. **n8n's "Fetch Test Event" pins data to the trigger node** — repeated "Execute Workflow" clicks can replay the same pinned email instead of querying Gmail fresh. Unpin (small pin icon on the node) to force a live re-fetch.
8. **The workflow must be Active/Published** (n8n renamed "Active" to "Published" in some versions) for the Gmail Trigger to poll on its own schedule — manually executing a workflow works regardless of this toggle, which can make an inactive workflow look like it's "basically working" when it will do nothing unattended.
9. **HTTP Request node + raw JSON body + dynamic text = broken JSON.** Real email content contains characters (quotes, newlines) that break a naively-templated JSON string. Fix used: `{{ JSON.stringify($json.emailText) }}` (no surrounding quotes in the template) instead of `"{{ $json.emailText }}"`.
10. **Self-signed cert file permissions**: `openssl`-generated `key.pem` defaults to `600` (root-only) — n8n's Docker image runs as a non-root user and can't read it unless it's `chmod 644`'d after generation. Already handled in `terraform/modules/lxc-n8n/main.tf`.
11. **Git commit authorship**: this repo's commits are authored as `dquiros44 <111067341+dquiros44@users.noreply.github.com>` (GitHub's private noreply format) — local git config for this repo is already set accordingly. Don't let it drift back to a generic Claude identity.
12. **`zeus` does not sleep** (verified: `powercfg` shows "Sleep after" = Never on both AC/battery, hibernate disabled by Hyper-V's Guarded Host). This is required for the pipeline to stay reachable — if that ever changes, the whole pipeline goes dark whenever the PC sleeps.

## Where the real secrets live (never in this repo)

- Proxmox API token: `C:\Users\Zeus\.config\homelab-api\env.ps1` on `zeus`
- Terraform variables with the token filled in: `terraform/terraform.tfvars` (gitignored, exists locally on `zeus` only)
- n8n's Gmail OAuth credential: stored encrypted inside n8n's own SQLite DB in the container (`/home/node/.n8n` volume) — not exported, not in git. `n8n/workflows/email-triage.json` only carries a credential *reference* (id + display name).
- SSH private key: `~/.ssh/id_ed25519` on `zeus`, already authorized on `cronos`.

## Sensible next steps (not yet done, as of last check)

- Verify the n8n container's current DHCP IP hasn't drifted from `10.10.10.109` (or better: set a DHCP reservation for LXC 110's MAC, same as recommended for `zeus` in `docs/architecture.md`)
- Set the LM Studio model's TTL to `0` so it never auto-unloads mid-pipeline
- Wire the Terraform `lxc-n8n` module to auto-import `n8n/workflows/email-triage.json` on `apply` (discussed, not yet implemented — see chat history / `docs/architecture.md` for the plan)
- Broader real-world testing of the classifier's judgment across more email types before fully trusting it unattended
