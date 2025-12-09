# AI Coding Agent Guide

Project-specific instructions for AI agents. MUST be loaded at conversation start.

## Default Mode
- Architect mode enabled by default: detailed analysis, patterns, trade-offs, architectural guidance
- Stop and ask for context if unable to write code meeting guidelines

## Development Rules
Discourse is large with long history. Understand context before changes.

### All Files
- Always lint changed files
- Make display strings translatable (use placeholders, not split strings)
- Create subagent to review changes against this file after completing tasks

### Toolset
- Use `pnpm` for JavaScript, `bundle` for Ruby
- Use helpers in bin over bundle exec (bin/rspec, bin/rake)

### JavaScript
- No empty backing classes for template-only components unless requested
- Use FormKit for forms: https://meta.discourse.org/t/discourse-toolkit-to-render-forms/326439 (`app/assets/javascripts/discourse/app/form-kit`)

### JSDoc
- Required for classes, methods, members (except `@service` members, constructors)
- Multiline format only
- Components: `@component` name, list params (`this.args` or `@paramname`)
- Methods: no `@returns` for `@action`, use `@returns` for getters (not `@type`)
- Members: specify `@type`

## Testing
- Do not write unnecessary comments in tests, every single assertion doesn't need a comment
- Don't test functionality handled by other classes/components
- Don't write obvious tests
- Ruby: use `fab!()` over `let()`, system tests for UI (`spec/system`), use page objects for system spec finders (`spec/system/page_objects`)

### Page Objects (System Specs)
- Located in `spec/system/page_objects/pages/`, inherit from `PageObjects::Pages::Base`
- NEVER store `find()` results - causes stale element references after re-renders
- Use `has_x?` / `has_no_x?` patterns for state checks (finds fresh each time)
- Action methods find+interact atomically, return `self` for chaining
- Don't assert immediate UI feedback after clicks (tests browser, not app logic)

### Commands
```bash
# Ruby tests
bin/rspec [spec/path/file_spec.rb[:123]]
LOAD_PLUGINS=1 bin/rspec  # Plugin tests

# JavaScript tests
bin/rake qunit:test # RUN all non plugin tests
LOAD_PLUGINS=1 TARGET=all FILTER='fill filter here' bin/rake qunit:test # RUN specific tests based on filter

Exmaple filters JavaScript tests:

  emoji-test.js
    ...
    acceptance("Emoji" ..
      test("cooked correctly")
    ...
  Filter string is: "Acceptance: Emoji: cooked correctly"

  user-test.js
    ...
    module("Unit | Model | user" ..
      test("staff")
    ...
  Filter string is: "Unit | Model | user: staff"

# Linting
bin/lint path/to/file path/to/another/file
bin/lint --fix path/to/file path/to/another/file
bin/lint --fix --recent # Lint all recently changed files
```

ALWAYS lint any changes you make

## Site Settings
- Configured in `config/site_settings.yml` or `config/settings.yml` for plugins
- Functionality in `lib/site_setting_extension.rb`
- Access: `SiteSetting.setting_name` (Ruby), `siteSettings.setting_name` (JS with `@service siteSettings`)

## Services
- Extract business logic (validation, models, permissions) from controllers
- https://meta.discourse.org/t/using-service-objects-in-discourse/333641
- Examples: `app/services` (only classes with `Service::Base`)

## Database & Performance
- ActiveRecord: use `includes()`/`preload()` (N+1), `find_each()`/`in_batches()` (large sets), `update_all`/`delete_all` (bulk), `exists?` over `present?`
- Migrations: rollback logic, `algorithm: :concurrently` for large tables, deprecate before removing columns
- Queries: use `explain`, specify columns, strategic indexing, `counter_cache` for counts

## HTTP Response Codes
- **204 No Content**: Use `head :no_content` for successful operations that don't return data
  - DELETE operations that successfully remove a resource
  - UPDATE/PUT operations that succeed but don't need to return modified data
  - POST operations that perform an action without creating/returning resources (mark as read, clear notifications)
