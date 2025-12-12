# Discourse Source Code Modifications

This document tracks all modifications made to Discourse core source code to support the SIRA Community deployment.

## Purpose
These modifications are necessary for:
- Docker build process compatibility
- Asset precompilation during build
- Production deployment requirements

## Modifications

### 1. `app/models/global_setting.rb`

**Lines 60-68**: Added nil checks for `load_defaults` method
- **Reason**: During Docker build asset precompilation, `@provider` and `default_provider` can be nil
- **Impact**: Prevents `NoMethodError` during asset precompilation
- **Risk**: Low - defensive programming, doesn't change runtime behavior

```ruby
# Ensure @provider is initialized (may be nil during asset precompilation)
@provider ||= EnvProvider.new
# Handle case where default_provider might be nil
default_keys = default_provider ? default_provider.keys : []
provider_keys = @provider ? @provider.keys : []
(default_keys + provider_keys)
  .uniq
  .each do |key|
    default = default_provider ? default_provider.lookup(key, nil) : nil
```

**Lines 183-189**: Added `respond_to?` check for `db_sslmode`
- **Reason**: `db_sslmode` method may not exist during asset precompilation
- **Impact**: Prevents `NameError` during asset precompilation
- **Risk**: Low - graceful fallback, doesn't affect runtime if method exists

```ruby
db_sslmode_val = respond_to?(:db_sslmode) ? db_sslmode : nil
if db_sslmode_val.present?
  hash["sslmode"] = db_sslmode_val
end
```

### 2. `frontend/asset-processor/build.js`

**Line 51**: Added `platform: "node"` to esbuild configuration
- **Reason**: Required for esbuild to correctly resolve Node.js built-in modules (`node:buffer`, `node:path`, etc.)
- **Impact**: Fixes asset processor build during Docker build
- **Risk**: Low - standard esbuild configuration

**Line 62**: Added `@babel/preset-typescript/package.json` to external array
- **Reason**: Prevents esbuild from trying to bundle a package.json file
- **Impact**: Fixes asset processor build errors
- **Risk**: Low - standard esbuild configuration

### 3. `app/models/global_setting.rb` (Test Environment Support)

**Lines 80-105**: Added environment variable prioritization for test environment
- **Reason**: Test environment needs to read database/Redis config from environment variables (Docker service names)
- **Impact**: Enables proper database/Redis connection in Docker test environment
- **Risk**: Low - only affects test environment, production unchanged

**Lines 530-600**: Enhanced `BlankProvider` to read database/Redis config from environment variables
- **Reason**: Test environment uses `BlankProvider` which needs to read from environment variables
- **Impact**: Enables proper database/Redis connection in Docker test environment
- **Risk**: Low - only affects test environment, production unchanged

### 4. `config/database.yml` (Test Environment Support)

**Lines 42-50**: Added environment variable support for test database configuration
- **Reason**: Test environment needs to connect to Docker PostgreSQL service using environment variables
- **Impact**: Enables proper database connection in Docker test environment
- **Risk**: Low - only affects test environment, production unchanged

## Upgrade Considerations

When upgrading Discourse:
1. Check if these modifications are still needed
2. Verify that Discourse hasn't implemented similar fixes
3. Re-apply modifications if necessary
4. Test asset precompilation during Docker build

## Testing

These modifications have been tested:
- ✅ Docker build completes successfully
- ✅ Asset processor builds correctly
- ✅ Application starts without errors
- ✅ Runtime behavior unchanged

## Revert Instructions

If these modifications cause issues:
1. Revert changes to `app/models/global_setting.rb`
2. Revert changes to `frontend/asset-processor/build.js`
3. Rebuild Docker images
4. Verify asset precompilation still works

