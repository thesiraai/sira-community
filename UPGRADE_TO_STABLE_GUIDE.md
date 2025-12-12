# Upgrade Guide: Beta to Stable (v2025.11.0)

## Overview
Upgrading from `3.6.0.beta3-latest` to `v2025.11.0` (latest stable release)

## Prerequisites
- Current branch: `main`
- Uncommitted changes: YES (need to handle)
- Remote: `origin` (thesiraai/sira-community)

---

## Step-by-Step Upgrade Process

### STEP 1: Backup Current State
```bash
# Create a backup branch with current state
git branch backup-before-upgrade-$(date +%Y%m%d)

# Verify backup was created
git branch | grep backup
```

### STEP 2: Commit or Stash Current Changes
**Option A: Commit your changes (Recommended if they're important)**
```bash
# Review what you've changed
git status

# Add all your customizations
git add .

# Commit with descriptive message
git commit -m "WIP: Customizations before upgrading to v2025.11.0

- Production-grade Dockerfile improvements
- SSL certificate configurations
- Environment setup modifications
- Custom deployment scripts
"

# Verify commit
git log --oneline -1
```

**Option B: Stash your changes (If you want to review later)**
```bash
# Stash all changes including untracked files
git stash push -u -m "Customizations before v2025.11.0 upgrade"

# Verify stash
git stash list
```

### STEP 3: Fetch Latest Tags from Discourse Repository
```bash
# Add Discourse upstream if not already added
git remote add upstream https://github.com/discourse/discourse.git 2>/dev/null || echo "Upstream already exists"

# Verify remotes
git remote -v

# Fetch all tags from upstream
git fetch upstream --tags

# Also fetch from origin (your fork)
git fetch origin --tags

# List available stable versions
git tag | grep -E "^(v2025\.|v3\.5\.)" | sort -V
```

### STEP 4: Checkout Stable Version
```bash
# Checkout the latest stable version
git checkout v2025.11.0

# Verify version
grep "STRING = " lib/version.rb

# Should show: STRING = "2025.11.0" or similar
```

### STEP 5: Merge Your Customizations (If you committed in Step 2)
```bash
# If you committed changes, merge them into the stable version
git merge main --no-ff -m "Merge customizations into v2025.11.0"

# If conflicts occur, resolve them (see conflict resolution below)
```

### STEP 6: Verify Version and Key Files
```bash
# Check Discourse version
cat lib/version.rb | grep "STRING ="

# Verify Dockerfile exists and is intact
test -f Dockerfile && echo "✓ Dockerfile exists" || echo "✗ Dockerfile missing"

# Verify docker-compose file exists
test -f docker/docker-compose.sira-community.app.yml && echo "✓ Compose file exists" || echo "✗ Compose file missing"

# Check if your custom files are preserved
ls -la docker-entrypoint.sh
ls -la docker/docker-compose.sira-community.app.yml
```

### STEP 7: Handle Merge Conflicts (If Any)
If conflicts occur during merge:

```bash
# List conflicted files
git status | grep "both modified"

# For each conflicted file, review and resolve:
# 1. Open the file
# 2. Look for conflict markers: <<<<<<< ======= >>>>>>>
# 3. Keep your customizations where appropriate
# 4. Keep Discourse updates where appropriate

# After resolving conflicts:
git add <resolved-file>
git commit -m "Resolve merge conflicts with v2025.11.0"
```

**Common files that may have conflicts:**
- `Dockerfile` - Keep your production-grade improvements
- `docker-entrypoint.sh` - Keep your customizations
- `config/environments/production.rb` - Merge carefully
- `db/fixtures/001_refresh.rb` - Keep your customizations
- `docker/docker-compose.sira-community.app.yml` - Keep your customizations

### STEP 8: Update Version Reference (If Needed)
```bash
# Verify the version string is correct
grep "STRING = " lib/version.rb

# If it shows the old beta version, the checkout didn't work properly
# In that case, ensure you're on the right tag:
git checkout v2025.11.0 --force
```

### STEP 9: Clean Build Environment
```bash
# Remove any cached build artifacts
docker compose -f docker/docker-compose.sira-community.app.yml down -v

# Remove old Docker images (optional, saves space)
docker image prune -f

# Clean any local build artifacts
rm -rf tmp/cache/* tmp/pids/* log/* 2>/dev/null || true
```

### STEP 10: Test the Build
```bash
# Build with the new stable version
docker compose -f docker/docker-compose.sira-community.app.yml build app

# Monitor for:
# ✓ Prebuilt assets download successfully (no 404 errors)
# ✓ Ember build completes without ember-this-fallback errors
# ✓ Asset processor builds successfully
# ✓ All verification steps pass
```

### STEP 11: Verify Asset Compilation
```bash
# Check build logs for success indicators
docker compose -f docker/docker-compose.sira-community.app.yml build app 2>&1 | grep -E "✓|ERROR|Prebuilt assets downloaded"

# Expected success indicators:
# - "Prebuilt assets downloaded and extracted successfully"
# - "✓ Ember CLI assets verified"
# - "✓ Asset processor verified"
# - "✓ Critical assets verified"
```

### STEP 12: Update Main Branch (After Successful Build)
```bash
# If build is successful, update your main branch
git checkout main
git merge v2025.11.0 --no-ff -m "Upgrade to stable v2025.11.0"

# Or create a new branch for the stable version
git checkout -b stable-v2025.11.0
git push origin stable-v2025.11.0
```

### STEP 13: Tag Your Stable Version
```bash
# Create a tag for your customized stable version
git tag -a sira-community-v2025.11.0 -m "SIRA Community v2025.11.0 with customizations"

# Push tag to remote
git push origin sira-community-v2025.11.0
```

---

## Rollback Plan (If Issues Occur)

### If build fails or issues arise:
```bash
# Return to your backup branch
git checkout backup-before-upgrade-YYYYMMDD

# Or restore from stash (if you stashed)
git checkout main
git stash pop
```

---

## Post-Upgrade Verification Checklist

- [ ] Version is `v2025.11.0` (check `lib/version.rb`)
- [ ] Prebuilt assets download successfully (no 404 errors)
- [ ] Ember build completes without errors
- [ ] Asset processor builds successfully
- [ ] Docker image builds completely
- [ ] All custom files preserved (Dockerfile, docker-compose, etc.)
- [ ] Application starts successfully
- [ ] Health check endpoint responds

---

## Expected Improvements After Upgrade

1. **Prebuilt Assets Available**: No more 404 errors
2. **No ember-this-fallback Errors**: Stable version has fixes
3. **Faster Builds**: Prebuilt assets = faster compilation
4. **Production Stability**: Stable version is production-tested
5. **Security Updates**: Latest security patches included

---

## Troubleshooting

### Issue: "Tag v2025.11.0 not found"
```bash
# Fetch tags again
git fetch upstream --tags --force
git fetch origin --tags --force

# List all tags
git tag -l | grep "2025.11"
```

### Issue: "Merge conflicts in critical files"
- Keep your customizations in: Dockerfile, docker-compose files, entrypoint
- Accept Discourse updates in: lib/, app/, config/ (unless you customized)

### Issue: "Build still fails after upgrade"
```bash
# Check if you're actually on the right version
git describe --tags

# Verify version string
grep "STRING = " lib/version.rb

# Try clean build
docker compose -f docker/docker-compose.sira-community.app.yml build --no-cache app
```

---

## Next Steps After Successful Upgrade

1. Test the application thoroughly
2. Update documentation with new version
3. Deploy to staging environment
4. Monitor for any issues
5. Deploy to production after validation

---

## Notes

- The upgrade preserves your customizations (Dockerfile, docker-compose, etc.)
- Discourse core files will be updated to v2025.11.0
- Your custom plugins and configurations should remain intact
- Always test in staging before production deployment