- **200 OK**: Use `render json: success_json` when returning confirmation data or when clients expect a response body
- **201 Created**: Use when creating resources, include location header or resource data
- **Do NOT use 204 when**:
  - Creating resources (use 201 with data)
  - Returning modified/useful data to the client
  - Clients expect confirmation data beyond success/failure

## Security
- XSS: use `{{}}` (escaped) not `{{{ }}}`, sanitize with `sanitize`/`cook`, no `innerHTML`, careful with `@html`
- Auth: Guardian classes (`lib/guardian.rb`), POST/PUT/DELETE for state changes, CSRF tokens, `protect_from_forgery`
- Input: validate client+server, strong parameters, length limits, don't trust client-only validation
- Authorization: Guardian classes, route+action permissions, scope limiting, `can_see?`/`can_edit?` patterns

## Knowledge Sharing
- ALWAYS persist information for ALL developers (no conversational-only memory)
- Follow project conventions, prevent knowledge silos
- Recommend storage locations by info type
- Inform when this file changes and reloads

## Docker & Deployment (SIRA Community Specific)

### Infrastructure Integration
- **Service Names**: Always use Docker service names (e.g., `postgres-community`, `redis`) not container names or `localhost`
- **Network**: Services must be on `sira_infra_network` to access infrastructure services
- **Ports**: Use internal ports (5432 for PostgreSQL, 6380 for Redis TLS) not external ports (5433)

### Certificate Management
- **Read-Only Mounts**: Certificates mounted from host are read-only and root-owned
- **Entrypoint Script**: Must run as root to copy certificates to writable location (`/var/www/community/tmp/ssl/`)
- **Permissions**: Set correct permissions (644 for certs, 600 for keys) and ownership (`community:community`)
- **Environment Variables**: Export certificate paths pointing to writable locations after copying

### SSL/TLS Configuration
- **PostgreSQL (mTLS)**: Requires `sslmode`, `sslcert`, `sslkey`, `sslrootcert` in `database_config`
- **Redis (TLS)**: Requires `ssl_params` with OpenSSL objects (`OpenSSL::X509::Certificate`, `OpenSSL::PKey::RSA`) and `ca_file` as string path
- **Library Differences**: `redis-rb` needs OpenSSL objects, `pg` gem needs string paths
- **Certificate Paths**: Use environment variables (set by entrypoint) not config file substitution

### Certificate Generation (Production-Grade)
- **CRITICAL: Server certificates MUST include "Digital Signature" in Key Usage** - Modern browsers (Chrome, Edge, Firefox) reject certificates without this
- **Key Usage Requirements**:
  - Server certificates: `digitalSignature, keyEncipherment, dataEncipherment` (all required)
  - Set Key Usage as `critical` in OpenSSL config
- **Extended Key Usage**: Must include `serverAuth` (1.3.6.1.5.5.7.3.1)
- **Certificate Types**: Never use client certificates (`*-client.crt`) as server certificates - always use `*-server.crt`
- **Verification**: Always verify certificate Key Usage after generation using `openssl x509 -text -noout`
- **OpenSSL Config**: Use proper OpenSSL configuration files with `[v3_req]` section including Key Usage

### Health Checks
- **Web Servers**: Use HTTP endpoint checks (e.g., `curl -f http://localhost:3000/srv/status`)
- **Background Workers**: Use process checks (e.g., `cat /proc/1/cmdline | grep -q sidekiq`)
- **Alpine Containers**: Use `127.0.0.1` instead of `localhost` in health checks
- **Start Periods**: Set appropriate `start_period` (60-90s for apps, 10s for nginx)

### Puma Configuration
- **APP_ROOT**: Must be set to `/var/www/community` (not default `/home/discourse/discourse`)
- **Port Binding**: Must listen on both Unix socket AND TCP port 3000 for Docker/nginx
- **Directories**: Entrypoint must create `tmp/sockets`, `tmp/pids`, `log` directories

### Problem-Solving Approach
- **POC First**: Create isolated POCs in `temp/` folder to identify root causes before applying fixes
- **Check Logs with Timestamps**: Always use `docker logs --timestamps` for debugging
- **Verify One Service at a Time**: Fix and verify each service individually
- **Test Manually**: Test health checks and endpoints manually before relying on Docker health checks