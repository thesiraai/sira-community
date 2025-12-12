# Clean Start Plan: Fork from v2025.11.0

## Strategy
Start completely fresh from Discourse v2025.11.0 stable release, then selectively apply only essential SIRA customizations.

## Benefits
- ✅ Clean codebase without beta version issues
- ✅ No merge conflicts from beta changes
- ✅ Only essential customizations applied
- ✅ Easier to maintain and upgrade in future
- ✅ Production-grade from the start

---

## PHASE 1: Preparation & Analysis

### STEP 1: Document Current Customizations
**Goal**: Identify what's actually needed vs. what was added for beta workarounds

```powershell
# Create a list of your custom files
Get-ChildItem -Recurse -File | Where-Object { 
    $_.FullName -match "docker|SIRA|sira|community" -or
    $_.Name -match "docker-compose|docker-entrypoint|\.env\.|\.local\."
} | Select-Object FullName | Out-File current-customizations.txt

# Review what you have
cat current-customizations.txt
```

### STEP 2: Categorize Customizations
**Essential (Must Keep)**:
- Docker Compose configuration (`docker/docker-compose.sira-community.app.yml`)
- Environment files (`docker/env.community.app.local`)
- SSL certificate handling in entrypoint
- Database/Redis connection configurations
- SIRA-specific branding/configurations

**Optional (Review Later)**:
- Documentation files
- Temporary test files
- Beta-specific workarounds
- Debug scripts

---

## PHASE 2: Create Clean Fork

### STEP 3: Backup Current Work
```powershell
# Create a backup of current state
git branch backup-current-state-$(Get-Date -Format "yyyyMMdd-HHmmss")

# Commit any uncommitted work to backup
git add .
git commit -m "Backup: Current state before clean start from v2025.11.0" || echo "No changes to commit"

# Push backup to remote
git push origin backup-current-state-$(Get-Date -Format "yyyyMMdd-HHmmss")
```

### STEP 4: Add Discourse Upstream
```powershell
# Add Discourse official repository
git remote add upstream https://github.com/discourse/discourse.git

# Verify
git remote -v
```

### STEP 5: Fetch Latest Tags
```powershell
# Fetch all tags from Discourse
git fetch upstream --tags

# Verify v2025.11.0 exists
git tag -l | Select-String "v2025.11.0"

# Should show: v2025.11.0
```

### STEP 6: Create Clean Branch from Stable
```powershell
# Create new branch from clean stable version
git checkout -b sira-community-v2025.11.0 upstream/v2025.11.0

# Verify you're on clean stable
git describe --tags
# Should show: v2025.11.0

# Verify version in code
Select-String -Path "lib/version.rb" -Pattern "STRING ="
# Should show: STRING = "2025.11.0" or similar

# Check status (should be clean)
git status
# Should show: "nothing to commit, working tree clean"
```

---

## PHASE 3: Apply Essential Customizations

### STEP 7: Create SIRA Directory Structure
```powershell
# Create docker directory structure
New-Item -ItemType Directory -Force -Path "docker/scripts"
New-Item -ItemType Directory -Force -Path "docker/nginx"

# Verify structure
Get-ChildItem docker -Recurse -Directory
```

### STEP 8: Copy Essential Files (One by One)

**A. Docker Compose Configuration**
```powershell
# Copy your docker-compose file
# (You'll need to manually copy from backup or recreate)
# File: docker/docker-compose.sira-community.app.yml
```

**B. Environment Configuration**
```powershell
# Copy environment file
# File: docker/env.community.app.local
```

**C. Docker Entrypoint**
```powershell
# Copy entrypoint script
# File: docker-entrypoint.sh
```

**D. Nginx Configuration**
```powershell
# Copy nginx config if you have customizations
# File: docker/nginx/nginx.conf
```

### STEP 9: Create Minimal Dockerfile
**Strategy**: Start with Discourse's base, add only SIRA essentials

```powershell
# Check if Discourse has a Dockerfile
Test-Path "Dockerfile"

# If not, create one based on your production-grade version
# But start minimal and add only what's needed
```

### STEP 10: Apply Database/Redis Configurations
```powershell
# Copy database.yml if customized
# File: config/database.yml

# Copy any Redis configurations
# Review: config/redis.yml (if exists)
```

---

## PHASE 4: Incremental Testing

### STEP 11: Test Each Component
```powershell
# Test 1: Verify version
Select-String -Path "lib/version.rb" -Pattern "STRING ="

# Test 2: Verify Dockerfile syntax
docker build --dry-run -f Dockerfile . 2>&1 | Select-String "ERROR"

# Test 3: Verify docker-compose syntax
docker compose -f docker/docker-compose.sira-community.app.yml config 2>&1 | Select-String "ERROR"
```

### STEP 12: First Build Test
```powershell
# Clean environment
docker compose -f docker/docker-compose.sira-community.app.yml down -v
docker builder prune -f

# Build with minimal customizations
docker compose -f docker/docker-compose.sira-community.app.yml build app

# Monitor for:
# ✓ Prebuilt assets download successfully
# ✓ No ember-this-fallback errors
# ✓ Build completes successfully
```

### STEP 13: Add Customizations Incrementally
**Add one customization at a time, test after each:**

1. **First**: Basic Docker setup (Dockerfile, docker-compose)
2. **Second**: Environment variables
3. **Third**: SSL/certificate handling
4. **Fourth**: Database configurations
5. **Fifth**: Any SIRA-specific features

**After each addition:**
```powershell
# Test build
docker compose -f docker/docker-compose.sira-community.app.yml build app

# If successful, commit
git add .
git commit -m "Add: [Description of what was added]"
```

---

## PHASE 5: Essential Files Checklist

