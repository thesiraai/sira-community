# Detailed Upgrade Steps: Beta to Stable v2025.11.0

## Current Status
- **Current Version**: 3.6.0.beta3-latest (Beta)
- **Target Version**: v2025.11.0 (Latest Stable)
- **Branch**: main
- **Uncommitted Changes**: Yes (need to handle)

---

## STEP 1: Backup Current State

```powershell
# Create backup branch with timestamp
git branch backup-before-upgrade-$(Get-Date -Format "yyyyMMdd-HHmmss")

# Verify backup created
git branch | Select-String "backup"
```

---

## STEP 2: Commit Your Customizations

**IMPORTANT**: Commit your changes before upgrading to preserve your customizations.

```powershell
# Review what will be committed
git status

# Add all your customizations
git add .

# Commit with descriptive message
git commit -m "WIP: Preserve customizations before upgrading to v2025.11.0

Customizations include:
- Production-grade Dockerfile improvements
- SSL certificate configurations  
- Docker Compose configurations
- Environment setup files
- Custom deployment scripts
- Database and Redis configurations
"

# Verify commit
git log --oneline -1
```

---

## STEP 3: Add Discourse Upstream Remote

```powershell
# Add Discourse official repository as upstream
git remote add upstream https://github.com/discourse/discourse.git

# Verify remotes
git remote -v

# Should show:
# origin    https://github.com/thesiraai/sira-community.git (fetch)
# origin    https://github.com/thesiraai/sira-community.git (push)
# upstream  https://github.com/discourse/discourse.git (fetch)
# upstream  https://github.com/discourse/discourse.git (push)
```

---

## STEP 4: Fetch Latest Tags from Discourse

```powershell
# Fetch all tags from Discourse upstream
git fetch upstream --tags

# List available stable versions
git tag -l | Select-String -Pattern "^(v2025\.|v3\.5\.)" | Sort-Object

# Verify v2025.11.0 exists
git tag -l | Select-String "v2025.11.0"
```

---

## STEP 5: Checkout Stable Version

```powershell
# Checkout the latest stable version
git checkout v2025.11.0

# Verify you're on the right version
git describe --tags

# Should show: v2025.11.0

# Verify version string in code
Select-String -Path "lib/version.rb" -Pattern "STRING ="
```

---

## STEP 6: Merge Your Customizations

```powershell
# Merge your customizations from main branch
git merge main --no-ff -m "Merge SIRA customizations into v2025.11.0"

# If conflicts occur, you'll see:
# "Automatic merge failed; fix conflicts and then commit the result."
```

---

## STEP 7: Resolve Merge Conflicts (If Any)

**If conflicts occur**, resolve them file by file:

```powershell
# See which files have conflicts
git status

# For each conflicted file, open it and resolve:
# Look for markers: <<<<<<< ======= >>>>>>>
# Keep your customizations where needed
# Keep Discourse updates where appropriate
```

**Conflict Resolution Strategy:**

| File Type | Action |
|-----------|--------|
| `Dockerfile` | **Keep your customizations** - Your production-grade improvements |
| `docker-entrypoint.sh` | **Keep your customizations** - Your SSL/certificate handling |
| `docker/docker-compose.sira-community.app.yml` | **Keep your customizations** - Your deployment config |
| `config/environments/production.rb` | **Merge carefully** - Keep your settings, accept Discourse updates |
| `db/fixtures/001_refresh.rb` | **Keep your customizations** - Your site initialization |
| `lib/version.rb` | **Accept Discourse version** - Must be v2025.11.0 |
| Core Discourse files (`app/`, `lib/` except your mods) | **Accept Discourse updates** |

**After resolving each file:**
```powershell
git add <resolved-file>
```

**After all conflicts resolved:**
```powershell
git commit -m "Resolve merge conflicts: preserve SIRA customizations in v2025.11.0"
```

---

## STEP 8: Verify Upgrade Success

```powershell
# 1. Check version
Select-String -Path "lib/version.rb" -Pattern "STRING ="
# Should show: STRING = "2025.11.0" or similar

# 2. Verify key files exist
Test-Path "Dockerfile"
Test-Path "docker/docker-compose.sira-community.app.yml"
Test-Path "docker-entrypoint.sh"

# 3. Check git status is clean
git status
# Should show: "nothing to commit, working tree clean"
```

---

## STEP 9: Clean Build Environment

```powershell
# Stop any running containers
docker compose -f docker/docker-compose.sira-community.app.yml down -v

# Clean Docker build cache (optional, but recommended for clean build)
docker builder prune -f

# Remove old images (optional)
docker image prune -f
```

---

## STEP 10: Build with Stable Version

```powershell
# Build the application
docker compose -f docker/docker-compose.sira-community.app.yml build app

# Monitor output for:
# ✓ "Prebuilt assets downloaded and extracted successfully" (no 404 errors)
# ✓ "✓ Ember CLI assets verified"
# ✓ "✓ Asset processor verified"  
# ✓ "✓ Critical assets verified"
# ✓ "=== Asset compilation completed successfully ==="
```

