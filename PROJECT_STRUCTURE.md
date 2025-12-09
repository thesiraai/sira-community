# SIRA Community - Project Structure

This document describes the organization of the SIRA Community project, following the ground rules for easier management and maintenance.

## 📁 Directory Structure

```
sira-community/
├── app/                          # Rails application code (backend)
│   ├── assets/                   # Asset files
│   ├── controllers/              # MVC controllers
│   ├── helpers/                  # View helpers
│   ├── jobs/                     # Background jobs
│   ├── mailers/                  # Email mailers
│   ├── models/                   # ActiveRecord models
│   ├── queries/                  # Query objects
│   ├── serializers/              # API serializers
│   ├── services/                 # Service objects
│   └── views/                    # View templates
│
├── config/                       # Configuration files
│   ├── discourse.conf.example    # Production config template
│   ├── discourse_defaults.conf   # Default Discourse config
│   ├── database.yml              # Database configuration
│   ├── puma.rb                   # Puma server config
│   ├── routes.rb                 # Rails routes
│   └── environments/             # Environment-specific configs
│
├── db/                           # Database files
│   ├── migrate/                  # Database migrations
│   └── post_migrate/             # Post-migration scripts
│
├── docker/                       # Docker configuration
│   ├── compose/                  # Docker Compose files (if needed)
│   ├── nginx/                    # Nginx configuration
│   │   ├── nginx.conf            # Main nginx config
│   │   └── ssl/                  # SSL certificates (not in git)
│   ├── scripts/                  # Deployment scripts
│   │   ├── validate-ssl.sh       # SSL validation
│   │   └── pre-deploy-check.sh   # Pre-deployment checks
│   ├── env.community.app.*       # Environment files (local, dev, test, stage, prod, example)
│   ├── docker-compose.sira-community.app.yml  # Docker Compose configuration
│   └── README.md                 # Docker documentation
│
├── docs/                         # Documentation
│   ├── DEPLOYMENT/               # Deployment documentation
│   │   ├── DEPLOYMENT_READINESS_CHECKLIST.md
│   │   ├── DEPLOYMENT_SUMMARY.md
│   │   ├── DOCKER_DEPLOYMENT_GUIDE.md
│   │   ├── PRODUCTION_GRADE_DEPLOYMENT_PLAN.md
│   │   └── PRODUCTION_GRADE_IMPLEMENTATION_SUMMARY.md
│   ├── INTEGRATION/              # Integration documentation
│   │   └── INTEGRATION_GUIDE.md
│   ├── SECURITY/                 # Security documentation
│   │   └── SECURITY.md
│   ├── INSTALL.md                # Installation guide
│   ├── INSTALL-cloud.md          # Cloud installation
│   ├── INSTALL-email.md          # Email configuration
│   ├── PLUGINS.md                # Plugin documentation
│   ├── TESTING.md                # Testing guide
│   └── ADMIN-QUICK-START-GUIDE.md
│
├── frontend/                     # Ember.js frontend code
│
├── lib/                          # Library code
│
├── log/                          # Application logs (gitignored)
│
├── plugins/                      # Discourse plugins
│
├── public/                       # Public assets
│   ├── assets/                   # Precompiled assets (gitignored)
│   ├── uploads/                  # User uploads (gitignored)
│   └── backups/                  # Database backups (gitignored)
│
├── spec/                         # RSpec tests
│
├── tmp/                          # Temporary files (gitignored)
│
├── themes/                       # Discourse themes
│
├── vendor/                       # Third-party dependencies
│
├── .gitignore                    # Git ignore rules
├── COMMUNITY_GROUND_RULES.md     # Project ground rules
├── PROJECT_STRUCTURE.md          # This file
├── README.md                     # Main project README
├── docker/
│   ├── docker-compose.sira-community.app.yml  # Docker Compose configuration
├── Dockerfile                    # Docker image definition
├── Gemfile                       # Ruby dependencies
├── Gemfile.lock                  # Locked Ruby dependencies
├── package.json                  # Node.js dependencies
├── pnpm-lock.yaml                # Locked Node.js dependencies
└── Rakefile                      # Rake tasks
```

## 📋 File Organization Rules

### Root Directory
**Only essential project-level configuration files should be in root:**
- ✅ `docker/docker-compose.sira-community.app.yml` - Docker Compose configuration
- ✅ `Dockerfile` - Docker image definition
- ✅ `README.md` - Main project documentation
- ✅ `COMMUNITY_GROUND_RULES.md` - Project ground rules
- ✅ `PROJECT_STRUCTURE.md` - This file
- ✅ `Gemfile`, `Gemfile.lock` - Ruby dependencies
- ✅ `package.json`, `pnpm-lock.yaml` - Node.js dependencies
- ✅ `.gitignore` - Git ignore rules
- ✅ `Rakefile` - Rake tasks
- ✅ Configuration files (`.ruby-version`, `eslint.config.mjs`, etc.)

