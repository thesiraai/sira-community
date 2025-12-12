# Essential Files Checklist for Clean Start

## Purpose
This checklist helps identify which files from your current setup are essential and must be copied to the clean v2025.11.0 fork.

---

## Critical Files (Must Copy)

### 1. Docker Configuration Files

#### `Dockerfile`
**Status**: ✅ ESSENTIAL  
**Reason**: Production-grade build with strict verification  
**Action**: Copy your improved Dockerfile or create minimal version based on it

#### `docker-entrypoint.sh`
**Status**: ✅ ESSENTIAL  
**Reason**: SSL certificate handling, user switching, asset processor backup  
**Action**: Copy as-is

#### `docker/docker-compose.sira-community.app.yml`
**Status**: ✅ ESSENTIAL  
**Reason**: Complete deployment configuration  
**Action**: Copy as-is

#### `docker/env.community.app.local`
**Status**: ✅ ESSENTIAL  
**Reason**: Environment variables for local deployment  
**Action**: Copy as-is

---

### 2. Application Configuration

#### `config/database.yml`
**Status**: ⚠️ REVIEW  
**Reason**: May have SIRA-specific database settings  
**Action**: Compare with Discourse default, copy only if customized

#### `config/environments/production.rb`
**Status**: ⚠️ REVIEW  
**Reason**: May have production optimizations  
**Action**: Compare with Discourse default, merge carefully

#### `db/fixtures/001_refresh.rb`
**Status**: ⚠️ REVIEW  
**Reason**: Site initialization customizations  
**Action**: Check if needed, may not be required in stable version

---

### 3. Nginx Configuration

#### `docker/nginx/nginx.conf`
**Status**: ⚠️ REVIEW  
**Reason**: SSL, proxy settings  
**Action**: Copy if customized, otherwise Discourse default may work

---

### 4. Scripts

#### `docker/scripts/*.sh`
**Status**: ⚠️ OPTIONAL  
**Reason**: Deployment automation  
**Action**: Copy if actively used, otherwise skip

#### `docker/scripts/*.ps1`
**Status**: ⚠️ OPTIONAL  
**Reason**: PowerShell automation  
**Action**: Copy if actively used, otherwise skip

---

## Files to Review (Not Essential)

### Documentation
- `README.md` - Update later
- `docker/README.md` - Update later
- All `*.md` files in `docs/` - Review and update as needed

### Temporary Files
- `tmp_*.rb` - Delete (temporary investigation files)
- `temp/` directory - Review and delete if not needed

### Beta Workarounds
- Any files with "beta" or "workaround" in comments
- Files that were added to fix beta-specific issues

---

## Files to NOT Copy (Discourse Defaults)

### Core Discourse Files
- `app/` - Use Discourse defaults
- `lib/` - Use Discourse defaults (except your customizations)
- `config/routes.rb` - Use Discourse defaults
- `config/application.rb` - Use Discourse defaults
- `frontend/` - Use Discourse defaults

### Dependencies
- `Gemfile` - Use Discourse defaults
- `package.json` - Use Discourse defaults
- `pnpm-lock.yaml` - Use Discourse defaults

---

## Copy Strategy

### Method 1: Selective Copy from Backup Branch
```powershell
# After creating clean branch, copy specific files:
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/docker-compose.sira-community.app.yml
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker-entrypoint.sh
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/env.community.app.local
# etc.
```

### Method 2: Manual Copy
```powershell
# Copy files manually from backup or file system
# More control, but more work
```

### Method 3: Create from Scratch
```powershell
# Start with Discourse defaults
# Add only what's needed
# Best for understanding what's actually required
```

---

## Verification After Copy

For each file copied, verify:

1. **Syntax Check**
   ```powershell
   # Dockerfile
   docker build --dry-run -f Dockerfile .
   
   # docker-compose
   docker compose -f docker/docker-compose.sira-community.app.yml config
   
   # Shell scripts
   bash -n docker-entrypoint.sh
   ```

2. **Functionality Check**
   ```powershell
   # Build test
   docker compose -f docker/docker-compose.sira-community.app.yml build app
   ```

3. **Version Compatibility**
   - Ensure file works with v2025.11.0
   - Check for deprecated features
   - Verify API compatibility

---

## Priority Order for Copying

1. **First Priority** (Core deployment):
   - `docker/docker-compose.sira-community.app.yml`
   - `docker/env.community.app.local`
   - `Dockerfile`

2. **Second Priority** (Runtime):
   - `docker-entrypoint.sh`
   - `docker/nginx/nginx.conf` (if customized)

3. **Third Priority** (Configuration):
   - `config/database.yml` (if customized)
   - `config/environments/production.rb` (if customized)

4. **Fourth Priority** (Scripts):
   - Deployment scripts (if actively used)

5. **Last Priority** (Documentation):
   - Update documentation after everything works

---

## Files Comparison Template

For each file, document:

```markdown
### File: [filename]

**Source**: Backup branch / Manual creation
**Essential**: Yes / No / Review
**Changes from Discourse default**: [List changes]
**Reason for keeping**: [Why it's needed]
**Test status**: [ ] Not tested / [ ] Tested / [ ] Verified
```

---

## Quick Copy Commands

```powershell
# After creating clean branch, run these to copy essential files:

# Core Docker files
git checkout backup-current-state-YYYYMMDD-HHmmss -- Dockerfile
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker-entrypoint.sh
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/docker-compose.sira-community.app.yml
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/env.community.app.local

# Create docker directory if needed
New-Item -ItemType Directory -Force -Path "docker/scripts"
New-Item -ItemType Directory -Force -Path "docker/nginx"

# Nginx config (if customized)
git checkout backup-current-state-YYYYMMDD-HHmmss -- docker/nginx/nginx.conf

# Config files (review first)
git checkout backup-current-state-YYYYMMDD-HHmmss -- config/database.yml
git checkout backup-current-state-YYYYMMDD-HHmmss -- config/environments/production.rb

# Verify what was copied
git status
```

---

## Notes

- Start minimal, add incrementally
- Test after each addition
- Document why each file is needed
- Remove anything that's not actually required
- Keep the codebase as clean as possible

