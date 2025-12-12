# Clean Start Execution Plan: v2025.11.0

## Strategy
Fork clean from Discourse v2025.11.0, then selectively apply only essential SIRA customizations.

---

## PHASE 1: Preparation (5 minutes)

### Step 1.1: Backup Current State
```powershell
# Create timestamped backup branch
$backupBranch = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git branch $backupBranch

# Commit any uncommitted work to backup
git add .
git commit -m "Backup: Current state before clean start from v2025.11.0" -m "This backup preserves all current customizations for reference"

# Push backup to remote
git push origin $backupBranch

# Verify backup
git branch | Select-String "backup"
```

### Step 1.2: Add Discourse Upstream
```powershell
# Add Discourse official repository
git remote add upstream https://github.com/discourse/discourse.git

# Verify remotes
git remote -v
# Should show: origin (your fork) and upstream (Discourse)
```

### Step 1.3: Fetch Latest Tags
```powershell
# Fetch all tags from Discourse
git fetch upstream --tags

# Verify v2025.11.0 exists
git tag -l | Select-String "v2025.11.0"
# Should show: v2025.11.0
```

---

## PHASE 2: Create Clean Fork (2 minutes)

### Step 2.1: Create Clean Branch from Stable
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

## PHASE 3: Apply Essential Customizations (15-30 minutes)

### Step 3.1: Create Directory Structure
```powershell
# Create docker directory structure
New-Item -ItemType Directory -Force -Path "docker/scripts"
New-Item -ItemType Directory -Force -Path "docker/nginx"

# Verify
Get-ChildItem docker -Recurse -Directory
```

### Step 3.2: Copy Essential Files from Backup

**A. Copy Docker Compose Configuration**
```powershell
# Copy docker-compose file
git checkout $backupBranch -- docker/docker-compose.sira-community.app.yml

# Verify
Test-Path "docker/docker-compose.sira-community.app.yml"
```

**B. Copy Environment Configuration**
```powershell
# Copy environment file
git checkout $backupBranch -- docker/env.community.app.local

# Verify
Test-Path "docker/env.community.app.local"
```

**C. Copy Docker Entrypoint**
```powershell
# Copy entrypoint script
git checkout $backupBranch -- docker-entrypoint.sh

# Make executable
git update-index --chmod=+x docker-entrypoint.sh

# Verify
Test-Path "docker-entrypoint.sh"
```

**D. Copy Production-Grade Dockerfile**
```powershell
# Copy your improved Dockerfile
git checkout $backupBranch -- Dockerfile

# Verify
Test-Path "Dockerfile"
```

**E. Copy Nginx Configuration (if customized)**
```powershell
# Copy nginx config if you have customizations
git checkout $backupBranch -- docker/nginx/nginx.conf 2>$null || echo "Nginx config not in backup or using defaults"

# Verify if copied
Test-Path "docker/nginx/nginx.conf"
```

### Step 3.3: Review and Copy Config Files (If Needed)

**Review these files - only copy if you customized them:**

```powershell
# Database config (only if customized)
git checkout $backupBranch -- config/database.yml 2>$null || echo "Using Discourse default"

# Production environment (only if customized)
git checkout $backupBranch -- config/environments/production.rb 2>$null || echo "Using Discourse default"

# Site initialization (only if customized)
git checkout $backupBranch -- db/fixtures/001_refresh.rb 2>$null || echo "Using Discourse default"
```

### Step 3.4: Verify Files Copied
```powershell
# Check what was copied
git status

# Should show:
# - docker/docker-compose.sira-community.app.yml (new)
# - docker/env.community.app.local (new)
# - docker-entrypoint.sh (new)
# - Dockerfile (new)
# - docker/nginx/nginx.conf (new, if copied)
```

---

## PHASE 4: First Build Test (10-15 minutes)

### Step 4.1: Clean Build Environment
```powershell
# Stop any running containers
docker compose -f docker/docker-compose.sira-community.app.yml down -v 2>$null

# Clean Docker build cache
docker builder prune -f

# Optional: Remove old images
docker image prune -f
```

### Step 4.2: Build with Minimal Customizations
```powershell
# Build the application
docker compose -f docker/docker-compose.sira-community.app.yml build app

# Monitor for:
# ✓ "Prebuilt assets downloaded and extracted successfully" (no 404 errors)
# ✓ "✓ Ember CLI assets verified"
# ✓ "✓ Asset processor verified"
# ✓ "✓ Critical assets verified"
# ✓ "=== Asset compilation completed successfully ==="
```

### Step 4.3: Verify Build Success
```powershell
# Check build output
docker compose -f docker/docker-compose.sira-community.app.yml build app 2>&1 | Select-String -Pattern "ERROR|✓|Prebuilt assets|completed successfully" | Select-Object -Last 20

# Expected: No ERROR messages, multiple ✓ checkmarks
```

---

## PHASE 5: Commit Clean State (2 minutes)

### Step 5.1: Commit Essential Customizations
```powershell
# Stage all copied files
git add docker/ Dockerfile docker-entrypoint.sh

# Commit
git commit -m "Initial: Clean fork from v2025.11.0 with essential SIRA customizations

Essential customizations:
- Production-grade Dockerfile with strict verification
- Docker Compose configuration for SIRA infrastructure
- SSL certificate handling in entrypoint
- Environment configuration files
- Nginx configuration (if customized)

This is a clean start from stable v2025.11.0, avoiding beta version issues.
"

# Verify commit
git log --oneline -1
```

