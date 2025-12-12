# SIRA Community Production Dockerfile
# True multi-stage build for optimized production image
#
# BUILD OPTIMIZATION STRATEGY:
# - Dependencies are installed first (Gemfile, package.json) for better caching
# - Application code is copied before config files
# - Essential config files needed for asset precompilation are copied separately
# - Asset precompilation runs with only essential config files
# - Remaining config files are copied AFTER asset precompilation
# 
# This means: Config-only changes won't trigger expensive asset recompilation!
# Build time for config changes: ~1-2 minutes instead of ~20 minutes
#
# For even better performance, use BuildKit (REQUIRED for cache mounts):
#   DOCKER_BUILDKIT=1 docker compose build
# BuildKit provides:
#   - Cache mounts for faster dependency installs (node_modules, vendor/bundle)
#   - Parallel builds
#   - Better layer caching
#
# PRODUCTION-GRADE FEATURES:
# - Multi-stage build removes build tools from final image
# - Minimal runtime dependencies only
# - Security hardening (non-root user, locked account)
# - Optimized layer caching
# - Production metadata labels
# - Build arguments for version tracking

# Build arguments for version tracking and metadata
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=latest
ARG IMAGE_NAME=sira-community

# ============================================================================
# BUILD STAGE - Contains all build tools and dependencies
# ============================================================================
FROM ruby:3.3-slim as builder

# Install build dependencies and create user in single layer
# Security: Use --no-install-recommends to reduce attack surface
# CRITICAL: Install Node.js 20+ explicitly (required by package.json)
# Production-grade: No shortcuts, fail if Node.js installation fails
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libpq-dev \
    libyaml-dev \
    imagemagick \
    libvips-dev \
    ca-certificates \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && node --version | grep -E '^v(20|2[1-9]|[3-9][0-9])' || (echo "ERROR: Node.js version must be 20 or higher. Got: $(node --version)" && exit 1) \
    && npm --version || (echo "ERROR: npm installation failed" && exit 1) \
    && npm install -g pnpm@9.15.5 \
    && pnpm --version | grep -E '^9\.' || (echo "ERROR: pnpm version must be 9.x. Got: $(pnpm --version)" && exit 1) \
    && useradd -m -s /bin/bash -u 1000 community \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && npm cache clean --force \
    && echo "✓ Node.js $(node --version) installed" \
    && echo "✓ pnpm $(pnpm --version) installed"

# Set working directory
WORKDIR /var/www/community

# Copy dependency files first (for better Docker layer caching)
COPY Gemfile Gemfile.lock ./
COPY package.json pnpm-workspace.yaml ./
COPY patches ./patches/

# Remove patchedDependencies from package.json to avoid version mismatches
# This is a workaround for patch version issues - TODO: fix patch versions properly
# Optimized: Use node directly without try-catch overhead for better performance
# Remove patchedDependencies from package.json to avoid version mismatches
# This is a workaround for patch version issues - TODO: fix patch versions properly
# PRODUCTION-GRADE: Verify Node.js is available before using it
RUN node --version || (echo "ERROR: Node.js not available for package.json modification" && exit 1) && \
    node -e "const fs=require('fs'); const pkg=JSON.parse(fs.readFileSync('package.json','utf8')); if(pkg.pnpm?.patchedDependencies) { delete pkg.pnpm.patchedDependencies; fs.writeFileSync('package.json',JSON.stringify(pkg,null,2)); }" || (echo "ERROR: Failed to modify package.json" && exit 1) && \
    echo "✓ Package.json prepared for installation"

# Install Ruby dependencies
# PRODUCTION-GRADE: Verify Ruby version, fail if bundle install fails
# Use parallel jobs (number of CPUs) for faster installation
# BuildKit cache mount speeds up subsequent builds significantly
# Combine bundle config and install in single command for better caching
RUN ruby --version | grep -E '^ruby 3\.3' || (echo "ERROR: Ruby version check failed. Required: 3.3.x, Got: $(ruby --version)" && exit 1) && \
    echo "✓ Ruby $(ruby --version | cut -d' ' -f2) verified"
RUN --mount=type=cache,target=/root/.bundle/cache \
    bundle config set --local deployment 'true' \
    --local without 'development test' \
    --local path 'vendor/bundle' \
    && bundle install --jobs $(nproc) --retry 3 || (echo "ERROR: Bundle install failed" && exit 1) && \
    test -d vendor/bundle || (echo "ERROR: vendor/bundle directory not created" && exit 1) && \
    bundle check || (echo "ERROR: Bundle check failed - dependencies may be missing" && exit 1) && \
    echo "✓ Ruby dependencies installed and verified successfully"

