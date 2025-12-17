# SIRA App ↔ Community “One Product” Rollout — Questions & Clarifications (Pre‑Execution)

This document is intended to be shared with the **SIRA App team** before executing the “one product” Community UX where Discourse is served under:

- `https://app.sira.ai/community/...` (**same origin**, subfolder mode)

The goal is to make the implementation predictable by confirming the **integration contract** (routing, headers, identity, and operational ownership) before any production changes.

---

## What we’re building (target state)

- **Community is not a separate site** (no `community.sira.ai` in the user journey)
- Discourse runs in **subfolder mode** at `/community`
- Authentication uses **DiscourseConnect (SSO)** with SIRA App as the **SSO provider**
- Customizations are **upgrade-safe** (Theme / Theme Component first; minimal plugins)

---

## Outstanding questions (remaining blockers before execution)

The runbook in SIRA App has been updated with many answers. The items below are the **only remaining blockers** to make execution unambiguous.

### 1) Canonical DiscourseConnect provider URL (pick ONE per environment)

**Question:** What is the single canonical `discourse_connect_url` we will paste into Discourse Admin → Settings → Login for each environment?

- Option A (SPA bridge): `https://<env>.app.sira.ai/auth/discourse/callback`
- Option B (backend route): `https://<env>.app.sira.ai/api/auth/discourse/callback`

**Rule:** Use the **external browser origin** (include port if non‑443), e.g. local:
- `https://local.app.sira.ai:8445/auth/discourse/callback`

**Recommendation (same-host Docker, production-grade):**
- Use **Option A** as the canonical value to configure in Discourse:
  - `https://<env>.app.sira.ai/auth/discourse/callback`
- Keep Option B (if it exists) as an internal redirect/convenience only, but **do not** document it as the primary value to paste into Discourse.

### 2) Exact `DISCOURSE_UPSTREAM` from the SIRA App nginx container (host:port + network)

**Question:** What is the exact `DISCOURSE_UPSTREAM` value per environment, as resolved **from the SIRA App edge nginx container**?

Confirm:
- **Host/service name** (Docker DNS) that the nginx container can resolve (e.g. `discourse`)
- **Port** Discourse actually serves on (commonly `3000`, sometimes `80` if fronted internally)
- **Shared Docker network** plan (especially if SIRA App and Discourse are in separate compose projects)

**Recommendation (same-host Docker, secure + production-grade):**
- Terminate TLS at the **SIRA App edge nginx** and run nginx → Discourse over **plain HTTP** on a private Docker network.
- Set upstream to the Discourse app port (most common):
  - **`DISCOURSE_UPSTREAM=http://discourse:3000`**
- Only use `:80` if you *intentionally* front Discourse internally on 80:
  - `DISCOURSE_UPSTREAM=http://discourse:80`

**Hardening checklist (same host):**
- **Do not publish** the Discourse upstream port to the host in production (no `-p 3000:3000` / no public NodePort).
- Put SIRA App edge nginx and Discourse on a **shared private network** (Docker external network or same compose network).
- Limit who can reach Discourse on that network (attach only required services; no “everything” network).
- Ensure forwarded headers reflect the **external browser origin** (include port if non‑443).
- Keep Discourse pinned (avoid `:latest`) and apply staged upgrades (staging-first).

---

## 1) Environments & canonical URLs (must be confirmed)

Please provide the exact values for each environment (**local/dev/stage/prod**):

- **SIRA App origin (external, browser)**: `https://<app-host>` (**include port if non-443**, e.g. `https://local.app.sira.ai:8445`)
- **Community path prefix**: expected to be `/community` (confirm it is not `/community/` vs `/community`)
- **Community canonical base URL**: `https://<app-host>/community` (**include port if non-443**)

**Docker note:** even if SIRA App runs in Docker, DiscourseConnect and URL generation must use the **external browser origin** (what users type), not an internal container hostname.

**Clarification:** for DiscourseConnect and URL generation, the canonical “community base” is **scheme + host + subfolder**.

---

## 2) Reverse proxy / routing contract

### Questions
- **Where is the proxy implemented?**
  - Which container/service is the edge entrypoint: `sira-app-nginx`, ingress controller, API gateway, or something else?
- **What is the upstream service target (internal) for Discourse?**
  - Hostname/service name resolvable **from the proxy container** (e.g., `discourse`)
  - Port (commonly `3000` for the Rails app; confirm your container/service port)
  - Where Discourse runs: same docker compose project, separate compose project, k8s, VM?
- **Does the proxy keep the `/community` prefix when forwarding?**
  - Confirm if it rewrites paths or forwards as-is

### Docker-specific routing questions (because SIRA App also runs in Docker)

- **Which Docker network(s) connect SIRA App ↔ Discourse?**
  - Are both stacks attached to a shared external network (recommended), or are they isolated?
  - If multiple compose projects are used, confirm the shared external network name and that both proxy and Discourse services join it.
- **Where is `DISCOURSE_UPSTREAM` configured and evaluated?**
  - Which container reads it (edge nginx vs app backend)?
  - Confirm the upstream hostname resolves via Docker DNS **from that container**.
- **Upstream port sanity check**
  - If you currently set `DISCOURSE_UPSTREAM=http://discourse:80`, confirm Discourse really listens on **80** internally.
  - If Discourse listens on **3000**, then upstream should be `http://discourse:3000`.