### Step 5.2: Tag Clean Version
```powershell
# Create tag
git tag -a sira-community-v2025.11.0-clean -m "Clean SIRA Community v2025.11.0 - Production Ready"

# Verify tag
git tag -l | Select-String "sira-community"
```

---

## PHASE 6: Push to Remote (1 minute)

### Step 6.1: Push Branch and Tag
```powershell
# Push branch
git push origin sira-community-v2025.11.0

# Push tag
git push origin sira-community-v2025.11.0-clean

# Verify on remote
git ls-remote --tags origin | Select-String "sira-community"
```

---

## PHASE 7: Test Application (5 minutes)

### Step 7.1: Start Application
```powershell
# Start services
docker compose -f docker/docker-compose.sira-community.app.yml up -d

# Check logs
docker compose -f docker/docker-compose.sira-community.app.yml logs app --tail=50
```

### Step 7.2: Verify Application
```powershell
# Test health endpoint
curl -k https://localhost:8443/srv/status

# Test main page
curl -k https://localhost:8443/ | Select-String -Pattern "title|SIRA|Discourse" | Select-Object -First 3
```

---

## PHASE 8: Update Main Branch (Optional)

### Step 8.1: Update Main to Use Stable
```powershell
# Option A: Merge stable into main
git checkout main
git merge sira-community-v2025.11.0 --no-ff -m "Upgrade main to stable v2025.11.0"
git push origin main

# Option B: Keep main as-is, use stable branch for production
# (Recommended - keeps main for reference)
```

---

## Quick Reference: All Commands

```powershell
# === PHASE 1: Preparation ===
$backupBranch = "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
git branch $backupBranch
git add . && git commit -m "Backup before clean start"
git push origin $backupBranch
git remote add upstream https://github.com/discourse/discourse.git
git fetch upstream --tags

# === PHASE 2: Create Clean Fork ===
git checkout -b sira-community-v2025.11.0 upstream/v2025.11.0

# === PHASE 3: Apply Essential Customizations ===
New-Item -ItemType Directory -Force -Path "docker/scripts","docker/nginx"
git checkout $backupBranch -- docker/docker-compose.sira-community.app.yml
git checkout $backupBranch -- docker/env.community.app.local
git checkout $backupBranch -- docker-entrypoint.sh
git checkout $backupBranch -- Dockerfile
git update-index --chmod=+x docker-entrypoint.sh
git checkout $backupBranch -- docker/nginx/nginx.conf 2>$null

# === PHASE 4: Build Test ===
docker compose -f docker/docker-compose.sira-community.app.yml down -v
docker builder prune -f
docker compose -f docker/docker-compose.sira-community.app.yml build app

# === PHASE 5: Commit ===
git add docker/ Dockerfile docker-entrypoint.sh
git commit -m "Initial: Clean v2025.11.0 with essential SIRA customizations"
git tag -a sira-community-v2025.11.0-clean -m "Clean SIRA Community v2025.11.0"

# === PHASE 6: Push ===
git push origin sira-community-v2025.11.0 sira-community-v2025.11.0-clean

# === PHASE 7: Test ===
docker compose -f docker/docker-compose.sira-community.app.yml up -d
curl -k https://localhost:8443/srv/status
```

---

## Essential Files Summary

### Must Copy (Critical):
1. ✅ `Dockerfile` - Production-grade build
2. ✅ `docker-entrypoint.sh` - SSL/certificate handling
3. ✅ `docker/docker-compose.sira-community.app.yml` - Deployment config
4. ✅ `docker/env.community.app.local` - Environment variables

### Review & Copy If Customized:
5. ⚠️ `docker/nginx/nginx.conf` - Nginx config
6. ⚠️ `config/database.yml` - Database config
7. ⚠️ `config/environments/production.rb` - Production settings
8. ⚠️ `db/fixtures/001_refresh.rb` - Site initialization

### Don't Copy (Use Discourse Defaults):
- ❌ Core Discourse files (`app/`, `lib/`, `frontend/`)
- ❌ Dependencies (`Gemfile`, `package.json`)
- ❌ Documentation (update later)
- ❌ Temporary files

---

## Success Criteria

✅ Clean codebase from v2025.11.0  
✅ Only essential files copied  
✅ Prebuilt assets download successfully  
✅ Build completes without errors  
✅ Application starts successfully  
✅ All SIRA infrastructure integrations work  

---

## Troubleshooting

### Issue: "Cannot checkout from backup branch"
```powershell
# Use full branch name
git checkout backup-YYYYMMDD-HHmmss -- <file>

# Or copy manually from file system
```

### Issue: "Build fails after copying files"
```powershell
# Check file syntax
docker compose -f docker/docker-compose.sira-community.app.yml config

# Review differences from Discourse default
git diff upstream/v2025.11.0 -- <file>
```

### Issue: "Files missing after checkout"
```powershell
# This is expected - you're starting clean
# Copy files one by one and test after each
```

---

## Next Steps After Clean Start

1. ✅ Test thoroughly
2. ✅ Document what was kept and why
3. ✅ Create upgrade path for future versions
4. ✅ Set up CI/CD
5. ✅ Deploy to staging
6. ✅ Deploy to production

---

## Notes

- Start minimal, add incrementally
- Test after each addition
- Keep codebase as clean as possible
- Document all customizations
- This approach avoids beta version issues