**Expected Success Indicators:**
- ✅ No 404 errors when downloading prebuilt assets
- ✅ No ember-this-fallback errors
- ✅ Asset compilation completes successfully
- ✅ All verification steps pass

---

## STEP 11: Verify Build Success

```powershell
# Check build output for errors
docker compose -f docker/docker-compose.sira-community.app.yml build app 2>&1 | Select-String -Pattern "ERROR|✓|Prebuilt assets|completed successfully"

# If build succeeds, you should see:
# - "Prebuilt assets downloaded and extracted successfully"
# - Multiple "✓" checkmarks
# - "=== Asset compilation completed successfully ==="
```

---

## STEP 12: Update Main Branch (After Successful Build)

**Option A: Merge stable into main**
```powershell
# Switch back to main
git checkout main

# Merge the stable version
git merge v2025.11.0 --no-ff -m "Upgrade to stable v2025.11.0 with SIRA customizations"

# Push to remote
git push origin main
```

**Option B: Create new stable branch (Recommended)**
```powershell
# Create a new branch for stable version
git checkout -b stable-v2025.11.0

# Push to remote
git push origin stable-v2025.11.0

# Also update main if desired
git checkout main
git merge stable-v2025.11.0 --no-ff -m "Upgrade main to stable v2025.11.0"
git push origin main
```

---

## STEP 13: Tag Your Stable Version

```powershell
# Create a tag for your customized stable version
git tag -a sira-community-v2025.11.0 -m "SIRA Community v2025.11.0 with customizations"

# Push tag to remote
git push origin sira-community-v2025.11.0
```

---

## STEP 14: Test Application

```powershell
# Start the application
docker compose -f docker/docker-compose.sira-community.app.yml up -d

# Check logs
docker compose -f docker/docker-compose.sira-community.app.yml logs app --tail=50

# Test health endpoint
curl -k https://localhost:8443/srv/status

# Test main page
curl -k https://localhost:8443/
```

---

## Rollback Plan (If Issues Occur)

```powershell
# Return to backup branch
git checkout backup-before-upgrade-YYYYMMDD-HHmmss

# Or return to main before upgrade
git checkout main
git reset --hard HEAD~1  # Only if you committed in Step 2
```

---

## Quick Reference: All Commands in Sequence

```powershell
# 1. Backup
git branch backup-before-upgrade-$(Get-Date -Format "yyyyMMdd-HHmmss")

# 2. Commit changes
git add .
git commit -m "WIP: Preserve customizations before upgrading to v2025.11.0"

# 3. Add upstream
git remote add upstream https://github.com/discourse/discourse.git

# 4. Fetch tags
git fetch upstream --tags

# 5. Checkout stable
git checkout v2025.11.0

# 6. Merge customizations
git merge main --no-ff -m "Merge SIRA customizations into v2025.11.0"

# 7. Resolve conflicts (if any)
# Edit conflicted files, then:
git add <resolved-files>
git commit -m "Resolve merge conflicts"

# 8. Clean build
docker compose -f docker/docker-compose.sira-community.app.yml down -v
docker builder prune -f

# 9. Build
docker compose -f docker/docker-compose.sira-community.app.yml build app

# 10. Verify and tag
git checkout -b stable-v2025.11.0
git tag -a sira-community-v2025.11.0 -m "SIRA Community v2025.11.0"
git push origin stable-v2025.11.0 sira-community-v2025.11.0
```

---

## Troubleshooting

### Issue: "fatal: 'upstream' already exists"
```powershell
# Update existing upstream
git remote set-url upstream https://github.com/discourse/discourse.git
```

### Issue: "error: pathspec 'v2025.11.0' did not match any file(s)"
```powershell
# Fetch tags again
git fetch upstream --tags --force

# List available tags
git tag -l | Select-String "2025.11"
```

### Issue: "Merge conflicts in many files"
- Focus on preserving your customizations in Dockerfile, docker-compose, entrypoint
- Accept Discourse updates in core files
- Use `git checkout --theirs <file>` to accept Discourse version
- Use `git checkout --ours <file>` to keep your version

### Issue: "Build still fails after upgrade"
```powershell
# Verify version
Select-String -Path "lib/version.rb" -Pattern "STRING ="

# Clean rebuild
docker compose -f docker/docker-compose.sira-community.app.yml build --no-cache app
```

---

## Success Criteria

✅ Version is v2025.11.0  
✅ Prebuilt assets download successfully  
✅ No ember-this-fallback errors  
✅ Asset compilation completes  
✅ Docker build succeeds  
✅ Application starts successfully  
✅ All customizations preserved  

---

## Next Steps After Successful Upgrade

1. ✅ Test thoroughly in local environment
2. ✅ Update documentation
3. ✅ Deploy to staging
4. ✅ Monitor for issues
5. ✅ Deploy to production

