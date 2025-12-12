# Asset Compilation Investigation

## Root Cause
**Exception:** `Propshaft::MissingAssetError`
**Location:** `lib/freedom_patches/propshaft_patches.rb:16`
**Called from:** `app/helpers/application_helper.rb:94` (`script_asset_path`)

## Investigation Steps

### Step 1: Identify Missing Asset
- Need to determine which specific asset file is missing (e.g., `start-discourse.js`, `browser-update.js`)

### Step 2: Understand Asset Paths
- Propshaft resolves assets from configured `Rails.application.config.assets.paths`
- Discourse adds paths: `public/javascripts`, `frontend/discourse/dist/assets`
- Propshaft serves assets directly from source paths (no manifest.json needed)

### Step 3: Check Asset Locations
- Verify assets exist in expected locations:
  - `frontend/discourse/dist/assets/*.js` (Ember CLI compiled assets)
  - `public/javascripts/*.js` (static JavaScript files)
  - `public/assets/*.js` (precompiled assets - may not exist for Propshaft)

### Step 4: Check Asset Compilation Process
- Discourse uses custom asset compilation:
  - `assets:precompile:build` - Runs Ember CLI compilation
  - `assets:precompile:asset_processor` - Builds asset processor
  - `assets:precompile` - Main precompilation task
- Need to verify if `assets:precompile:build` runs during Docker build

### Step 5: Docker Build Process
- Current Dockerfile runs:
  - `assets:precompile:asset_processor` ✓
  - `assets:precompile` ✓
  - But may NOT run `assets:precompile:build` (Ember CLI compilation)

## Findings
- Propshaft doesn't use `manifest.json` (resolves at runtime)
- `public/assets` directory not created (normal for Propshaft)
- Missing asset files in locations Propshaft can find them
- Ember CLI compilation may not be running during Docker build

## Next Steps
1. Identify exact missing asset name
2. Verify Ember CLI compilation runs during build
3. Ensure compiled assets are in correct locations
4. Verify Propshaft can find assets in configured paths



