# Admin Account Setup - Idempotent Deployment

## Overview

Admin account creation is now **idempotent** and can be part of the automated deployment process. This means:

- ✅ **Safe to run multiple times** - Won't create duplicates
- ✅ **One-time setup** - Typically only needed once per deployment
- ✅ **Optional automation** - Can be enabled/disabled via environment variable
- ✅ **Production-ready** - Secure, configurable, and documented

## Is It Part of Deployment?

**Yes, optionally.** Admin account creation can be:

1. **Automated** (recommended for initial setup): Enabled via `ENABLE_AUTO_ADMIN=true`
2. **Manual**: Run `rake admin:create` when needed
3. **Disabled**: Set `ENABLE_AUTO_ADMIN=false` (default)

## Is It One-Time?

**Yes, typically.** Once an admin account exists, subsequent runs will:
- Update existing admin if needed
- Not create duplicates
- Update password if provided via environment variable

## Making It Idempotent

The solution is **already idempotent**:

### Rake Task (`lib/tasks/admin.rake`)

```ruby
# Checks if admin exists first
existing_user = User.find_by_username(admin_username) || User.find_by_email(admin_email)

if existing_user
  # Updates existing user (idempotent)
  existing_user.admin = true
  existing_user.save
else
  # Creates new user (only if doesn't exist)
  User.create(...)
end
```

### Entrypoint Integration

The entrypoint script runs the rake task automatically if `ENABLE_AUTO_ADMIN=true`:

```bash
if [ "${ENABLE_AUTO_ADMIN:-false}" = "true" ]; then
  bundle exec rake admin:create
fi
```

## Usage

### Option 1: Automated (Recommended for Initial Setup)

**Enable in `env.community.app.local`:**

```bash
ENABLE_AUTO_ADMIN=true
ADMIN_EMAIL=admin@sira.ai
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
```

**Deploy:**
```bash
./docker/build-and-deploy.sh
```

Admin account will be created/updated automatically on first startup.

### Option 2: Manual (One-Time)

**After deployment, run:**
```bash
docker exec sira-community-app bundle exec rake admin:create \
  ADMIN_EMAIL=admin@sira.ai \
  ADMIN_USERNAME=admin \
  ADMIN_PASSWORD=your-secure-password
```

### Option 3: Disabled (Default)

**No action needed** - Admin account creation is disabled by default. Create manually when needed.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_AUTO_ADMIN` | `false` | Enable automatic admin creation on startup |
| `ADMIN_EMAIL` | `admin@sira.ai` | Admin account email |
| `ADMIN_USERNAME` | `admin` | Admin account username |
| `ADMIN_PASSWORD` | (generated) | Admin account password (required if auto-generating) |

**Alternative names** (for compatibility):
- `COMMUNITY_ADMIN_EMAIL`
- `COMMUNITY_ADMIN_USERNAME`
- `COMMUNITY_ADMIN_PASSWORD`

## Rake Tasks

### Create/Update Admin
```bash
bundle exec rake admin:create
bundle exec rake admin:create ADMIN_EMAIL=admin@example.com ADMIN_USERNAME=admin ADMIN_PASSWORD=password
```

### List Admins
```bash
bundle exec rake admin:list
```

### Remove Admin Privileges
```bash
bundle exec rake admin:remove[username]
```

## Idempotency Guarantees

✅ **Safe to run multiple times** - Won't fail or create duplicates
✅ **Updates existing** - If admin exists, updates admin status if needed
✅ **Creates if missing** - Only creates if admin doesn't exist
✅ **Password updates** - Updates password if provided via environment variable
✅ **No side effects** - Safe to run in production, CI/CD, or manual setup

## Production Recommendations

1. **Initial Setup**: Enable `ENABLE_AUTO_ADMIN=true` for first deployment
2. **Subsequent Deployments**: Can disable (`ENABLE_AUTO_ADMIN=false`) or keep enabled (idempotent)
3. **Password Management**: Always set `ADMIN_PASSWORD` explicitly in production
4. **Security**: Store passwords in secure secret management (not in plain text files)

## Troubleshooting

### Admin Not Created

**Check logs:**
```bash
docker logs sira-community-app | grep -i admin
```

**Verify environment variables:**
```bash
docker exec sira-community-app env | grep -i admin
```

**Run manually:**
```bash
docker exec sira-community-app bundle exec rake admin:create
```

### Admin Already Exists

**This is expected!** The task is idempotent - it will update the existing admin if needed.

**Verify admin exists:**
```bash
docker exec sira-community-app bundle exec rake admin:list
```

## Summary

- ✅ **Part of deployment**: Optional, enabled via `ENABLE_AUTO_ADMIN=true`
- ✅ **One-time**: Typically only needed once, but safe to run multiple times
- ✅ **Idempotent**: Already implemented - safe to run repeatedly
- ✅ **Production-ready**: Secure, configurable, and well-documented
