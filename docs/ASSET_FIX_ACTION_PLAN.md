# Asset Fix - Action Plan

## Executive Summary
**Issue:** `Propshaft::MissingAssetError` causing 500 errors on application routes
**Root Cause:** Missing compiled asset files (likely Ember CLI compiled JavaScript)
**Impact:** Application routes fail with 500 errors

---

## Investigation Results

### 1. Missing Asset Identification
**Status:** In Progress
- Error occurs in `script_asset_path` helper
- Likely missing: `start-discourse.js`, `browser-update.js`, or other Ember-compiled assets
- Need to extract exact asset name from error

### 2. Asset Paths Configuration
**Status:** Verified
- Propshaft configured to look in:
  - `public/javascripts/`
  - `frontend/discourse/dist/assets/`
- Propshaft resolves assets at runtime (no manifest.json needed)

### 3. Asset Locations Check
**Status:** Needs Verification
- Check if `frontend/discourse/dist/assets/` exists
- Check if Ember CLI compiled assets are present
- Verify assets are copied to runtime stage

### 4. Docker Build Process
**Status:** Issue Identified
- Dockerfile runs: `assets:precompile:asset_processor` ✓
- Dockerfile runs: `assets:precompile` ✓
- Dockerfile may NOT run: `assets:precompile:build` (Ember CLI) ❓

---

## Root Cause Hypothesis

### Primary Hypothesis: Ember CLI Compilation Not Running
**Evidence:**
- `assets:precompile:build` task runs Ember CLI compilation
- This task creates `frontend/discourse/dist/assets/*.js` files
- Dockerfile may not be calling this task
- Without Ember compilation, `start-discourse.js` and other assets don't exist

### Secondary Hypothesis: Assets Not Copied to Runtime
**Evidence:**
- Assets compiled in builder stage
- May not be copied to runtime stage
- Propshaft can't find assets in runtime container

---

## Action Plan

### Phase 1: Complete Investigation (IMMEDIATE)
**Time:** 15 minutes

1. **Extract exact missing asset name**
   ```bash
   # Run error extraction script in container
   docker exec sira-community-app bundle exec ruby tmp_find_missing_asset.rb
   ```

2. **Check if Ember assets exist**
   ```bash
   # Check for compiled Ember assets
   docker exec sira-community-app ls -la /var/www/community/frontend/discourse/dist/assets/
   ```

3. **Verify Dockerfile asset compilation**
   ```bash
   # Check if assets:precompile:build is in Dockerfile
   grep -n "assets:precompile:build" Dockerfile
   ```

### Phase 2: Fix Implementation (HIGH PRIORITY)
**Time:** 30-60 minutes

#### Option A: If Ember CLI Compilation Missing
1. **Update Dockerfile to run Ember compilation**
   ```dockerfile
   RUN DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
       bundle exec rake assets:precompile:build && \
       bundle exec rake assets:precompile:asset_processor && \
       bundle exec rake assets:precompile
   ```

2. **Ensure Ember CLI dependencies are installed**
   - Verify `node_modules` includes Ember CLI
   - Check `package.json` for Ember dependencies

3. **Verify compiled assets are created**
   ```dockerfile
   RUN test -d frontend/discourse/dist/assets && \
       echo "✓ Ember assets compiled" || \
       (echo "✗ Ember assets missing" && exit 1)
   ```

#### Option B: If Assets Not Copied to Runtime
1. **Copy Ember compiled assets to runtime**
   ```dockerfile
   COPY --from=builder --chown=community:community \
       /var/www/community/frontend/discourse/dist ./frontend/discourse/dist
   ```

2. **Verify asset paths in runtime**
   - Ensure `frontend/discourse/dist/assets` exists
   - Verify Propshaft can access the path

### Phase 3: Testing & Verification (CRITICAL)
**Time:** 15 minutes

1. **Rebuild Docker image**
   ```bash
   docker build -t sira-community:latest -f Dockerfile .
   ```

2. **Deploy and test**
   ```bash
   docker compose -f docker/docker-compose.sira-community.app.yml up -d
   ```

3. **Verify routes work**
   ```bash
   curl http://localhost:3000/finish-installation
   # Should return 200, not 500
   ```

4. **Check for errors**
   ```bash
   docker logs sira-community-app | grep -i error
   ```

---

## Implementation Steps (Detailed)

### Step 1: Verify Missing Asset
```bash
# In container, extract exact error
docker exec sira-community-app bundle exec ruby tmp_find_missing_asset.rb
```

### Step 2: Check Current Asset State
```bash
# Check if Ember assets exist
docker exec sira-community-app find /var/www/community/frontend/discourse/dist -name "*.js" | head -10

# Check asset paths
docker exec sira-community-app bundle exec rails runner 'puts Rails.application.config.assets.paths'
```

### Step 3: Review Dockerfile
- Check if `assets:precompile:build` is called
- Verify Ember CLI dependencies are installed
- Ensure compiled assets are copied to runtime

### Step 4: Implement Fix
- Add missing compilation step if needed
- Fix asset copying if needed
- Add verification steps

### Step 5: Test
- Rebuild image
- Deploy
- Test routes
- Verify no errors

---

## Risk Assessment

### Low Risk:
- Adding `assets:precompile:build` to Dockerfile (if missing)
- Copying assets to runtime stage

### Medium Risk:
- Ember CLI compilation may take time
- May need additional dependencies
- Build time may increase

### Mitigation:
- Test in isolated environment first
- Add proper error handling
- Verify each step before proceeding

---

## Success Criteria

✅ **Build completes successfully**
- All asset compilation tasks run
- No errors during build

✅ **Assets exist in runtime**
- `frontend/discourse/dist/assets/*.js` files present
- Propshaft can resolve assets

✅ **Application works**
- `/finish-installation` returns 200
- No `Propshaft::MissingAssetError` exceptions
- All routes functional

---

## Next Actions

1. **IMMEDIATE:** Complete Phase 1 investigation
   - Extract exact missing asset name
   - Verify Ember assets exist
   - Check Dockerfile for `assets:precompile:build`

2. **HIGH PRIORITY:** Implement fix based on findings
   - Add missing compilation step if needed
   - Fix asset copying if needed

3. **VERIFY:** Test and confirm fix works
   - Rebuild and deploy
   - Test all routes
   - Verify no errors

---

## Notes

- Propshaft doesn't use `manifest.json` (resolves at runtime)
- `public/assets` directory not needed (Propshaft uses source paths)
- Focus on ensuring Ember CLI compilation runs and assets are accessible
- Discourse's custom asset pipeline requires `assets:precompile:build` for Ember assets



