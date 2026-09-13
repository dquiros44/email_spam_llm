# n8n workflows

Exported workflow JSON lives here, versioned like code. To export from a
running n8n instance:

```bash
n8n export:workflow --all --output=./n8n/workflows/
```

## `email-triage.json`

Exported from the live, working instance (`n8n export:workflow --all --separate`).
Currently **active** on the test LXC. The pipeline:

```
Gmail Trigger → build prompt → POST to local LLM (/v1/chat/completions,
structured JSON output) → parse category → Switch → Gmail: add label
(AI-Important / AI-Spam / AI-Sorted)
```

- Classifier model: a local 3B (`llama-3.2-3b-instruct-uncensored-i1`),
  `temperature: 0`, JSON-schema-constrained output (`category`, `reason`,
  `confidence`).
- Routing is label-only — no auto-delete. False positives on real mail cost
  more than the occasional spam slipping through.
- LLM endpoint: `http://10.10.10.202:1234/v1/chat/completions` (LM Studio,
  LAN-reachable; see `docs/architecture.md`).

Credentials are **not** included — `email-triage.json` only carries a
credential *reference* (id + display name), not the actual OAuth token.
Re-importing this workflow onto a fresh n8n instance requires creating a
Gmail OAuth2 credential there separately (see `docs/setup.md`), then
re-pointing each Gmail node at it.

To re-import:
```bash
n8n import:workflow --separate --input=./n8n/workflows/
```
