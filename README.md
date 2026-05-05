# NikoZone WireMock Demo

Standalone WireMock + MailHog stack serving the mocked Magento API and SMTP sink used by the
NikoZone Vendor Portal. Designed to deploy as-is to a Coolify v4 instance via the **Docker Compose**
resource type — no manual Traefik / labels work required.

## What's inside

```
wiremock_demo/
├── docker-compose.yml          # Coolify-ready: uses SERVICE_FQDN_* magic env vars, no host ports
├── docker-compose.local.yml    # Local-only override that publishes host ports for dev use
├── .env.example                # Documents local port overrides
└── wiremock/
    ├── mappings/               # JSON stub mappings (orders, branches, vendors, stock, catalog sets)
    └── __files/                # Static response body files (currently empty — all stubs use inline jsonBody)
```

## Services

| Service  | Internal port | Purpose                |
|----------|---------------|------------------------|
| WireMock | `8089`        | HTTP API (mock Magento)|
| WireMock | `8080`        | GUI / admin            |
| MailHog  | `1025`        | SMTP                   |
| MailHog  | `8025`        | Web inbox              |

## Coolify deployment

1. In Coolify, create a new resource → **Docker Compose** → point it at this repo / sub-folder.
2. After Coolify parses `docker-compose.yml`, three magic FQDN slots appear under each service's
   **Domains** section:
   - `wiremock` → `SERVICE_FQDN_WIREMOCK_8089` (API) and `SERVICE_FQDN_WIREMOCK_8080` (GUI)
   - `mailhog`  → `SERVICE_FQDN_MAILHOG_8025` (web inbox)
3. Assign a domain to each — Coolify wires Traefik + TLS automatically. Suggested layout:
   - `wiremock-api.your-domain.tld` → WireMock API
   - `wiremock-gui.your-domain.tld` → WireMock GUI (**protect with Coolify Basic Auth**)
   - `mailhog.your-domain.tld` → MailHog inbox (**protect with Coolify Basic Auth**)
4. **MailHog SMTP (port 1025) is not assigned a public domain** — it's reachable only on the
   internal Coolify network. The portal must connect to it via the internal hostname Coolify
   shows in the UI (typically `mailhog-<resource-uuid>:1025`). If you do need SMTP public, expose
   it via Coolify's "Service Port Mapping" UI rather than editing this file.
5. Click Deploy. Mappings reload on container start; live-reload via `POST /__admin/mappings/reset`.

### Pointing the portal at the demo

In your portal `.env` (UAT / staging):

```
MAGENTO_BASE_URL=https://wiremock-api.your-domain.tld
MAGENTO_INTEGRATION_TOKEN=wiremock-dev-token

MAIL_MAILER=smtp
MAIL_HOST=mailhog-<coolify-uuid>     # Coolify-internal hostname, see Coolify UI
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
```

The stubs do not validate the bearer token — any value is accepted. MailHog accepts SMTP
unauthenticated and never relays — it just stores everything for inspection.

## Local quick start

The committed `docker-compose.yml` does **not** publish host ports (Coolify routes via Traefik
instead). For local dev, use the override file which adds host port mappings:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

- Mocked Magento API → `http://localhost:8088`
- WireMock GUI → `http://localhost:8087`
- MailHog SMTP → `localhost:1025`
- MailHog inbox → `http://localhost:8025`
- Health check → `curl http://localhost:8088/__admin/health`

Override default host ports via `WIREMOCK_API_PORT`, `WIREMOCK_GUI_PORT`, `MAILHOG_SMTP_PORT`,
`MAILHOG_UI_PORT` (see `.env.example`).

## Editing mappings

- Drop new `.json` files into `wiremock/mappings/` — they're picked up on container start.
- For binary response bodies (PDFs, images), drop them into `wiremock/__files/` and reference them
  via `"bodyFileName": "your-file.ext"` in a mapping.
- Use the GUI for ad-hoc edits during a pentest; remember GUI changes don't persist on Coolify
  redeploy unless you commit them back to git.

## Security notes for hosted use

- Neither WireMock nor MailHog ship with built-in auth on their HTTP/GUI surfaces. Always front
  the WireMock GUI and the MailHog inbox with **Coolify Basic Auth** (or Cloudflare Access).
- The WireMock API is intended to be public for the portal to reach it — the bearer token is
  decorative; nothing in the stubs validates it. Treat all data here as fixtures, not secrets.
- `--max-request-journal 1000` keeps the in-memory request log bounded — fine for demos, not a
  substitute for log shipping.
- WireMock is a **mock**, not a real Magento. Do not point production traffic at it.