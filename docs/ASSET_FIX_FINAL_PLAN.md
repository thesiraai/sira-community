# Asset Fix - Final Action Plan

## ✅ Root Cause Confirmed

### Missing Asset
- **Asset:** `onpopstate-handler.js`
- **Error:** `Propshaft::MissingAssetError: The asset 'onpopstate-handler.js' was not found in the load path`
- **Location:** `app/views/exceptions/not_found.html.erb:51`

### Root Cause
**Ember CLI compilation is NOT running during Docker build**

**Evidence:**
1. `frontend/discourse/dist/assets/` directory does NOT exist in container
2. Dockerfile runs `assets:precompile:asset_processor` ✓
3. Dockerfile runs `assets:precompile` ✓
4. Dockerfile does NOT run `assets:precompile:build` ✗
5. `assets:precompile:build` is required to compile Ember CLI assets
6. Without Ember compilation, `frontend/discourse/dist/assets/*.js` files don't exist

---

## Solution

### Fix: Add Ember CLI Compilation to Dockerfile

**Current Dockerfile (line ~134-141):**
```dockerfile
RUN DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    bundle exec rake assets:precompile:asset_processor && \
    test -f tmp/asset-processor.js || (echo "ERROR: Asset processor failed to build" && exit 1) && \
    echo "✓ Asset processor built successfully ($(du -h tmp/asset-processor.js | cut -f1))" && \
    DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    bundle exec rake assets:precompile && \
    echo "✓ Assets precompiled successfully" && \
    test -d public/assets && echo "✓ public/assets directory exists" || echo "⚠ public/assets directory not found"
```

**Fixed Dockerfile:**
```dockerfile
RUN DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    bundle exec rake assets:precompile:build && \
    echo "✓ Ember CLI assets compiled" && \
    bundle exec rake assets:precompile:asset_processor && \
    test -f tmp/asset-processor.js || (echo "ERROR: Asset processor failed to build" && exit 1) && \
    echo "✓ Asset processor built successfully ($(du -h tmp/asset-processor.js | cut -f1))" && \
    DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    bundle exec rake assets:precompile && \
    echo "✓ Assets precompiled successfully" && \
    test -d frontend/discourse/dist/assets && echo "✓ Ember assets exist" || (echo "✗ Ember assets missing" && exit 1)
```

**Key Changes:**
1. Add `bundle exec rake assets:precompile:build` BEFORE other asset tasks
2. Verify `frontend/discourse/dist/assets` exists (not `public/assets`)
3. Fail build if Ember assets don't exist

---

## Implementation Steps

### Step 1: Update Dockerfile
1. Add `assets:precompile:build` task
2. Add verification for `frontend/discourse/dist/assets`
3. Ensure proper order: build → asset_processor → precompile

### Step 2: Rebuild Docker Image
```bash
cd "C:\Users\vvssi\OneDrive\Projects\AI Project\SIRA AI\Code\sira-community"
docker build --progress=plain -t sira-community:latest -f Dockerfile .
```

### Step 3: Verify Build
- Check build logs for "✓ Ember CLI assets compiled"
- Verify "✓ Ember assets exist" message
- Ensure build completes successfully

### Step 4: Deploy and Test
```bash
cd docker
docker compose -f docker-compose.sira-community.app.yml up -d
```

### Step 5: Verify Fix
```bash
# Test routes
curl http://localhost:3000/finish-installation
# Should return 200, not 500

# Verify assets exist
docker exec sira-community-app ls -la /var/www/community/frontend/discourse/dist/assets/*.js | head -5
```

---

## Expected Results

### After Fix:
✅ `frontend/discourse/dist/assets/` directory exists
✅ `onpopstate-handler.js` and other Ember assets present
✅ Propshaft can resolve assets from configured paths
✅ `/finish-installation` returns 200 (not 500)
✅ No `Propshaft::MissingAssetError` exceptions

### Build Output:
```
✓ Ember CLI assets compiled
✓ Asset processor built successfully (18M)
✓ Assets precompiled successfully
✓ Ember assets exist
```

---

## Risk Assessment

### Low Risk:
- Adding `assets:precompile:build` is standard Discourse practice
- Task is already defined in `lib/tasks/assets.rake`
- Only adds Ember compilation step

### Potential Issues:
- **Build time increase:** Ember CLI compilation takes time (~5-10 minutes)
- **Memory usage:** Ember compilation is memory-intensive
- **Dependencies:** Need to ensure Ember CLI dependencies are installed

### Mitigation:
- Build time increase is acceptable (one-time cost)
- Memory should be sufficient in builder stage
- Dependencies already installed (node_modules exists)

---

## Verification Checklist

- [ ] Dockerfile updated with `assets:precompile:build`
- [ ] Build completes successfully
- [ ] `frontend/discourse/dist/assets/` exists in image
- [ ] `onpopstate-handler.js` exists in dist/assets
- [ ] Application deploys successfully
- [ ] `/finish-installation` returns 200
- [ ] No `Propshaft::MissingAssetError` in logs
- [ ] All routes functional

---

## Notes

- `assets:precompile:build` runs `script/assemble_ember_build.rb`
- This compiles Ember CLI app to `frontend/discourse/dist/assets/`
- Propshaft looks for assets in `frontend/discourse/dist/assets/` (configured in `config/initializers/assets.rb`)
- Without Ember compilation, these assets don't exist → `MissingAssetError`
- The fix is straightforward: add the missing compilation step

---

## Timeline

- **Investigation:** ✅ Complete (30 minutes)
- **Fix Implementation:** 15 minutes
- **Build & Test:** 20-30 minutes
- **Total:** ~1 hour

---

## Success Criteria

✅ Build completes with Ember assets compiled
✅ Assets exist in `frontend/discourse/dist/assets/`
✅ Application routes return 200 (not 500)
✅ No asset-related errors in logs