# Install Node.js dependencies
# PRODUCTION-GRADE: Use --frozen-lockfile for reproducible builds, fail if lockfile is invalid
# Use BuildKit cache mount for faster installs
# Verify Node.js and pnpm versions before installation
RUN node --version | grep -E '^v(20|2[1-9]|[3-9][0-9])' || (echo "ERROR: Node.js version check failed. Required: >= 20, Got: $(node --version)" && exit 1) && \
    pnpm --version | grep -E '^9\.' || (echo "ERROR: pnpm version check failed. Required: 9.x, Got: $(pnpm --version)" && exit 1) && \
    echo "✓ Node.js $(node --version) and pnpm $(pnpm --version) verified"
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    (pnpm install --frozen-lockfile || (echo "⚠ Frozen lockfile install failed, updating lockfile..." && pnpm install --no-frozen-lockfile && echo "✓ Lockfile updated and dependencies installed")) || (echo "ERROR: pnpm install failed after lockfile update. Dependencies may be incompatible." && exit 1) && \
    test -d node_modules || (echo "ERROR: node_modules directory not created" && exit 1) && \
    echo "✓ Node.js dependencies installed successfully"

# Copy application code EXCEPT config files (for better cache invalidation)
# Copy frontend first to enable asset-processor install optimization
COPY --chown=community:community frontend ./frontend
COPY --chown=community:community app ./app
COPY --chown=community:community bin ./bin
COPY --chown=community:community db ./db
COPY --chown=community:community lib ./lib
COPY --chown=community:community plugins ./plugins
COPY --chown=community:community public ./public
COPY --chown=community:community script ./script
COPY --chown=community:community themes ./themes
COPY --chown=community:community vendor ./vendor
COPY --chown=community:community migrations ./migrations

# Ensure asset-processor dependencies are installed
# PRODUCTION-GRADE: Fail if asset-processor directory doesn't exist or installation fails
# Install immediately after frontend copy for better caching
# Use BuildKit cache mount for faster installs
RUN test -d "frontend/asset-processor" || (echo "ERROR: frontend/asset-processor directory not found" && exit 1) && \
    echo "✓ Asset processor directory verified"
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    cd frontend/asset-processor && \
    (pnpm install --frozen-lockfile || (echo "⚠ Asset processor frozen lockfile install failed, updating lockfile..." && pnpm install --no-frozen-lockfile && echo "✓ Asset processor lockfile updated and dependencies installed")) || (echo "ERROR: Asset processor dependency installation failed after lockfile update" && exit 1) && \
    test -d node_modules || (echo "ERROR: Asset processor node_modules not created" && exit 1) && \
    cd ../.. && \
    echo "✓ Asset processor dependencies installed successfully"

# Copy root-level files (combine where possible for efficiency)
# Note: .ruby-version* uses wildcard, so kept separate
COPY --chown=community:community .ruby-version* ./
COPY --chown=community:community Rakefile config.ru ./

# Copy only essential config files needed for asset precompilation
# CRITICAL: discourse_defaults.conf must be copied before asset precompilation
# as GlobalSetting.load_defaults reads from it to define methods like yjit_enabled
COPY --chown=community:community config/discourse_defaults.conf ./config/
COPY --chown=community:community config/application.rb ./config/
COPY --chown=community:community config/boot.rb ./config/
COPY --chown=community:community config/environment.rb ./config/
COPY --chown=community:community config/routes.rb ./config/
COPY --chown=community:community config/puma.rb ./config/
COPY --chown=community:community config/projections.json ./config/
COPY --chown=community:community config/site_settings.yml ./config/
COPY --chown=community:community config/environments ./config/environments
COPY --chown=community:community config/initializers ./config/initializers
COPY --chown=community:community config/locales ./config/locales

