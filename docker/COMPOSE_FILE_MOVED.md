# Docker Compose File Location Update

## ⚠️ Important: File Location Changed

The Docker Compose configuration file has been moved and renamed:

**Old Location**: `docker-compose.yml` (root directory)  
**New Location**: `docker/docker-compose.sira-community.app.yml`

## Why This Change?

This change was made to:
- ✅ Follow project ground rules for file organization
- ✅ Keep all Docker-related files in the `docker/` directory
- ✅ Match the structure of other SIRA projects
- ✅ Improve project organization and maintainability

## Updated Usage

### Before (Old)
```bash
docker-compose build
docker-compose up -d
```

### After (New)
```bash
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod build
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d
```

## Using Makefile (Recommended)

The Makefile has been updated to use the new location automatically:

```bash
# Build
make build ENV=prod

# Start services
make up ENV=prod

# View logs
make logs ENV=prod

# Run migrations
make migrate ENV=prod
```

## Quick Reference

| Command | New Format |
|---------|------------|
| Build | `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod build` |
| Start | `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d` |
| Stop | `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod down` |
| Logs | `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod logs -f` |

## Path Updates

All paths in the compose file have been updated:
- Build context: `..` (project root)
- Volume mounts: `../config/`, `../public/`, etc.
- Nginx config: `./nginx/` (relative to docker/ directory)

## Documentation Updates

All documentation has been updated to reflect the new location:
- ✅ `README.md` - Updated commands
- ✅ `PROJECT_STRUCTURE.md` - Updated file location
- ✅ `docker/Makefile` - Updated all commands
- ✅ `docker/README-COMPOSE.md` - New usage guide

---

**Date**: January 2025  
**Status**: ✅ File moved and all references updated

