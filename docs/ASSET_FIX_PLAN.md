# Structured Plan to Resolve Propshaft::MissingAssetError

## Phase 1: Investigation (Current)
**Goal:** Identify exact missing asset and understand asset compilation flow

### Tasks:
1. ✅ Identify which specific asset is missing
   - Run error extraction script
   - Check error logs for asset name
   - Verify which route/helper is requesting the asset

2. ✅ Understand Propshaft asset resolution
   - Check `Rails.application.config.assets.paths`
   - Verify Propshaft configuration
   - Understand how Propshaft finds assets (no manifest.json)

3. ✅ Check current asset locations
   - `frontend/discourse/dist/assets/` (Ember CLI output)
   - `public/javascripts/` (static files)
   - `public/assets/` (precompiled - may not exist)

4. ✅ Verify asset compilation in Dockerfile
   - Check if `assets:precompile:build` runs (Ember CLI)
   - Check if `assets:precompile` runs
   - Verify compiled assets are copied to runtime stage

## Phase 2: Root Cause Analysis
**Goal:** Determine why assets are missing

### Possible Causes:
1. **Ember CLI compilation not running**
   - `assets:precompile:build` not executed in Dockerfile
   - Ember CLI dependencies missing
   - Build process failing silently

2. **Assets not in correct location**
   - Compiled assets in wrong directory
   - Propshaft paths not configured correctly
   - Assets not copied to runtime stage

3. **Asset compilation failing**
   - Build errors not caught
   - Dependencies missing
   - Environment issues during build

## Phase 3: Solution Implementation
**Goal:** Fix asset compilation and ensure assets are available

### Solution A: Ensure Ember CLI Compilation Runs
**If Ember CLI compilation is missing:**
1. Add `assets:precompile:build` to Dockerfile
2. Ensure Ember CLI dependencies are installed
3. Verify build completes successfully
4. Copy compiled assets to runtime stage

### Solution B: Fix Asset Paths
**If assets are in wrong location:**
1. Verify Propshaft asset paths configuration
2. Ensure `frontend/discourse/dist/assets` is in paths
3. Copy assets to correct location if needed
4. Verify Propshaft can resolve assets

### Solution C: Fix Asset Compilation Process
**If compilation is failing:**
1. Add error checking to build process
2. Ensure all dependencies are available
3. Fix any compilation errors
4. Verify assets are created

## Phase 4: Verification
**Goal:** Confirm fix works

### Tests:
1. Build Docker image successfully
2. Verify assets exist in expected locations
3. Test application routes (especially `/finish-installation`)
4. Verify no `Propshaft::MissingAssetError` occurs
5. Check application loads correctly

## Implementation Priority

### High Priority:
1. Identify exact missing asset name
2. Verify if `assets:precompile:build` runs in Dockerfile
3. Check if Ember CLI compiled assets exist

### Medium Priority:
4. Fix Dockerfile to ensure Ember CLI compilation
5. Verify asset paths configuration
6. Ensure assets copied to runtime stage

### Low Priority:
7. Optimize asset compilation process
8. Add better error handling
9. Document asset compilation process

## Success Criteria
- ✅ No `Propshaft::MissingAssetError` exceptions
- ✅ All routes return 200 (not 500)
- ✅ Assets load correctly in browser
- ✅ Application fully functional