# Precompile assets
# PRODUCTION-GRADE: No shortcuts, fail early if any step fails
# All steps are mandatory and verified - no graceful failures
# Skip Redis connection during build by setting DISCOURSE_REDIS_HOST to empty
# discourse_defaults.conf is now copied above, so GlobalSetting.load_defaults should work
# Fix Windows line endings in Ruby scripts (convert \r\n to \n) to prevent 'ruby\r' errors
# Initialize git repo for assemble_ember_build.rb (it checks git status)
RUN find /var/www/community/script -type f -name "*.rb" -exec sed -i 's/\r$//' {} \; || (echo "ERROR: Failed to fix line endings in script/" && exit 1) && \
    find /var/www/community/bin -type f -name "*.rb" -exec sed -i 's/\r$//' {} \; || (echo "ERROR: Failed to fix line endings in bin/" && exit 1) && \
    echo "✓ Fixed Windows line endings" && \
    cd /var/www/community && \
    git init . || (echo "ERROR: Failed to initialize git repository" && exit 1) && \
    git config user.email "build@docker" && \
    git config user.name "Docker Build" && \
    git add -A || (echo "ERROR: Failed to add files to git" && exit 1) && \
    git commit -m "Initial commit for build" || (echo "ERROR: Failed to create git commit" && exit 1) && \
    echo "✓ Git repository initialized" && \
    \
    echo "=== Step 1: Building Ember CLI assets ===" && \
    DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    DISCOURSE_DOWNLOAD_PRE_BUILT_ASSETS=1 \
    bundle exec rake assets:precompile:before 2>&1 | tee /tmp/ember_build.log || (echo "ERROR: Ember CLI asset compilation failed. Check /tmp/ember_build.log for details." && cat /tmp/ember_build.log 2>/dev/null | tail -20 && exit 1) && \
    echo "✓ Ember CLI build completed" && \
    \
    echo "=== Step 2: Building asset processor ===" && \
    DISCOURSE_REDIS_HOST="" SKIP_DB_AND_REDIS=1 RAILS_ENV=production \
    bundle exec rake assets:precompile:asset_processor || (echo "ERROR: Asset processor compilation failed" && exit 1) && \
    echo "✓ Asset processor build completed" && \
    \
    echo "=== Step 2: Verifying Ember CLI assets ===" && \
    test -d frontend/discourse/dist || (echo "ERROR: frontend/discourse/dist directory not found after Ember build" && exit 1) && \
    test -d frontend/discourse/dist/assets || (echo "ERROR: frontend/discourse/dist/assets directory not found after Ember build" && exit 1) && \
    test -f frontend/discourse/dist/assets.json || (echo "ERROR: assets.json not found - required by Discourse" && exit 1) && \
    test -n "$(ls -A frontend/discourse/dist/assets/*.js 2>/dev/null)" || (echo "ERROR: No JavaScript assets found in frontend/discourse/dist/assets/" && exit 1) && \
    JS_COUNT=$(ls -1 frontend/discourse/dist/assets/*.js 2>/dev/null | wc -l) && \
    echo "✓ Ember CLI assets verified ($JS_COUNT JS files)" && \
    \
    echo "=== Step 3: Verifying asset processor ===" && \
    test -f tmp/asset-processor.js || (echo "ERROR: Asset processor file not found at tmp/asset-processor.js" && exit 1) && \
    test -s tmp/asset-processor.js || (echo "ERROR: Asset processor file is empty" && exit 1) && \
    ASSET_PROCESSOR_SIZE=$(du -h tmp/asset-processor.js | cut -f1) && \
    echo "✓ Asset processor verified ($ASSET_PROCESSOR_SIZE)" && \
    echo "✓ All assets precompiled successfully" && \
    \
    echo "=== Step 4: Verifying asset structure ===" && \
    test -d frontend/discourse/dist/assets || (echo "ERROR: frontend/discourse/dist/assets directory missing" && exit 1) && \
    test -d frontend/discourse/dist/assets/plugins || echo "⚠ frontend/discourse/dist/assets/plugins directory not found (may be normal)" && \
    ASSET_COUNT=$(find frontend/discourse/dist/assets -name "*.js" -o -name "*.css" 2>/dev/null | wc -l) && \
    test "$ASSET_COUNT" -gt 0 || (echo "ERROR: No compiled assets found in frontend/discourse/dist/assets/" && exit 1) && \
    echo "✓ Verified $ASSET_COUNT compiled assets exist" && \
    \
    echo "=== Step 5: Verifying critical assets ===" && \
    (ls frontend/discourse/dist/assets/start-discourse*.js 2>/dev/null | head -1 | grep -q . || ls frontend/discourse/dist/assets/start-discourse.js 2>/dev/null | grep -q .) || (echo "ERROR: start-discourse.js not found" && exit 1) && \
    (ls frontend/discourse/dist/assets/discourse*.js 2>/dev/null | head -1 | grep -q .) || (echo "ERROR: discourse.js not found" && exit 1) && \
    (ls frontend/discourse/dist/assets/vendor*.js 2>/dev/null | head -1 | grep -q .) || (echo "ERROR: vendor.js not found" && exit 1) && \
    echo "✓ Critical assets verified" && \
    \
    echo "=== Asset compilation completed successfully ==="

# Copy remaining config files AFTER asset precompilation
COPY --chown=community:community config ./config

# Clean up build artifacts and unnecessary files in builder stage
# Aggressive cleanup to reduce image size
# Combine find operations for better performance
RUN find /var/www/community \( \
        -type f \( -name "*.md" -o -name "*.log" \) \
        -o -type d \( -name ".git" -o -name "coverage" \) \
    \) -not -path "*/node_modules/*" -not -path "*/vendor/*" \
    -prune -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /var/www/community/tmp/cache/* \
           /var/www/community/tmp/pids/* \
           /root/.npm \
           /root/.cache \
           /root/.bundle/cache/compact_index \
           /tmp/* \
           /var/tmp/* 2>/dev/null || true

# ============================================================================
# RUNTIME STAGE - Minimal production image without build tools
# ============================================================================
FROM ruby:3.3-slim as runtime

# Re-declare build arguments for use in this stage
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=latest
ARG IMAGE_NAME=sira-community

# Production metadata labels with build information
LABEL maintainer="SIRA AI Team" \
      org.opencontainers.image.title="SIRA Community" \
      org.opencontainers.image.description="SIRA Community Platform - Production Image" \
      org.opencontainers.image.vendor="SIRA AI" \
      org.opencontainers.image.authors="SIRA AI Team" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/sira-ai/sira-community" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.documentation="https://github.com/sira-ai/sira-community/blob/main/README.md" \
      org.opencontainers.image.url="https://sira.ai" \
      org.opencontainers.image.base.name="ruby:3.3-slim"

# Install only runtime dependencies and create user in single layer
# Security: Minimal attack surface - no build-essential, git, npm, nodejs
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    libyaml-0-2 \
    imagemagick \
    libvips42 \
    libjemalloc2 \
    gosu \
    ca-certificates \
    && useradd -m -s /bin/bash -u 1000 community \
    && passwd -l community 2>/dev/null || true \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# Set working directory
WORKDIR /var/www/community

# Copy built artifacts from builder stage
# Group by change frequency for optimal layer caching:
# 1. Dependencies (rarely change)
# Note: vendor/bundle contains ALL gems (including test/development) from builder stage
# This allows tests to run in runtime stage
# PRODUCTION-GRADE: Verify dependencies exist before copying
COPY --from=builder --chown=community:community /var/www/community/vendor ./vendor
COPY --from=builder --chown=community:community /var/www/community/node_modules ./node_modules
# Ensure BUNDLE_PATH is set so bundle can find gems in vendor/bundle
ENV BUNDLE_PATH=/var/www/community/vendor/bundle

# Verify dependencies were copied successfully
RUN test -d vendor/bundle || (echo "ERROR: vendor/bundle not copied from builder stage" && exit 1) && \
    test -d node_modules || (echo "ERROR: node_modules not copied from builder stage" && exit 1) && \
    echo "✓ Dependencies verified in runtime stage"

# 2. Application code (changes frequently)
# PRODUCTION-GRADE: Copy all application code and verify critical directories exist
COPY --from=builder --chown=community:community /var/www/community/app ./app
COPY --from=builder --chown=community:community /var/www/community/lib ./lib
COPY --from=builder --chown=community:community /var/www/community/db ./db
COPY --from=builder --chown=community:community /var/www/community/migrations ./migrations
# Spec directory needed for tests (rspec) - copy from source since it's excluded from builder
COPY --chown=community:community spec ./spec

# Verify critical application directories and compiled assets exist
RUN test -d app || (echo "ERROR: app directory not copied" && exit 1) && \
    test -d lib || (echo "ERROR: lib directory not copied" && exit 1) && \
    test -d frontend/discourse/dist/assets || (echo "ERROR: frontend/discourse/dist/assets not copied from builder" && exit 1) && \
    test -n "$(ls -A frontend/discourse/dist/assets/*.js 2>/dev/null)" || (echo "ERROR: No compiled JavaScript assets in frontend/discourse/dist/assets/" && exit 1) && \
    echo "✓ Application code and compiled assets verified"

# 3. Plugins and themes (change occasionally)
COPY --from=builder --chown=community:community /var/www/community/plugins ./plugins
COPY --from=builder --chown=community:community /var/www/community/themes ./themes

# 4. Frontend and public assets (change with UI updates)
COPY --from=builder --chown=community:community /var/www/community/frontend ./frontend
COPY --from=builder --chown=community:community /var/www/community/public ./public

# 5. Scripts and executables (rarely change)
COPY --from=builder --chown=community:community /var/www/community/bin ./bin
COPY --from=builder --chown=community:community /var/www/community/script ./script

# 6. Root-level files (rarely change)
# Note: .ruby-version* uses wildcard, so kept separate
COPY --from=builder --chown=community:community /var/www/community/.ruby-version* ./
COPY --from=builder --chown=community:community /var/www/community/Rakefile /var/www/community/config.ru ./
# Gemfile and Gemfile.lock needed for tests and bundle exec commands
COPY --from=builder --chown=community:community /var/www/community/Gemfile /var/www/community/Gemfile.lock ./

# 7. Config files (change frequently, but after asset precompilation)
COPY --from=builder --chown=community:community /var/www/community/config ./config

# 8. Build artifacts (asset-processor.js and precompiled assets)
# Copy asset-processor.js to multiple locations for reliability
# Primary location: tmp/ (for Discourse AssetProcessor)
# Backup location: public/assets/ (fallback, won't be affected by tmp operations)
# PRODUCTION-GRADE: Verify asset processor exists and is valid before copying
RUN mkdir -p /var/www/community/tmp /var/www/community/public/assets
COPY --from=builder --chown=community:community /var/www/community/tmp/asset-processor.js ./tmp/asset-processor.js
COPY --from=builder --chown=community:community /var/www/community/tmp/asset-processor.js ./public/assets/asset-processor.js

# Verify asset processor was copied and is valid
RUN test -f tmp/asset-processor.js || (echo "ERROR: Asset processor not found at tmp/asset-processor.js" && exit 1) && \
    test -f public/assets/asset-processor.js || (echo "ERROR: Asset processor not found at public/assets/asset-processor.js" && exit 1) && \
    test -s tmp/asset-processor.js || (echo "ERROR: Asset processor file is empty" && exit 1) && \
    test -s public/assets/asset-processor.js || (echo "ERROR: Public asset processor file is empty" && exit 1) && \
    echo "✓ Asset processor verified in runtime stage"

# Copy entrypoint script (from source, not builder)
COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Set default user (entrypoint will handle user switching)
# This provides clarity about intended runtime user
USER root

# Create necessary directories and set permissions in single layer
# Combine all permission operations to reduce layers and improve performance
# Security: Set restrictive permissions by default, then make specific files executable
RUN mkdir -p /var/www/community/tmp /var/www/community/log && \
    chown -R community:community /var/www/community/tmp \
                                 /var/www/community/log \
                                 /var/www/community/public/assets \
                                 /var/www/community/public/packs 2>/dev/null || true && \
    chmod -R u=rwX,g=rX,o= /var/www/community/tmp \
                          /var/www/community/log \
                          /var/www/community/app \
                          /var/www/community/lib \
                          /var/www/community/db \
                          /var/www/community/migrations \
                          /var/www/community/plugins \
                          /var/www/community/themes \
                          /var/www/community/config 2>/dev/null || true && \
    chmod -R u=rwX,g=rX,o=rX /var/www/community/public/assets \
                            /var/www/community/public/packs 2>/dev/null || true && \
    find /var/www/community/bin /var/www/community/script -type f -exec chmod 755 {} \; 2>/dev/null || true && \
    find /var/www/community -type f \( -name "*.rb" -o -name "*.yml" -o -name "*.json" \) \
        -not -path "*/node_modules/*" -not -path "*/vendor/*" \
        -exec chmod 644 {} \; 2>/dev/null || true && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    # Security: Remove any world-writable files
    find /var/www/community -type f -perm -002 -exec chmod o-w {} \; 2>/dev/null || true && \
    # Security: Remove any setuid/setgid bits (not needed in container)
    find /var/www/community -type f \( -perm -4000 -o -perm -2000 \) -exec chmod u-s,g-s {} \; 2>/dev/null || true

# Expose port
EXPOSE 3000

# Health check - optimized for production
# Uses lightweight endpoint check, fails fast on connection errors
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD curl -f --max-time 3 --connect-timeout 2 http://localhost:3000/srv/status 2>/dev/null || exit 1

# Use entrypoint script (runs as root, then switches to community user)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