### Must-Have Files (Copy from Backup)

#### Docker Configuration
- [ ] `Dockerfile` - Production-grade build
- [ ] `docker-entrypoint.sh` - SSL/certificate handling
- [ ] `docker/docker-compose.sira-community.app.yml` - Main compose file
- [ ] `docker/env.community.app.local` - Environment variables
- [ ] `docker/nginx/nginx.conf` - Nginx configuration (if customized)

#### Application Configuration
- [ ] `config/database.yml` - Database connection (if customized)
- [ ] `config/environments/production.rb` - Production settings (if customized)
- [ ] `db/fixtures/001_refresh.rb` - Site initialization (if customized)

#### Scripts
- [ ] `docker/scripts/*.sh` - Deployment scripts (if needed)
- [ ] `docker/scripts/*.ps1` - PowerShell scripts (if needed)

### Optional Files (Review & Decide)

#### Documentation
- [ ] `README.md` - Update with SIRA-specific info
- [ ] `docker/README.md` - Deployment docs
- [ ] Any SIRA-specific documentation

#### Other
- [ ] `.dockerignore` - If customized
- [ ] `.gitignore` - If customized
- [ ] Any plugin customizations

---

## PHASE 6: Build & Verify

### STEP 14: Final Build
```powershell
# Complete clean build
docker compose -f docker/docker-compose.sira-community.app.yml down -v
docker system prune -f
docker builder prune -f

# Build
docker compose -f docker/docker-compose.sira-community.app.yml build app

# Expected results:
# ✓ Prebuilt assets downloaded
# ✓ No errors
# ✓ All verification steps pass
```

### STEP 15: Verify Application
```powershell
# Start application
docker compose -f docker/docker-compose.sira-community.app.yml up -d

# Check logs
docker compose -f docker/docker-compose.sira-community.app.yml logs app --tail=50

# Test endpoints
curl -k https://localhost:8443/srv/status
curl -k https://localhost:8443/
```

### STEP 16: Commit Clean State
```powershell
# Commit clean stable version with essential customizations
git add .
git commit -m "Initial: Clean fork from v2025.11.0 with essential SIRA customizations

Essential customizations:
- Production-grade Dockerfile
- Docker Compose configuration
- SSL certificate handling
- Environment configuration
- Database/Redis configurations
"

# Tag the clean version
git tag -a sira-community-v2025.11.0-clean -m "Clean SIRA Community v2025.11.0"

# Push to remote
git push origin sira-community-v2025.11.0
git push origin sira-community-v2025.11.0-clean
```

---

## PHASE 7: Comparison & Validation

### STEP 17: Compare with Backup
```powershell
# Compare your clean version with backup
git diff backup-current-state-YYYYMMDD-HHmmss..sira-community-v2025.11.0 --stat

# Review what was removed (beta workarounds, etc.)
# Review what was kept (essential customizations)
```

### STEP 18: Document Differences
```powershell
# Create a document listing:
# - What was removed (beta workarounds)
# - What was kept (essential customizations)
# - What was added (new from stable)
```

---

## Quick Reference: All Steps

```powershell
# PHASE 1: Preparation
git branch backup-current-state-$(Get-Date -Format "yyyyMMdd-HHmmss")
git add . && git commit -m "Backup before clean start"
git remote add upstream https://github.com/discourse/discourse.git
git fetch upstream --tags

# PHASE 2: Create Clean Fork
git checkout -b sira-community-v2025.11.0 upstream/v2025.11.0

# PHASE 3: Apply Essential Customizations
# Manually copy essential files:
# - docker/docker-compose.sira-community.app.yml
# - docker/env.community.app.local
# - docker-entrypoint.sh
# - Dockerfile (or create minimal one)
# - config files if customized

# PHASE 4: Test
docker compose -f docker/docker-compose.sira-community.app.yml build app

# PHASE 5: Commit
git add .
git commit -m "Initial: Clean v2025.11.0 with essential SIRA customizations"
git tag -a sira-community-v2025.11.0-clean -m "Clean SIRA Community v2025.11.0"
git push origin sira-community-v2025.11.0 sira-community-v2025.11.0-clean
```

---

## Essential Customizations Template

### Minimal Dockerfile Requirements
- Multi-stage build
- Node.js 20+ installation
- Ruby 3.3.x
- Asset compilation with verification
- Production optimizations

### Minimal Docker Compose Requirements
- App service
- Sidekiq service (if needed)
- Nginx service (if needed)
- Database connection
- Redis connection
- SSL certificate volumes

### Minimal Entrypoint Requirements
- SSL certificate copying
- User switching
- Asset processor verification
- Environment variable setup

---

## Troubleshooting

### Issue: "Cannot find upstream/v2025.11.0"
```powershell
# Fetch again
git fetch upstream --tags --force

# List available tags
git tag -l | Select-String "2025.11"
```

### Issue: "Files missing after checkout"
```powershell
# This is expected - you're starting clean
# Copy essential files from backup branch:
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/docker-compose.sira-community.app.yml
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker-entrypoint.sh
# etc.
```

### Issue: "Build fails with missing files"
```powershell
# Add files incrementally
# Test after each addition
# Identify minimum required set
```

---

## Success Criteria

✅ Clean codebase from v2025.11.0  
✅ Only essential customizations applied  
✅ Prebuilt assets download successfully  
✅ Build completes without errors  
✅ Application starts successfully  
✅ All SIRA-specific features work  
✅ No beta workarounds needed  

---

## Next Steps After Clean Start

1. ✅ Test thoroughly
2. ✅ Document what customizations were kept
3. ✅ Create upgrade path for future versions
4. ✅ Set up CI/CD if needed
5. ✅ Deploy to staging
6. ✅ Deploy to production

