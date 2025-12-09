# Environment Files Renamed

## ⚠️ Important: Environment Files Renamed

All environment files have been renamed to follow the naming convention: `env.community.app.{environment}`

## File Name Changes

| Old Name | New Name |
|----------|----------|
| `env.local` | `env.community.app.local` |
| `env.dev` | `env.community.app.dev` |
| `env.test` | `env.community.app.test` |
| `env.stage` | `env.community.app.stage` |
| `env.prod` | `env.community.app.prod` |
| `env.example` | `env.community.app.example` |

## Updated Usage

### Before (Old)
```bash
cp docker/env.prod .env
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.prod up -d
```

### After (New)
```bash
cp docker/env.community.app.prod .env
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d
```

## Using Makefile (Recommended)

The Makefile has been updated to use the new naming convention automatically:

```bash
# Build
make build ENV=prod

# Start services
make up ENV=prod

# Setup environment
make setup-prod
```

## Quick Reference

| Environment | File Name |
|-------------|-----------|
| Local | `env.community.app.local` |
| Development | `env.community.app.dev` |
| Test | `env.community.app.test` |
| Staging | `env.community.app.stage` |
| Production | `env.community.app.prod` |
| Example/Template | `env.community.app.example` |

## Why This Change?

This naming convention:
- ✅ Clearly identifies the service (`community`)
- ✅ Clearly identifies the component (`app`)
- ✅ Matches the docker-compose file naming (`docker-compose.sira-community.app.yml`)
- ✅ Follows consistent naming patterns across SIRA projects
- ✅ Makes it easier to identify which service/environment a file belongs to

## Updated Documentation

All documentation has been updated to reflect the new naming:
- ✅ `docker/Makefile` - All commands updated
- ✅ `docker/README-ENV.md` - Updated file references
- ✅ `docker/ENVIRONMENT_SETUP.md` - Updated examples
- ✅ `docker/README-COMPOSE.md` - Updated commands
- ✅ `README.md` - Updated quick start guide

---

**Date**: January 2025  
**Status**: ✅ Files renamed and all references updated

