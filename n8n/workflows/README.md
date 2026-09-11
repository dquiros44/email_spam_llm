# n8n workflows

Exported workflow JSON lives here, versioned like code. To export from a
running n8n instance:

```bash
n8n export:workflow --all --output=./n8n/workflows/
```

## `email-triage.json` (planned)

The pipeline designed for this project:

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

Not yet exported/committed — build the workflow in the n8n UI first, then
drop the export here.
