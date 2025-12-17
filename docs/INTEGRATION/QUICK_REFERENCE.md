# SIRA App ↔ Community Integration - Quick Reference

## Quick Start Checklist

## What the SIRA App team needs from Community team (confirmations)

### 1) Exact Community origin (must match `DISCOURSE_URL` / `DISCOURSE_BASE_URL`)

Provide the **exact** community origin as **scheme + host + port** (if non-443). Examples:

- **Local**: `https://local.community.sira.ai:8443`
- **Prod (typical)**: `https://community.sira.ai`

This value is what the SIRA App team will set as:
- `DISCOURSE_BASE_URL` (or `DISCOURSE_URL`) in the SIRA App backend

### 2) Discourse Admin → Settings → Login (Discourse Connect)

These must be set in Discourse:

```text
enable_discourse_connect = true
discourse_connect_url = https://<your-app-domain>/auth/discourse/callback
discourse_connect_secret = <same value as DISCOURSE_SSO_SECRET>
```

### 3) If you share app domains per environment, we can return exact paste-ready URLs

If you provide your SIRA App origins for **local/dev/stage/prod** (e.g. `https://app-dev.sira.ai`), then the exact `discourse_connect_url` for each environment is:

```text
https://<APP_ORIGIN>/auth/discourse/callback
```

### 1. Discourse Configuration

```text
# Admin → Settings → Login
enable_discourse_connect = true
discourse_connect_url = https://app.sira.ai/auth/discourse/callback
discourse_connect_secret = <same value as DISCOURSE_SSO_SECRET>
```

### 2. SIRA App Environment Variables

```bash
# Backend .env
# Community origin / base URL (scheme + host + port). Set this to match your deployment.
# Local example:
# - https://local.community.sira.ai:8443
DISCOURSE_BASE_URL=https://local.community.sira.ai:8443
DISCOURSE_SSO_SECRET=your_shared_secret_key_here
DISCOURSE_API_KEY=your_discourse_api_key_here
DISCOURSE_API_USERNAME=system
APP_BASE_URL=https://app.sira.ai
```

### 3. API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/discourse/login` | GET | Initiate SSO login |
| `/api/auth/discourse/callback` | GET | Handle SSO callback |
| `/api/community/recent-topics` | GET | Get recent topics |
| `/api/community/topic/:id` | GET | Get topic details |
| `/api/community/search` | GET | Search topics |
| `/api/community/categories` | GET | Get categories |
| `/api/community/topic` | POST | Create topic |

### 4. Frontend Utilities

```javascript
import { navigateToCommunity } from '../utils/community';

// Navigate to community with SSO
navigateToCommunity('/t/topic-slug/123', false);

// Open in new tab
navigateToCommunity('', true);
```

### 5. React Components

```jsx
import CommunityLink from '../components/CommunityLink';
import CommunityWidget from '../components/CommunityWidget';

// Navigation link
<CommunityLink>Community</CommunityLink>

// Dashboard widget
<CommunityWidget />
```

## SSO Flow

1. User clicks "Community" → `/api/auth/discourse/login`
2. Backend generates SSO payload → Redirects to Discourse
3. Discourse verifies → Redirects to callback
4. Backend builds return payload → Redirects back to Discourse
5. User logged in → Community accessible

## API Examples

### Get Recent Topics

```javascript
const response = await fetch('/api/community/recent-topics?limit=10', {
  credentials: 'include',
});
const data = await response.json();
```

### Search Topics

```javascript
const response = await fetch('/api/community/search?q=search+query', {
  credentials: 'include',
});
const data = await response.json();
```

### Create Topic

```javascript
const response = await fetch('/api/community/topic', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  credentials: 'include',
  body: JSON.stringify({
    title: 'Topic Title',
    content: 'Topic content in markdown',
    category: 'category-id',
  }),
});
```

## Common Issues

| Issue | Solution |
|-------|----------|
| SSO signature mismatch | Verify `DISCOURSE_SSO_SECRET` matches |
| User not created | Check Discourse logs, verify user data |
| API 403 error | Verify API key and scopes |
| CORS errors | Configure CORS in Discourse or use backend proxy |

## Security Checklist

- [ ] SSO secret stored in environment variables
- [ ] API key stored in environment variables
- [ ] HTTPS enabled for all redirects
- [ ] Nonces expire after 5 minutes
- [ ] User data validated before sending
- [ ] API keys have minimum required scopes

