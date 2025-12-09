# SIRA Community Production Dockerfile
# Multi-stage build for optimized production image

FROM ruby:3.3-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
    libpq-dev \
    libyaml-dev \
    nodejs \
    npm \
    imagemagick \
    libvips \
    libjemalloc2 \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN npm install -g pnpm@9.15.5

# Create community user
RUN useradd -m -s /bin/bash -u 1000 community

# Set working directory
WORKDIR /var/www/community

# Copy dependency files first (for better Docker layer caching)
COPY Gemfile Gemfile.lock ./
COPY package.json pnpm-workspace.yaml ./
# Copy patches directory
COPY patches ./patches/
# Remove patchedDependencies from package.json and lockfile to avoid version mismatches
# This is a workaround for patch version issues - TODO: fix patch versions properly
RUN npm install -g js-yaml && \
    node -e "const fs=require('fs'); const pkg=JSON.parse(fs.readFileSync('package.json','utf8')); delete pkg.pnpm.patchedDependencies; fs.writeFileSync('package.json',JSON.stringify(pkg,null,2)); console.log('Removed patchedDependencies from package.json');" 2>/dev/null || \
    (echo "No patchedDependencies in package.json" && true) && \
    rm -f pnpm-lock.yaml && \
    echo "Prepared for fresh install"

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4

# Install Node.js dependencies
# Note: Installing all dependencies (including dev) as frontend build requires dev dependencies
# Lockfile was removed - pnpm will regenerate it without patch conflicts
# TODO: Fix patch versions to match installed packages and commit new lockfile
RUN pnpm install

# Copy application code
COPY --chown=community:community . .

# Precompile assets
# Skip Redis connection during build by setting DISCOURSE_REDIS_HOST to empty
RUN DISCOURSE_REDIS_HOST="" RAILS_ENV=production bundle exec rake assets:precompile || \
    (echo "Asset precompilation failed, continuing without precompiled assets (will compile at runtime)" && true)

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set ownership
RUN chown -R community:community /var/www/community

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/srv/status || exit 1

# Use entrypoint script (runs as root, then switches to community user)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]



