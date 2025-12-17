# One Product Community (/community) — Execution Plan (Community Team)

This plan implements the “one product” Community UX where Discourse is served at:

- `https://<env>.app.sira.ai/community/...`

Reference runbook (SIRA App repo):
- `app/docs/integrations/sira-community/SIRA_COMMUNITY_TEAM_ONE_PRODUCT_COMMUNITY.md`

---

## 0) Preconditions (must be true before staging rollout)

- **SIRA App edge nginx** routes `/community/*` → Discourse upstream (no path rewrite)
- **Forwarded headers** are correct (external browser origin, include port if non‑443):
  - `Host`, `X-Forwarded-Host`, `X-Forwarded-Proto`, `X-Forwarded-Port`
- **Websocket upgrades enabled** for `/community/*` (message-bus)
- **SSO provider URL (canonical)** agreed:
  - `https://<env>.app.sira.ai/auth/discourse/callback` (include port if non‑443)
- **`DISCOURSE_UPSTREAM`** confirmed from edge nginx container:
  - Recommended: `http://discourse:3000` (same-host Docker, private network, no published ports)

---

## 1) Community-side configuration (Discourse)

### A) Run Discourse in subfolder mode

Discourse must be configured so all generated URLs stay under `/community/*`.

Required:
- `DISCOURSE_RELATIVE_URL_ROOT=/community`
- `DISCOURSE_HOSTNAME=<env>.app.sira.ai` (hostname must not include port)
- `DISCOURSE_FORCE_HTTPS=1`
- If the external origin uses a non‑443 port (local): set `DISCOURSE_PORT=<port>` so Discourse generates absolute URLs with that port.

### B) Expose Discourse only on the internal network

Production-grade recommendation (same host):
- Do **not** publish Discourse upstream ports to the host.
- Put SIRA App edge nginx and Discourse on a shared **private** Docker network.

### C) Configure DiscourseConnect (SSO)

In Discourse Admin → Settings → Login:

- `enable_discourse_connect = true`
- `discourse_connect_url = https://<env>.app.sira.ai/auth/discourse/callback`
- `discourse_connect_secret = <DISCOURSE_SSO_SECRET>`

SSO-only UX:
- disable/hide local login + signup

---

## 2) Staging validation checklist (must pass before prod)

- Routing:
  - `/community/` works
  - Deep link `/community/t/<slug>/<id>` works
  - No redirects to another host
- Assets/uploads:
  - `/community/assets/*` loads
  - `/community/uploads/*` loads
- Live updates:
  - message-bus works under `/community/message-bus/*`
- Auth:
  - SSO-only UX: no Discourse-native login
  - SSO flow works from:
    - entering via SIRA App → `/community`
    - deep linking directly to a topic

---

## 3) Deliverables for this repo (sira-community)

We will maintain:
- **Templates** for one-product env config (no secrets committed)
- **Docs** for required settings and validation steps