- **TLS termination location**
  - Confirm TLS terminates at the edge proxy (recommended), and traffic from proxy → Discourse is plain HTTP on the internal network.

### Required header behavior (confirm exact implementation)
- `X-Forwarded-Proto: https`
- `X-Forwarded-Host: <env>.app.sira.ai` (no internal hostnames)
- `X-Forwarded-Port: 443` (or your actual external port, e.g. `8445` for local)
- `Host: <env>.app.sira.ai` (must match the external origin)

### Websocket / live updates
Confirm that `/community/message-bus/*` and any websocket upgrade traffic works through the proxy:
- `Connection: upgrade`
- `Upgrade: websocket`

---

## 3) Discourse subfolder mode (must be explicit)

### Questions
- **How will Discourse be configured to use `/community`?**
  - Environment variable (e.g. `DISCOURSE_RELATIVE_URL_ROOT=/community`)
  - Site setting (`relative_url_root`)
  - Bootstrap/init automation vs manual admin setting
- **What is the canonical host Discourse should consider?**
  - Must be `app.sira.ai` (not `community.sira.ai`)
- **How will we validate URL correctness?**
  - Links, assets, and uploads must stay under:
    - `/community/...`
    - `/community/assets/...`
    - `/community/uploads/...`

---

## 4) DiscourseConnect (SSO) contract (identity + endpoints)

### Questions to confirm
- **What is the exact SSO provider endpoint in SIRA App** (the value used in Discourse `discourse_connect_url`) for each environment?
  - Example shape: `https://<app-origin>/<path>/discourse` (confirm actual path)
- **What is the shared secret storage/rotation plan?**
  - Where is `DISCOURSE_SSO_SECRET` stored (secrets manager)?
  - Rotation cadence and rollback plan?
- **User identifiers**
  - What will be used as `external_id`? (must be stable + immutable)
  - What is the source of truth for email changes?
  - Username policy (stable vs mutable, conflict resolution)
- **User provisioning**
  - Should Discourse auto-create users on first visit?
  - Should SSO override email/username/name on every login?
- **Logout behavior**
  - If a user logs out of SIRA App, what should happen on `/community`?
  - If a user logs out of Discourse, should it redirect to SIRA App logout?

### “SSO-only UX” expectations
Confirm the intended behavior:
- Local Discourse login/signup disabled or hidden
- Visiting `/community` with an active SIRA App session is **immediate**
- Visiting a deep link `/community/t/...` triggers **silent SSO** (or a single redirect hop)

---

## 5) Cookies, CSRF, and same-origin interactions

Because Discourse will run under the same origin (`app.sira.ai`), confirm:

- **Cookie collision avoidance**
  - Are there any cookie name conflicts between SIRA App and Discourse?
- **Cookie path scoping**
  - Should Discourse cookies be scoped to `/community`?
- **SameSite policy**
  - Confirm desired `SameSite` and `Secure` settings (prod must be `Secure`)
- **CSRF expectations**
  - Any custom global middleware/security headers that could break Discourse CSRF handling?

---

## 6) Theme / branding ownership (upgrade-safe)

### Questions
- Who owns the **Theme Component repo** (app team vs community team)?
- How will it be deployed (admin UI import vs CI automation)?
- What are the required “product chrome” elements?
  - Header branding
  - Primary navigation (Dashboard, Community, Profile)
  - “Back to SIRA AI” affordance
- Are we standardizing on **design tokens** (CSS variables) from SIRA App?

---

## 7) API access pattern for “one product”

### Questions
- Will the SIRA App frontend call Discourse APIs **directly** (browser → `/community/.../json`) or via **backend proxy**?
  - Recommendation: proxy via SIRA App backend for auth + rate limiting + future evolution
- Which community data is required “in-app”?
  - Recent topics, topic details, category list, search, create topic/post, notifications
- What is the auth model for API calls?
  - Discourse API key usage (server-to-server) vs user session cookie (browser)

---

## 8) Security & ops expectations (prod readiness)

### Questions
- How is Discourse version pinned (no `:latest` in prod)?
- Backup strategy (uploads + DB) and restore drill cadence?
- Monitoring ownership
  - 4xx/5xx rate, latency, background jobs, disk usage, email deliverability
- Admin hardening
  - Staff 2FA policy, admin access restrictions, audit/log retention

---

## 9) Acceptance tests (pre-prod checklist)

Please confirm we will validate the following in **staging** before prod:

- `/community` loads with correct branding
- Deep links `/community/t/<slug>/<id>` load and stay under `/community`
- Assets load under `/community/assets/*`
- Uploads load under `/community/uploads/*`
- Compose + post works
- Notifications and live updates work (message-bus)
- SSO-only login experience (no local Discourse login flow visible)

---

## What we need back from the SIRA App team (minimum)

1. **App origin per environment** (local/dev/stage/prod)
2. **Canonical `discourse_connect_url` per environment** (choose ONE canonical URL to configure in Discourse)
3. **`DISCOURSE_UPSTREAM` per environment** (exact internal `http://host:port` reachable from the edge nginx container)
4. Any **global security headers/middleware** applied at `app.sira.ai` that could affect `/community`

### Additional minimums when SIRA App runs in Docker

5. **Shared network plan**: which Docker network connects the SIRA App proxy container to the Discourse service (and how it’s created/managed)
 