**Documentation files should be organized in `docs/`:**
- ❌ Deployment docs in root → ✅ Move to `docs/DEPLOYMENT/`
- ❌ Integration docs in root → ✅ Move to `docs/INTEGRATION/`
- ❌ Security docs in root → ✅ Move to `docs/SECURITY/`

### Application Code
- **`app/`** - Contains ONLY source code (no logs, no node_modules, no generated files)
- **`config/`** - All configuration files
- **`lib/`** - Library code and utilities
- **`frontend/`** - Ember.js frontend code

### Runtime Files (Gitignored)
- **`log/`** - Application logs
- **`tmp/`** - Temporary files
- **`public/assets/`** - Precompiled assets
- **`public/uploads/`** - User uploads
- **`public/backups/`** - Database backups

### Docker Configuration
- **`docker/`** - All Docker-related files
  - **`docker/nginx/`** - Nginx configuration
  - **`docker/scripts/`** - Deployment and utility scripts
  - **`docker/env.*`** - Environment configuration files

### Documentation
- **`docs/`** - All documentation
  - **`docs/DEPLOYMENT/`** - Deployment guides and checklists
  - **`docs/INTEGRATION/`** - Integration documentation
  - **`docs/SECURITY/`** - Security documentation
  - **`docs/`** - General documentation (installation, testing, etc.)

## 🧹 Cleanup Rules Applied

### Files to Remove/Organize
1. **Documentation files in root** → Move to `docs/` subdirectories
2. **Temporary files** → Clean up `tmp/` directory
3. **Log files** → Clean up `log/` directory
4. **Empty directories** → Remove unused directory structures

### Gitignore Rules
The `.gitignore` file should exclude:
- ✅ Log files (`log/*`)
- ✅ Temporary files (`tmp/*`)
- ✅ Precompiled assets (`public/assets/*`)
- ✅ User uploads (`public/uploads/*`)
- ✅ Database backups (`public/backups/*`)
- ✅ Environment files (`.env`)
- ✅ Production configuration (`config/discourse.conf`)
- ✅ SSL certificates (`docker/nginx/ssl/*`)

## 📚 Documentation Organization

### Deployment Documentation (`docs/DEPLOYMENT/`)
- `DEPLOYMENT_READINESS_CHECKLIST.md`
- `DEPLOYMENT_SUMMARY.md`
- `DOCKER_DEPLOYMENT_GUIDE.md`
- `PRODUCTION_GRADE_DEPLOYMENT_PLAN.md`
- `PRODUCTION_GRADE_IMPLEMENTATION_SUMMARY.md`

### Integration Documentation (`docs/INTEGRATION/`)
- `INTEGRATION_GUIDE.md`
- Integration verification documents

### Security Documentation (`docs/SECURITY/`)
- `SECURITY.md`
- Security assessment reports

### General Documentation (`docs/`)
- `INSTALL.md` - Installation guide
- `INSTALL-cloud.md` - Cloud installation
- `INSTALL-email.md` - Email configuration
- `PLUGINS.md` - Plugin documentation
- `TESTING.md` - Testing guide
- `ADMIN-QUICK-START-GUIDE.md` - Admin guide

## 🔒 Security Files

### Production Configuration
- **`config/discourse.conf.example`** - Template (committed)
- **`config/discourse.conf`** - Production config (gitignored)

### SSL Certificates
- **`docker/nginx/ssl/`** - SSL certificates (gitignored, mounted from infrastructure)

### Environment Files
- **`docker/env.*`** - Environment templates (committed)
- **`.env`** - Local environment file (gitignored)

## 🚀 Quick Reference

### Where to Find Things

| What | Where |
|------|-------|
| Application code | `app/` |
| Configuration | `config/` |
| Database migrations | `db/migrate/` |
| Docker config | `docker/` |
| Deployment docs | `docs/DEPLOYMENT/` |
| Integration docs | `docs/INTEGRATION/` |
| Security docs | `docs/SECURITY/` |
| Frontend code | `frontend/` |
| Plugins | `plugins/` |
| Tests | `spec/` |
| Logs | `log/` (gitignored) |
| Temporary files | `tmp/` (gitignored) |

## ✅ Organization Checklist

- [x] Root directory contains only essential config files
- [x] Documentation organized in `docs/` subdirectories
- [x] Docker files organized in `docker/` directory
- [x] Application code in `app/` directory
- [x] Configuration in `config/` directory
- [x] Runtime files properly gitignored
- [x] Project structure documented

---

**Last Updated**: January 2025  
**Status**: ✅ Organized according to ground rules

