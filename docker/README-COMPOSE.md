# Docker Compose Configuration

## File Location

The Docker Compose configuration file is located at:
```
docker/docker-compose.sira-community.app.yml
```

## Usage

### Basic Commands

All docker-compose commands must specify the file location:

```bash
# Build images
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod build

# Start services
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d

# Stop services
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod down

# View logs
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod logs -f

# Execute commands in container
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod exec app bash
```

### Environment-Specific Deployment

```bash
# Production
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d

# Development
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.dev up -d

# Staging
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.stage up -d

# Local
docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.local up -d
```

### Quick Reference

| Command | Description |
|---------|-------------|
| `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod build` | Build images |
| `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d` | Start services |
| `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod down` | Stop services |
| `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod ps` | List services |
| `docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod logs -f` | View logs |

## File Structure

The compose file is located in the `docker/` directory to:
- ✅ Keep all Docker-related files organized together
- ✅ Follow the project's ground rules for file organization
- ✅ Match the structure of other SIRA projects

## Path References

All paths in the compose file are relative to the project root:
- Build context: `..` (parent directory, project root)
- Volume mounts: `../config/`, `../public/`, etc.
- Nginx config: `./nginx/` (relative to docker/ directory)

---

**Note**: Always use the full path to the compose file when running docker-compose commands.

