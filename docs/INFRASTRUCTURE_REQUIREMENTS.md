# SIRA Community Infrastructure Requirements

**Document Version:** 1.0  
**Last Updated:** 2024  
**Prepared For:** Infrastructure Team  
**Purpose:** Comprehensive infrastructure setup guide for SIRA Community deployment

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Compute Resources](#compute-resources)
4. [Database Infrastructure](#database-infrastructure)
5. [Cache & Redis Infrastructure](#cache--redis-infrastructure)
6. [Storage Requirements](#storage-requirements)
7. [Network Configuration](#network-configuration)
8. [Load Balancing & High Availability](#load-balancing--high-availability)
9. [SSL/TLS Certificates](#ssltls-certificates)
10. [DNS Configuration](#dns-configuration)
11. [Email Infrastructure](#email-infrastructure)
12. [Monitoring & Logging](#monitoring--logging)
13. [Backup & Disaster Recovery](#backup--disaster-recovery)
14. [Security Requirements](#security-requirements)
15. [Environment-Specific Configurations](#environment-specific-configurations)
16. [Integration Points](#integration-points)
17. [Resource Sizing Recommendations](#resource-sizing-recommendations)
18. [Deployment Checklist](#deployment-checklist)

---

## Executive Summary

SIRA Community is a Ruby on Rails application (based on Discourse) that requires:

- **Application Servers**: Docker containers running Rails application (Puma) and background workers (Sidekiq)
- **Database**: PostgreSQL 13+ with high availability
- **Cache**: Redis 7+ for caching and background job queue
- **Reverse Proxy**: Nginx for SSL termination and load balancing
- **Storage**: Persistent volumes for uploads, backups, and logs
- **Network**: Docker network integration with SIRA AI ecosystem
- **Monitoring**: Comprehensive logging and monitoring infrastructure

**Minimum Production Requirements:**
- 4 CPU cores
- 8 GB RAM
- 100 GB storage
- PostgreSQL 13+
- Redis 7+
- Docker & Docker Compose

**Recommended Production Requirements:**
- 8 CPU cores
- 16 GB RAM
- 500 GB storage (SSD)
- Managed PostgreSQL (high availability)
- Managed Redis (high availability)
- Load balancer
- CDN for static assets

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer / CDN                       │
│              (HTTPS: 443, HTTP: 80)                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Nginx Reverse Proxy                        │
│              (SSL Termination, Rate Limiting)                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────────┐            ┌──────────────────────┐
│   Application Pod 1  │            │   Application Pod 2  │
│  ┌────────────────┐  │            │  ┌────────────────┐  │
│  │ Rails App      │  │            │  │ Rails App      │  │
│  │ (Puma)         │  │            │  │ (Puma)         │  │
│  └────────────────┘  │            │  └────────────────┘  │
│  ┌────────────────┐  │            │  ┌────────────────┐  │
│  │ Sidekiq Worker │  │            │  │ Sidekiq Worker │  │
│  └────────────────┘  │            │  └────────────────┘  │
└──────────────────────┘            └──────────────────────┘
        │                                       │
        └──────────────────┬──────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────────┐            ┌──────────────────────┐
│   PostgreSQL 13+     │            │      Redis 7+         │
│   (Primary/Replica)   │            │   (Primary/Replica)   │
└──────────────────────┘            └──────────────────────┘
        │                                       │
        └──────────────────┬──────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Persistent Storage (Volumes)                    │
│  - Database backups                                         │
│  - Application uploads                                       │
│  - Logs                                                     │
│  - Temporary files                                          │
└─────────────────────────────────────────────────────────────┘
```

### Docker Services Architecture

```
sira-network (Docker Network)
├── sira-community-app (Rails Application)
│   ├── Port: 3000 (internal)
│   ├── Workers: 4-8 (configurable)
│   └── Health: /srv/status
│
├── sira-community-sidekiq (Background Jobs)
│   ├── Concurrency: 5-10 (configurable)
│   └── Jobs: Email, notifications, search indexing
│
├── sira-community-nginx (Reverse Proxy)
│   ├── Port: 80 (HTTP)
│   ├── Port: 443 (HTTPS)
│   └── SSL Termination
│
├── sira-community-postgres (Database)
│   ├── Port: 5432 (internal)
│   ├── Version: 13+
│   └── Data Volume: postgres_data
│
└── sira-community-redis (Cache)
    ├── Port: 6379 (internal)
    ├── Version: 7+
    └── Data Volume: redis_data
```

---

## Compute Resources

### Application Servers

#### Container Specifications

**Application Container (Rails/Puma):**
- **Base Image**: `ruby:3.3-slim`
- **CPU**: 2-4 cores per container
- **Memory**: 2-4 GB per container
- **Instances**: 2+ for high availability
- **Port**: 3000 (internal)

**Sidekiq Worker Container:**
- **Base Image**: `ruby:3.3-slim`
- **CPU**: 1-2 cores per container
- **Memory**: 1-2 GB per container
- **Instances**: 2+ for high availability
- **Concurrency**: 5-10 workers per container

**Nginx Container:**
- **Base Image**: `nginx:alpine`
- **CPU**: 0.5-1 core per container
- **Memory**: 128-256 MB per container
- **Instances**: 2+ for high availability
- **Ports**: 80 (HTTP), 443 (HTTPS)

#### Resource Requirements by Environment

| Environment | App Containers | Sidekiq Containers | Total CPU | Total RAM | Storage |
|------------|----------------|-------------------|-----------|-----------|---------|
| **Local** | 1 | 1 | 2 cores | 4 GB | 20 GB |
| **Development** | 2 | 2 | 4 cores | 8 GB | 50 GB |
| **Test** | 2 | 2 | 4 cores | 8 GB | 100 GB |
| **Staging** | 3 | 3 | 6 cores | 12 GB | 200 GB |
| **Production** | 4+ | 4+ | 8+ cores | 16+ GB | 500+ GB |

#### Container Orchestration

**Recommended Platforms:**
- Docker Compose (for single-server deployments)
- Kubernetes (for multi-server deployments)
- Docker Swarm (alternative orchestration)

**Container Health Checks:**
- Application: `GET /srv/status` (200 OK) - Interval: 30s, Timeout: 10s, Retries: 3, Start Period: 60s
- Database: `pg_isready -U ${DB_USER}` - Interval: 10s, Timeout: 5s, Retries: 5, Start Period: 30s
- Redis: `redis-cli -a ${REDIS_PASSWORD} ping` (PONG) - Interval: 10s, Timeout: 5s, Retries: 5, Start Period: 10s
- Nginx: `GET /health` (200 OK) - Interval: 30s, Timeout: 10s, Retries: 3
- Sidekiq: Process check + Redis connectivity - Interval: 60s, Timeout: 10s, Retries: 3

**Container Resource Limits:**
- **CPU Limits**: Prevent resource exhaustion, allow bursting
- **Memory Limits**: Hard limit with OOM killer, soft limit for warnings
- **Process Limits**: Prevent fork bombs
- **File Descriptor Limits**: Sufficient for connection handling
- **Network Bandwidth**: Rate limiting to prevent abuse

**Container Security:**
- **Non-Root User**: All containers run as non-root (UID 1000+)
- **Read-Only Root FS**: Where possible, mount writable directories as volumes
- **Capabilities**: Drop all capabilities, add only required
- **Seccomp Profile**: Restrict system calls
- **AppArmor/SELinux**: Enable if supported

---

## Database Infrastructure

### PostgreSQL Requirements

#### Version & Configuration

- **Version**: PostgreSQL 13 or higher (14+ recommended)
- **Encoding**: UTF-8
- **Locale**: en_US.UTF-8
- **Extensions Required**:
  - `pg_trgm` (trigram extension for search)
  - `hstore` (key-value storage)
  - `pg_stat_statements` (query statistics)

#### Database Configuration

**Production Settings:**
```sql
shared_buffers = 256MB
max_connections = 200
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
```

#### Database Sizing

| Environment | Database Size | Connections | Storage | Backup Retention |
|------------|--------------|-------------|---------|------------------|
| **Local** | 1-5 GB | 20 | 10 GB | 7 days |
| **Development** | 10-50 GB | 50 | 50 GB | 14 days |
| **Test** | 20-100 GB | 100 | 100 GB | 30 days |
| **Staging** | 50-200 GB | 150 | 200 GB | 30 days |
| **Production** | 100+ GB | 200 | 500+ GB | 90 days |

#### High Availability

**Recommended Setup:**
- **Primary Database**: Read/write operations
- **Replica Database(s)**: Read-only operations, failover
- **Connection Pooling**: PgBouncer or similar
- **Automated Failover**: Patroni, repmgr, or managed service

**Backup Strategy:**
- **Full Backups**: Daily at 2 AM UTC
- **WAL Archiving**: Continuous
- **Point-in-Time Recovery**: Enabled
- **Backup Storage**: Separate from primary database

#### Database Users and Roles

**Required Database Users:**

| User | Purpose | Permissions | Environment Variable |
|------|---------|-------------|---------------------|
| **community** (or `${COMMUNITY_DB_USER}`) | Application user | SELECT, INSERT, UPDATE, DELETE on all tables | `DISCOURSE_DB_USERNAME` |
| **community_admin** (optional) | Admin operations | Full access (DDL, DML) for migrations | Used during deployment only |
| **community_readonly** (optional) | Read replicas | SELECT only | For read replicas |

**User Configuration:**
- **Application User**: 
  - Username: `community` (or from `COMMUNITY_DB_USER` env var)
  - Password: Strong password (32+ characters, stored in `COMMUNITY_DB_PASSWORD`)
  - Permissions: DML only (SELECT, INSERT, UPDATE, DELETE)
  - No DDL permissions (CREATE, DROP, ALTER)
  - Connection limit: Based on `max_connections` setting
- **Admin User** (for migrations):
  - Used only during deployment/migrations
  - Full database access
  - Should be rotated after migrations

**Connection Pooling:**
- Use PgBouncer or similar for connection pooling
- Pool mode: Transaction pooling recommended
- Max connections per user: Configure based on environment

#### Database Tables

The database contains **200+ tables** organized into the following categories:

**Core User Management Tables:**
- `users` - User accounts and authentication
- `user_emails` - User email addresses (primary and secondary)
- `user_profiles` - Extended user profile information
- `user_options` - User preferences and settings
- `user_stats` - User statistics (posts, topics, etc.)
- `user_visits` - User visit tracking
- `user_auth_tokens` - Authentication tokens and sessions
- `email_tokens` - Email verification tokens
- `user_actions` - User activity tracking
- `user_badges` - User badge assignments
- `user_notification_schedules` - User notification preferences

**Content Tables:**
- `topics` - Discussion topics/threads
- `posts` - Individual posts within topics
- `post_actions` - Post actions (likes, flags, bookmarks)
- `post_action_types` - Types of post actions
- `post_revisions` - Post edit history
- `post_timings` - Post read timing data
- `topic_users` - User-topic relationships (tracking, notifications)
- `topic_timers` - Scheduled topic actions (close, delete, etc.)
- `topic_links` - Links within topics
- `topic_allowed_users` - Private topic participants
- `topic_allowed_groups` - Groups allowed in private topics

**Category and Tag Tables:**
- `categories` - Forum categories
- `category_users` - Category-specific user settings
- `category_custom_fields` - Category metadata
- `category_featured_topics` - Featured topics per category
- `tags` - Content tags
- `topic_tags` - Topic-tag relationships
- `tag_groups` - Tag groupings
- `tag_group_memberships` - Tag group memberships
- `tag_localizations` - Tag translations

**Moderation Tables:**
- `reviewables` - Items pending review
- `reviewable_scores` - Review scores and history
- `reviewable_histories` - Review action history
- `reviewable_claimed_topics` - Claimed review topics
- `flags` - Content flags
- `post_actions` - Post moderation actions

**Notification and Messaging Tables:**
- `notifications` - User notifications
- `notification_settings` - Notification preferences
- `user_notification_schedules` - Scheduled notifications
- `incoming_emails` - Incoming email processing
- `email_logs` - Email delivery logs
- `incoming_links` - Incoming link tracking

**Search Tables:**
- `posts_search` - Full-text search index for posts
- `users_search` - Full-text search index for users
- `categories_search` - Full-text search index for categories

**Badge and Achievement Tables:**
- `badges` - Available badges
- `user_badges` - User badge assignments
- `badge_groupings` - Badge organization
- `badge_types` - Badge type definitions

**Group and Permission Tables:**
- `groups` - User groups
- `group_users` - Group memberships
- `group_requests` - Group join requests
- `group_histories` - Group change history
- `group_mentions` - Group mentions in posts

**Upload and Media Tables:**
- `uploads` - File uploads
- `optimized_images` - Optimized image versions
- `user_uploads` - User upload tracking

**Site Configuration Tables:**
- `site_settings` - Site-wide settings
- `site_setting_groups` - Setting organization
- `site_customizations` - Theme customizations
- `javascript_caches` - Cached JavaScript assets
- `stylesheets` - Stylesheet definitions

**Plugin and Extension Tables:**
- `plugin_store_rows` - Plugin data storage
- `web_hooks` - Webhook configurations
- `web_hook_events` - Webhook event logs
- Various plugin-specific tables (poll, solved, etc.)

**System Tables:**
- `schema_migrations` - Migration tracking
- `ar_internal_metadata` - Rails metadata
- `message_bus` - Message bus data

**Note**: Complete table list with schemas is generated during `rake db:migrate`. The application uses ActiveRecord migrations to create and manage all tables.

#### Database Indexes

**Critical Indexes Required for Performance:**

**User Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Username lookups
CREATE INDEX index_users_on_username_lower ON users (username_lower);
CREATE UNIQUE INDEX index_users_on_username_lower ON users (username_lower);

-- Email lookups
CREATE INDEX index_users_on_email ON users (email);

-- Active user queries
CREATE INDEX index_users_on_active ON users (active) WHERE active = true;

-- Trust level queries
CREATE INDEX index_users_on_trust_level ON users (trust_level);

-- Admin/moderator queries
CREATE INDEX index_users_on_admin ON users (admin) WHERE admin = true;
CREATE INDEX index_users_on_moderator ON users (moderator) WHERE moderator = true;

-- Search indexes (GIN)
CREATE INDEX idx_search_user ON users USING GIN(to_tsvector('english', username));
```

**Topic Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Category queries
CREATE INDEX index_topics_on_category_id ON topics (category_id) WHERE deleted_at IS NULL;

-- User queries
CREATE INDEX idx_topics_user_id_deleted_at ON topics (user_id) WHERE deleted_at IS NULL;

-- Bumped/updated queries
CREATE INDEX index_topics_on_bumped_at ON topics (bumped_at DESC);
CREATE INDEX index_topics_on_updated_at ON topics (updated_at DESC);

-- Visibility queries
CREATE INDEX index_topics_on_visible ON topics (visible) WHERE visible = true;
CREATE INDEX index_topics_on_archetype ON topics (archetype);

-- Search indexes (GIN)
CREATE INDEX idx_search_thread ON topics USING GIN(to_tsvector('english', title));
```

**Post Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Topic queries (most critical)
CREATE INDEX index_posts_on_topic_id_and_post_number ON posts (topic_id, post_number);
CREATE INDEX index_posts_on_topic_id_and_created_at ON posts (topic_id, created_at);

-- User queries
CREATE INDEX idx_posts_user_id_deleted_at ON posts (user_id) WHERE deleted_at IS NULL;
CREATE INDEX index_posts_user_and_likes ON posts (user_id, like_count DESC, created_at DESC) WHERE post_number > 1;

-- Deleted posts
CREATE INDEX index_posts_on_deleted_at ON posts (deleted_at) WHERE deleted_at IS NOT NULL;

-- Editor queries
CREATE INDEX index_posts_on_deleted_by_id ON posts (deleted_by_id) WHERE deleted_by_id IS NOT NULL;
CREATE INDEX index_posts_on_last_editor_id ON posts (last_editor_id) WHERE last_editor_id IS NOT NULL;
CREATE INDEX index_posts_on_locked_by_id ON posts (locked_by_id) WHERE locked_by_id IS NOT NULL;
CREATE INDEX index_posts_on_reply_to_user_id ON posts (reply_to_user_id) WHERE reply_to_user_id IS NOT NULL;

-- Post type queries
CREATE INDEX index_posts_on_post_type ON posts (post_type) WHERE post_type != 1;

-- Search indexes (GIN)
CREATE INDEX idx_search_post ON posts_search USING GIN(search_data);
```

**Notification Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- User notification queries (most critical)
CREATE INDEX index_notifications_on_user_id_and_created_at ON notifications (user_id, created_at DESC);
CREATE INDEX index_notifications_on_user_id_and_read ON notifications (user_id, read) WHERE read = false;

-- Notification type queries
CREATE INDEX index_notifications_on_notification_type ON notifications (notification_type);

-- JSONB indexes for notification data
CREATE INDEX index_notifications_on_data_original_username ON notifications USING GIN ((data->>'original_username'));
CREATE INDEX index_notifications_on_data_display_username ON notifications USING GIN ((data->>'display_username'));
CREATE INDEX index_notifications_on_data_username ON notifications USING GIN ((data->>'username'));
```

**Post Actions Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Post action lookups
CREATE INDEX index_post_actions_on_post_id ON post_actions (post_id);
CREATE INDEX index_post_actions_on_user_id ON post_actions (user_id);
CREATE INDEX index_post_actions_on_post_action_type_id ON post_actions (post_action_type_id);

-- Moderation action queries
CREATE INDEX index_post_actions_on_agreed_by_id ON post_actions (agreed_by_id) WHERE agreed_by_id IS NOT NULL;
CREATE INDEX index_post_actions_on_deferred_by_id ON post_actions (deferred_by_id) WHERE deferred_by_id IS NOT NULL;
CREATE INDEX index_post_actions_on_deleted_by_id ON post_actions (deleted_by_id) WHERE deleted_by_id IS NOT NULL;
CREATE INDEX index_post_actions_on_disagreed_by_id ON post_actions (disagreed_by_id) WHERE disagreed_by_id IS NOT NULL;
```

**Category Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Parent category queries
CREATE INDEX index_categories_on_parent_category_id ON categories (parent_category_id);

-- Search indexes (GIN)
CREATE INDEX idx_search_category ON categories_search USING GIN(search_data);
```

**Tag Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Tag name lookups
CREATE INDEX index_tags_on_name ON tags (name);
CREATE UNIQUE INDEX index_tags_on_lower_name ON tags (lower(name));

-- Topic-tag relationships
CREATE INDEX index_topic_tags_on_topic_id ON topic_tags (topic_id);
CREATE INDEX index_topic_tags_on_tag_id ON topic_tags (tag_id);
CREATE UNIQUE INDEX index_topic_tags_on_tag_id_and_topic_id ON topic_tags (tag_id, topic_id);
```

**Reviewable Table Indexes:**
```sql
-- Primary key (automatic)
PRIMARY KEY (id)

-- Reviewable status queries
CREATE INDEX index_reviewables_on_status ON reviewables (status);
CREATE INDEX index_reviewables_on_reviewable_type ON reviewables (reviewable_type);
CREATE INDEX index_reviewables_on_created_at ON reviewables (created_at DESC);

-- Reviewable scores
CREATE INDEX index_reviewable_scores_on_reviewable_score_type ON reviewable_scores (reviewable_score_type);
```

**Topic Links Indexes:**
```sql
-- User link tracking
CREATE INDEX index_topic_links_on_user_and_clicks ON topic_links (user_id, clicks DESC, created_at DESC) 
  WHERE (NOT reflection AND NOT quote AND NOT internal);
```

**Directory Items Indexes:**
```sql
-- User directory queries
CREATE INDEX index_directory_items_on_user_id ON directory_items (user_id);
CREATE INDEX index_directory_items_on_period_type ON directory_items (period_type);
```

**Index Creation Notes:**
- All indexes are created automatically during `rake db:migrate`
- Indexes use `CONCURRENTLY` where possible to avoid locking
- Partial indexes (WHERE clauses) are used extensively for performance
- GIN indexes are used for full-text search
- Composite indexes are optimized for common query patterns
- Indexes are maintained automatically by PostgreSQL

**Index Maintenance:**
- Run `VACUUM ANALYZE` regularly (automated via pg_cron or similar)
- Monitor index usage with `pg_stat_user_indexes`
- Review unused indexes quarterly
- Reindex large tables during maintenance windows if needed

---

## Cache & Redis Infrastructure

### Redis Requirements

#### Version & Configuration

- **Version**: Redis 7 or higher
- **Persistence**: AOF (Append Only File) enabled
- **Memory Policy**: `allkeys-lru` (evict least recently used)
- **Max Memory**: 512 MB - 2 GB (depending on environment)

#### Redis Configuration

**Production Settings:**
```redis
appendonly yes
maxmemory 2gb
maxmemory-policy allkeys-lru
requirepass <strong-password>
```

#### Redis Database Allocation

| Database | Purpose | Used By |
|---------|---------|---------|
| **DB 0** | Discourse default | Community app |
| **DB 1** | Community service cache | SIRA AI app integration |
| **DB 2** | Auth service | SIRA AI app (if shared) |
| **DB 3** | User service | SIRA AI app (if shared) |
| **DB 4** | Profile service | SIRA AI app (if shared) |

#### Redis Key Patterns and Namespaces

**Key Naming Convention:**
- All keys are namespaced by site/database name: `{namespace}:{key}`
- Namespace is automatically prepended by `DiscourseRedis` class
- Example: `community_production:cache:user:123`

**Core Redis Key Patterns:**

**Cache Keys:**
- `cache:{key}` - General application cache
- `cache:{model}:{id}` - Model-specific cache (e.g., `cache:user:123`)
- `cache:{fragment}` - Fragment cache for views
- `cache:global:{key}` - Global cache (not namespaced)

**Rate Limiting Keys:**
- `l-rate-limit3:{user_id}:{type}` - User rate limits
- `GLOBAL::l-rate-limit3:{type}` - Global rate limits
- Used for: API calls, login attempts, search queries, uploads

**Session and Authentication Keys:**
- `user_auth_token:{token}` - Authentication tokens
- `user_sessions:{user_id}` - Active user sessions
- `email_token:{token}` - Email verification tokens

**Background Job Keys (Sidekiq):**
- `queue:{queue_name}` - Job queues (default, critical, low)
- `queue:default` - Default job queue
- `queue:critical` - Critical priority jobs
- `queue:low` - Low priority jobs
- `schedule` - Scheduled jobs
- `retry` - Failed jobs to retry
- `dead` - Dead jobs
- `stat:processed` - Job statistics
- `stat:failed` - Failure statistics

**Message Bus Keys:**
- `message_bus:{channel}` - Real-time message channels
- `message_bus:channel:{channel}:seq` - Channel sequence numbers
- Used for: Real-time updates, notifications, presence

**Search and Indexing Keys:**
- `search:{query_hash}` - Search result cache
- `search_index:{type}` - Search index metadata

**User Activity Keys:**
- `user_last_seen:{user_id}` - Last seen timestamps
- `user_visit:{user_id}:{date}` - Daily visit tracking
- `user_action:{user_id}:{action}` - User action tracking

**Notification Keys:**
- `notification:{user_id}` - User notification cache
- `unread_notifications:{user_id}` - Unread notification count

**Topic and Post Keys:**
- `topic:{topic_id}:views` - Topic view counts
- `topic:{topic_id}:read:{user_id}` - User read tracking
- `post:{post_id}:like_count` - Post like counts (cached)

**Category and Tag Keys:**
- `category:{category_id}:stats` - Category statistics
- `tag:{tag_id}:stats` - Tag statistics

**Site Settings Keys:**
- `site_settings:{key}` - Cached site settings
- `site_customization:{id}` - Theme customization cache

**Plugin Keys:**
- `plugin:{plugin_name}:{key}` - Plugin-specific data
- Various plugin-specific patterns

**Key Expiration:**
- Cache keys: TTL varies (5 minutes to 24 hours)
- Rate limit keys: TTL based on rate limit window
- Session keys: TTL based on session timeout (default 30 minutes)
- Search cache: TTL 2-15 minutes
- Statistics: TTL 1-24 hours

**Key Management:**
- Keys are automatically namespaced per site/database
- Use `DiscourseRedis.without_namespace` for global keys
- Key cleanup handled by Redis eviction policy (`allkeys-lru`)
- Monitor key count and memory usage regularly

#### Redis Sizing

| Environment | Memory | Persistence | Replication |
|------------|--------|-------------|-------------|
| **Local** | 256 MB | AOF | None |
| **Development** | 512 MB | AOF | Optional |
| **Test** | 1 GB | AOF | Optional |
| **Staging** | 1 GB | AOF | Replica |
| **Production** | 2 GB | AOF | Replica + Sentinel |

#### High Availability

**Recommended Setup:**
- **Primary Redis**: Write operations
- **Replica Redis**: Read operations, failover
- **Redis Sentinel**: Automatic failover
- **Password Protection**: Required for all environments

---

## Storage Requirements

### Persistent Volumes

#### Volume Types

1. **Database Volume** (`postgres_data`)
   - **Purpose**: PostgreSQL data directory
   - **Size**: 50 GB - 500 GB (depending on environment)
   - **Type**: SSD recommended
   - **Backup**: Daily snapshots
   - **Path**: `/var/lib/postgresql/data/pgdata` (container)
   - **Mount**: `postgres_data:/var/lib/postgresql/data`

2. **Redis Volume** (`redis_data`)
   - **Purpose**: Redis AOF files
   - **Size**: 1 GB - 10 GB
   - **Type**: SSD recommended
   - **Backup**: Daily snapshots
   - **Path**: `/data` (container)
   - **Mount**: `redis_data:/data`

3. **Uploads Volume** (`public/uploads`)
   - **Purpose**: User-uploaded files (images, attachments)
   - **Size**: 100 GB - 1 TB (grows with usage)
   - **Type**: SSD for production
   - **Backup**: Daily incremental backups
   - **Path**: `/var/www/community/public/uploads` (container)
   - **Mount**: `./public/uploads:/var/www/community/public/uploads`
   - **Permissions**: 755 (rwxr-xr-x)
   - **Owner**: Application user (UID 1000+)

4. **Backups Volume** (`public/backups`)
   - **Purpose**: Database and application backups
   - **Size**: 200 GB - 2 TB (depends on retention)
   - **Type**: Standard storage acceptable
   - **Retention**: 7-90 days (environment-dependent)
   - **Path**: `/var/www/community/public/backups` (container)
   - **Mount**: `./public/backups:/var/www/community/public/backups`
   - **Permissions**: 755
   - **Backup Strategy**: Daily full backups, incremental where possible

5. **Logs Volume** (`log`)
   - **Purpose**: Application logs
   - **Size**: 10 GB - 100 GB
   - **Type**: Standard storage
   - **Retention**: 30-90 days
   - **Path**: `/var/www/community/log` (container)
   - **Mount**: `./log:/var/www/community/log`
   - **Permissions**: 755
   - **Log Rotation**: Daily rotation, compress after 7 days

6. **Temporary Files Volume** (`tmp`)
   - **Purpose**: Temporary processing files
   - **Size**: 5 GB - 50 GB
   - **Type**: Standard storage
   - **Cleanup**: Automatic
   - **Path**: `/var/www/community/tmp` (container)
   - **Mount**: `./tmp:/var/www/community/tmp`
   - **Permissions**: 755
   - **Cleanup Policy**: Files older than 7 days automatically removed

### File System Structure

**Application Root Directory:**
```
/var/www/community/          # Application root (container path)
├── app/                     # Application code
├── config/                  # Configuration files
│   ├── database.yml        # Database configuration
│   ├── discourse.conf      # Discourse configuration
│   └── nginx.conf          # Nginx configuration (if applicable)
├── public/                  # Public web root
│   ├── uploads/            # User uploads (persistent volume)
│   │   ├── original/       # Original uploaded files
│   │   └── optimized/     # Optimized images
│   ├── backups/            # Database backups (persistent volume)
│   ├── assets/             # Compiled assets (CSS, JS)
│   └── images/             # Static images
├── log/                     # Application logs (persistent volume)
│   ├── production.log      # Production log
│   ├── sidekiq.log         # Background job log
│   └── nginx/              # Nginx logs (if applicable)
├── tmp/                     # Temporary files (persistent volume)
│   ├── cache/              # Application cache
│   ├── pids/               # Process IDs
│   └── sockets/            # Unix sockets
└── db/                      # Database files (migrations, seeds)
```

**Required Directory Permissions:**

| Directory | Permissions | Owner | Purpose |
|-----------|------------|-------|---------|
| `/var/www/community` | 755 | root | Application root |
| `/var/www/community/public/uploads` | 755 | app_user (UID 1000+) | User uploads |
| `/var/www/community/public/backups` | 755 | app_user | Backups |
| `/var/www/community/log` | 755 | app_user | Logs |
| `/var/www/community/tmp` | 755 | app_user | Temporary files |
| `/var/www/community/tmp/cache` | 777 | app_user | Cache (writable) |
| `/var/www/community/tmp/pids` | 755 | app_user | Process IDs |

**File System Requirements:**

**Disk Space Allocation by Environment:**

| Environment | Total | Database | Uploads | Backups | Logs | Temp |
|------------|-------|----------|---------|---------|------|------|
| **Local** | 20 GB | 5 GB | 5 GB | 5 GB | 1 GB | 1 GB |
| **Development** | 100 GB | 20 GB | 30 GB | 30 GB | 5 GB | 5 GB |
| **Test** | 200 GB | 50 GB | 50 GB | 70 GB | 10 GB | 10 GB |
| **Staging** | 500 GB | 100 GB | 150 GB | 200 GB | 20 GB | 20 GB |
| **Production** | 1 TB+ | 200 GB+ | 500 GB+ | 500 GB+ | 50 GB+ | 50 GB+ |

**File System Features:**
- **Inode Limits**: Ensure sufficient inodes (recommend 1M+ for production)
- **Quota Management**: Set quotas on uploads directory to prevent disk fill
- **Symbolic Links**: Support for symlinks (used for asset management)
- **Extended Attributes**: Not required but supported
- **ACL Support**: Optional, not required

**Storage Performance Requirements:**

| Volume Type | IOPS | Latency | Throughput |
|------------|------|---------|------------|
| **Database** | 3000+ | < 5ms | 500+ MB/s |
| **Uploads** | 1000+ | < 10ms | 200+ MB/s |
| **Backups** | 500+ | < 50ms | 100+ MB/s |
| **Logs** | 100+ | < 100ms | 50+ MB/s |
| **Temp** | 500+ | < 20ms | 100+ MB/s |

**Backup Storage Requirements:**

**Backup File Naming Convention:**
- Database backups: `{database_name}_{timestamp}.dump.gz`
- Upload backups: `uploads_{timestamp}.tar.gz`
- Configuration backups: `config_{timestamp}.tar.gz`

**Backup Retention:**
- **Local**: 7 days
- **Development**: 14 days
- **Test**: 30 days
- **Staging**: 30 days
- **Production**: 90 days

**Backup Storage Locations:**
- Primary: Local backup volume (`public/backups`)
- Secondary: Remote object storage (S3, Azure Blob, etc.)
- Tertiary: Off-site backup (for disaster recovery)

### Storage Sizing by Environment

| Environment | Total Storage | Database | Uploads | Backups | Logs |
|------------|--------------|----------|---------|---------|------|
| **Local** | 20 GB | 5 GB | 5 GB | 5 GB | 1 GB |
| **Development** | 100 GB | 20 GB | 30 GB | 30 GB | 5 GB |
| **Test** | 200 GB | 50 GB | 50 GB | 70 GB | 10 GB |
| **Staging** | 500 GB | 100 GB | 150 GB | 200 GB | 20 GB |
| **Production** | 1 TB+ | 200 GB+ | 500 GB+ | 500 GB+ | 50 GB+ |

### Storage Performance

**IOPS Requirements:**
- **Database**: 3000+ IOPS (SSD)
- **Uploads**: 1000+ IOPS (SSD for production)
- **Backups**: 500+ IOPS (standard acceptable)
- **Logs**: 100+ IOPS (standard acceptable)

---

## Network Configuration

### Docker Network

#### Network Name: `sira-network`

**Configuration:**
- **Type**: Bridge network
- **Driver**: bridge
- **Subnet**: Configurable (e.g., 172.20.0.0/16)
- **Gateway**: Auto-assigned
- **DNS**: Internal Docker DNS

**Services on Network:**
- `sira-community-app`
- `sira-community-sidekiq`
- `sira-community-nginx`
- `sira-community-postgres`
- `sira-community-redis`
- Other SIRA services (if integrated)

### Port Configuration

#### Internal Ports (Docker Network)

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| **Rails App** | 3000 | HTTP | Application server |
| **PostgreSQL** | 5432 | TCP | Database |
| **Redis** | 6379 | TCP | Cache |
| **Nginx** | 80 | HTTP | HTTP traffic |
| **Nginx** | 443 | HTTPS | HTTPS traffic |

#### External Ports (Public/Private)

| Environment | HTTP Port | HTTPS Port | Notes |
|------------|-----------|------------|-------|
| **Local** | 8080 | 8443 | Development only |
| **Development** | 80 | 443 | Standard ports |
| **Test** | 80 | 443 | Standard ports |
| **Staging** | 80 | 443 | Standard ports |
| **Production** | 80 | 443 | Standard ports |

### Firewall Rules

#### Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 80 | TCP | 0.0.0.0/0 | HTTP traffic |
| 443 | TCP | 0.0.0.0/0 | HTTPS traffic |
| 22 | TCP | Admin IPs | SSH access |

#### Outbound Rules

| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 443 | TCP | SMTP servers | Email sending |
| 443 | TCP | SIRA API | API integration |
| 53 | UDP/TCP | DNS servers | DNS resolution |
| 80/443 | TCP | Package repositories | Updates |

### Network Security

- **VPC/Private Network**: Recommended for production
- **Security Groups**: Restrict database/Redis to internal network only
- **DDoS Protection**: Cloud provider DDoS protection recommended
- **WAF**: Web Application Firewall for production

---

## Load Balancing & High Availability

### Load Balancer Configuration

#### Requirements

- **Type**: Application Load Balancer (Layer 7)
- **Protocol**: HTTP/HTTPS
- **Health Checks**: `GET /srv/status` (200 OK)
- **Session Affinity**: Not required (stateless application)
- **SSL Termination**: At load balancer or Nginx

#### Load Balancer Rules

```
HTTP (Port 80) → Redirect to HTTPS
HTTPS (Port 443) → Forward to Nginx (Port 80)
Health Check → GET /srv/status (every 30s)
```

#### High Availability Setup

**Multi-Zone Deployment:**
- **Zone 1**: Application Pod 1, Database Primary, Redis Primary, Nginx 1
- **Zone 2**: Application Pod 2, Database Replica, Redis Replica, Nginx 2
- **Zone 3** (Production): Application Pod 3, Database Standby, Redis Standby (optional)
- **Load Balancer**: Routes traffic across zones with health checks
- **Zone Distribution**: 50/50 or 33/33/33 distribution for optimal availability

**Failover Configuration:**
- **Database**: 
  - Automatic failover to replica (Patroni/repmgr)
  - Failover time: < 30 seconds
  - Connection pooling with automatic reconnection
  - Read replicas for read scaling
  - Synchronous replication for zero data loss (optional, with performance trade-off)
- **Redis**: 
  - Automatic failover via Sentinel (3+ sentinel instances)
  - Failover time: < 10 seconds
  - Replication lag monitoring
  - Automatic reconnection on failover
- **Application**: 
  - Load balancer health checks remove unhealthy instances
  - Graceful shutdown (drain connections before termination)
  - Rolling deployments (zero-downtime)
  - Blue-green deployments for major updates
- **Nginx**: 
  - Multiple instances behind load balancer
  - Health checks remove unhealthy instances
  - Session persistence not required (stateless)

**High Availability Metrics:**
- **Target Uptime**: 99.9% (8.76 hours downtime/year)
- **RTO (Recovery Time Objective)**: 15 minutes
- **RPO (Recovery Point Objective)**: 1 hour (with WAL archiving)
- **MTTR (Mean Time To Recovery)**: < 15 minutes

**Disaster Recovery:**
- **Multi-Region**: Consider multi-region deployment for critical production
- **Backup Strategy**: 
  - Cross-region backups
  - Point-in-time recovery capability
  - Regular disaster recovery drills (quarterly)

---

## SSL/TLS Certificates

### Certificate Requirements

#### Production

- **Type**: Valid SSL/TLS certificate (Let's Encrypt or commercial)
- **Domain**: `community.sira.ai` (and `www.community.sira.ai` if needed)
- **Wildcard**: Optional (`*.sira.ai`)
- **Renewal**: Automatic (Let's Encrypt) or manual (commercial)

#### Certificate Installation

**Nginx Configuration:**
- Certificate file: `/etc/nginx/ssl/cert.pem`
- Private key: `/etc/nginx/ssl/key.pem`
- Intermediate CA: Included in cert.pem

**Let's Encrypt Setup:**
```bash
# Install certbot
apt-get install certbot

# Obtain certificate
certbot certonly --standalone -d community.sira.ai

# Auto-renewal (cron)
0 0 * * * certbot renew --quiet
```

### SSL/TLS Configuration

**Recommended Cipher Suites:**
- TLS 1.2 minimum
- TLS 1.3 preferred
- Strong cipher suites only
- HSTS enabled (1 year)

**Nginx SSL Settings:**
```nginx
# TLS Protocol Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;  # TLS 1.3 prefers server order

# Cipher Suites (TLS 1.2)
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_ecdh_curve secp384r1;

# Session Configuration
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;  # Disable for better security

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/nginx/ssl/chain.pem;

# Security Headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';" always;

# Certificate Configuration
ssl_certificate /etc/nginx/ssl/cert.pem;
ssl_certificate_key /etc/nginx/ssl/key.pem;

# DH Parameters (generate: openssl dhparam -out dhparam.pem 2048)
ssl_dhparam /etc/nginx/ssl/dhparam.pem;
```

**SSL Certificate Management:**
- **Certificate Monitoring**: Alert 30 days before expiration
- **Auto-Renewal**: Automated renewal with certbot or managed certificates
- **Certificate Chain**: Include full chain (intermediate + root)
- **Certificate Validation**: Regular validation of certificate chain
- **OCSP Stapling**: Enabled for improved performance and privacy

---

## DNS Configuration

### DNS Records Required

#### Production DNS

| Type | Name | Value | TTL | Purpose |
|------|------|-------|-----|---------|
| **A** | `community.sira.ai` | Load Balancer IP | 300 | Main domain |
| **A** | `www.community.sira.ai` | Load Balancer IP | 300 | WWW subdomain (optional) |
| **CNAME** | `*.community.sira.ai` | `community.sira.ai` | 300 | Wildcard (optional) |

#### Environment-Specific DNS

| Environment | Domain | Type | Value |
|------------|--------|------|-------|
| **Development** | `community-dev.sira.ai` | A | Dev server IP |
| **Test** | `community-test.sira.ai` | A | Test server IP |
| **Staging** | `community-staging.sira.ai` | A | Staging server IP |
| **Production** | `community.sira.ai` | A | Load balancer IP |

### DNS Propagation

- **TTL**: 300 seconds (5 minutes) for quick updates
- **Propagation Time**: 5-30 minutes typically
- **Health Checks**: Monitor DNS resolution

---

## Email Infrastructure

### SMTP Configuration

#### Production SMTP (SendGrid)

- **Host**: `smtp.sendgrid.net`
- **Port**: 587 (TLS) or 465 (SSL)
- **Authentication**: API Key
- **Username**: `apikey`
- **Password**: SendGrid API Key
- **Domain**: `sira.ai`

#### Email Requirements

**Email Types:**
- User registration emails
- Password reset emails
- Notification emails
- Digest emails
- Admin notifications

**Email Volume Estimates:**
- **Small Community** (< 1,000 users): 100-500 emails/day
- **Medium Community** (1,000-10,000 users): 500-5,000 emails/day
- **Large Community** (10,000+ users): 5,000+ emails/day

#### SMTP Alternatives

- **SendGrid**: Recommended (configured)
- **Amazon SES**: Alternative
- **Mailgun**: Alternative
- **Postmark**: Alternative
- **Self-hosted**: Not recommended for production

---

## Monitoring & Logging

### Application Monitoring

#### Metrics to Monitor

**Application Metrics:**
- **Request Metrics**:
  - Request rate (requests/second) - Alert if > 1000 req/s sustained
  - Response time (p50, p95, p99) - Alert if p95 > 2s, p99 > 5s
  - Error rate (4xx, 5xx) - Alert if error rate > 1%
  - Request size and response size
  - Endpoint-specific metrics (slow endpoints)
- **User Metrics**:
  - Active users (concurrent, daily active, monthly active)
  - User registration rate
  - User login rate
  - Failed login attempts (security alert if > 10/minute)
- **Database Metrics**:
  - Query time (p50, p95, p99) - Alert if p95 > 500ms
  - Connection pool usage - Alert if > 80%
  - Slow queries (> 1 second)
  - Database size and growth rate
  - Replication lag - Alert if > 5 seconds
- **Redis Metrics**:
  - Redis latency (p50, p95, p99) - Alert if p95 > 10ms
  - Memory usage - Alert if > 80%
  - Hit rate - Alert if < 90%
  - Connection count
  - Replication lag - Alert if > 1 second
- **Background Jobs**:
  - Sidekiq queue depth - Alert if > 1000 jobs
  - Job processing time
  - Failed jobs - Alert if > 10 failures/hour
  - Job retry rate

**System Metrics:**
- **Compute Metrics**:
  - CPU usage (per container, per host) - Alert if > 80% for 5 minutes
  - Memory usage (per container, per host) - Alert if > 85%
  - Disk I/O (read/write IOPS, latency) - Alert if latency > 100ms
  - Network I/O (bandwidth, packet rate) - Alert if bandwidth > 80% capacity
- **Container Metrics**:
  - Container health status
  - Container restart count - Alert if > 3 restarts/hour
  - Container resource limits (CPU throttling, OOM kills)
- **Storage Metrics**:
  - Disk usage - Alert if > 80%
  - Disk I/O latency
  - Backup success/failure
  - Backup size and duration

**Business Metrics:**
- Topics created per day
- Posts created per day
- User engagement metrics
- Search query volume
- Email delivery rate
- API usage (if exposed)

#### Monitoring Tools

**Recommended Stack:**
- **Metrics Collection**: Prometheus (open source) or Datadog/New Relic (managed)
- **Visualization**: Grafana (with Prometheus) or native dashboards
- **APM (Application Performance Monitoring)**: 
  - New Relic, Datadog APM, or Elastic APM
  - Distributed tracing for request flows
  - Code-level performance insights
- **Log Aggregation**: 
  - ELK Stack (Elasticsearch, Logstash, Kibana)
  - Loki + Grafana (lightweight alternative)
  - CloudWatch Logs (AWS) or Azure Monitor Logs
- **Uptime Monitoring**: 
  - Pingdom, UptimeRobot, or cloud provider monitoring
  - External health checks from multiple locations
  - SSL certificate expiration monitoring

**Monitoring Dashboards:**
- **Application Dashboard**: Request rate, response time, error rate, active users
- **Infrastructure Dashboard**: CPU, memory, disk, network across all hosts
- **Database Dashboard**: Query performance, connection pool, replication status
- **Redis Dashboard**: Latency, memory usage, hit rate, replication
- **Security Dashboard**: Failed logins, rate limit hits, suspicious activity
- **Business Dashboard**: User growth, content creation, engagement metrics

### Logging

#### Log Types

1. **Application Logs** (`log/production.log`):
   - Rails application logs (INFO, WARN, ERROR levels)
   - Request logs (method, path, status, duration, IP)
   - Error logs with stack traces
   - Access logs (user, action, resource)
   - Structured JSON logging for parsing

2. **Nginx Logs** (`docker/nginx/logs/`):
   - Access logs (IP, method, path, status, user agent, referer)
   - Error logs (configuration errors, upstream errors)
   - Custom log format with request ID for correlation

3. **Database Logs**:
   - PostgreSQL logs (errors, slow queries, connections)
   - Slow query log (queries > 1 second)
   - Connection log
   - Audit log (DDL changes, privilege changes)

4. **Container Logs**:
   - Docker container stdout/stderr
   - Sidekiq job logs
   - Container lifecycle events

5. **Security Logs**:
   - Authentication attempts (success and failure)
   - Authorization failures
   - Rate limit violations
   - Suspicious activity
   - Admin actions

#### Log Aggregation

- **Centralized Logging**: All logs sent to centralized log aggregation system
- **Log Retention**: 
  - Application logs: 90 days
  - Access logs: 30 days
  - Security logs: 1 year (compliance requirement)
  - Audit logs: 7 years (compliance requirement)
- **Log Rotation**: 
  - Daily rotation
  - Compression after rotation
  - Automatic cleanup of old logs
- **Log Parsing**: 
  - Structured logging (JSON) for easy parsing
  - Log parsing rules for common patterns
  - Log correlation using request IDs

**Log Analysis:**
- **Search Capabilities**: Full-text search across all logs
- **Log Correlation**: Correlate logs by request ID, user ID, time
- **Anomaly Detection**: Detect unusual patterns in logs
- **Compliance Reporting**: Generate reports for compliance audits

#### Log Retention

| Environment | Application Logs | Access Logs | Security Logs | Audit Logs |
|------------|-----------------|-------------|---------------|------------|
| **Local** | 7 days | 3 days | 30 days | 90 days |
| **Development** | 14 days | 7 days | 90 days | 1 year |
| **Test** | 30 days | 14 days | 90 days | 1 year |
| **Staging** | 30 days | 14 days | 1 year | 7 years |
| **Production** | 90 days | 30 days | 1 year | 7 years |

### Alerting

#### Alert Severity Levels

- **Critical**: Service down, data loss risk, security breach
- **High**: Performance degradation, high error rate, resource exhaustion
- **Medium**: Warning conditions, capacity planning needs
- **Low**: Informational, trends to watch

#### Alert Conditions

**Critical Alerts (Immediate Response):**
- Application health check failures (> 2 minutes)
- Database connection failures
- Redis connection failures
- Disk space > 95%
- Memory usage > 95%
- Error rate > 5%
- Security incidents (brute force, suspicious activity)

**High Priority Alerts (Response within 1 hour):**
- Response time p95 > 3 seconds
- Error rate > 1%
- Database query time p95 > 1 second
- Redis latency p95 > 50ms
- CPU usage > 85% for 10 minutes
- Sidekiq queue depth > 5000 jobs

**Medium Priority Alerts:**
- Response time p95 > 2 seconds
- Error rate > 0.5%
- Disk usage > 80%
- Memory usage > 80%
- Backup failures

#### Alert Channels

- **Critical**: PagerDuty, phone call, SMS
- **High**: Slack/Teams channel, email
- **Medium/Low**: Email, dashboard notifications

---

## Backup & Disaster Recovery

### Backup Strategy

#### Database Backups

**Full Backups:**
- **Frequency**: Daily at 2 AM UTC
- **Retention**: 30 days (production), 7 days (other environments)
- **Storage**: Separate backup storage (S3, Azure Blob, etc.)
- **Compression**: Enabled (gzip)

**WAL Archiving:**
- **Continuous**: Enabled
- **Retention**: 7 days
- **Point-in-Time Recovery**: Supported

**Backup Verification:**
- **Weekly**: Restore test to verify backup integrity
- **Monthly**: Full disaster recovery drill

#### Application Backups

**Uploads Backup:**
- **Frequency**: Daily incremental, weekly full
- **Retention**: 30 days
- **Storage**: Object storage (S3, Azure Blob)

**Configuration Backup:**
- **Frequency**: On every configuration change
- **Retention**: 90 days
- **Storage**: Version control (Git) + backup storage

### Disaster Recovery

#### Recovery Time Objectives (RTO)

| Environment | RTO | RPO |
|------------|-----|-----|
| **Development** | 4 hours | 24 hours |
| **Test** | 2 hours | 12 hours |
| **Staging** | 1 hour | 6 hours |
| **Production** | 15 minutes | 1 hour |

**RTO**: Recovery Time Objective (maximum downtime)  
**RPO**: Recovery Point Objective (maximum data loss)

**Note**: Production RTO of 15 minutes requires:
- Automated failover for database and Redis
- Pre-configured backup infrastructure
- Documented and tested recovery procedures
- Trained operations team
- Regular disaster recovery drills

#### Disaster Recovery Plan

1. **Database Recovery**:
   - Restore from latest backup
   - Apply WAL archives for point-in-time recovery
   - Verify data integrity

2. **Application Recovery**:
   - Deploy application from Git
   - Restore configuration files
   - Restore uploads from backup

3. **Infrastructure Recovery**:
   - Provision new infrastructure
   - Restore from backups
   - Update DNS records

---

## Security Requirements

### Security Hardening

#### Application Security

**Authentication & Authorization:**
- **Secret Key Base**: 128-character hex string (unique per environment), rotated quarterly
- **API Keys**: Strong, randomly generated (minimum 32 characters), rotated every 90 days
- **SSO Secret**: Minimum 32 characters, cryptographically secure random generation
- **Password Policy**: 
  - Minimum 12 characters
  - Require uppercase, lowercase, numbers, special characters
  - Password history: 5 previous passwords
  - Maximum age: 90 days
  - Account lockout after 5 failed attempts (15-minute lockout)
- **Session Management**: 
  - Secure session cookies (HttpOnly, Secure, SameSite=Strict)
  - Session timeout: 30 minutes of inactivity
  - Session rotation on privilege escalation

**Application Security Controls:**
- **Rate Limiting**: 
  - API endpoints: 100 requests/minute per IP
  - Authentication endpoints: 5 requests/minute per IP
  - Search endpoints: 20 requests/minute per user
  - Upload endpoints: 10 requests/minute per user
- **CSRF Protection**: Enabled with token validation on all state-changing operations
- **XSS Protection**: 
  - Content Security Policy (CSP) headers
  - Input sanitization and output encoding
  - X-XSS-Protection header enabled
- **SQL Injection Prevention**: 
  - Parameterized queries only (ActiveRecord ORM)
  - No raw SQL queries without sanitization
  - Database user with least privilege (read/write only, no DDL)
- **Input Validation**: 
  - All user inputs validated and sanitized
  - File upload restrictions (type, size, content scanning)
  - Maximum upload size: 10 MB per file
- **Security Headers**:
  ```
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  X-XSS-Protection: 1; mode=block
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  ```

#### Container Security

**Image Security:**
- **Base Images**: Use official, minimal base images (alpine variants preferred)
- **Image Scanning**: 
  - Scan all images for vulnerabilities before deployment
  - Use tools: Trivy, Clair, Snyk, or cloud provider scanning
  - Block deployment if critical/high vulnerabilities found
- **Image Updates**: 
  - Regular base image updates (monthly)
  - Security patches applied within 48 hours of release
  - Version pinning for reproducibility
- **Non-Root Containers**: 
  - All containers run as non-root user (UID 1000+)
  - Read-only root filesystem where possible
  - Minimal capabilities (drop all, add only required)

**Container Runtime Security:**
- **Resource Limits**: 
  - CPU limits: Prevent resource exhaustion attacks
  - Memory limits: Prevent OOM attacks
  - Process limits: Prevent fork bombs
- **Network Policies**: 
  - Restrict container-to-container communication
  - Only allow necessary ports
  - Deny all by default, allow explicitly
- **Secrets**: 
  - Never store secrets in images or environment variables in plain text
  - Use secret management services or encrypted volumes
  - Rotate secrets regularly

#### Infrastructure Security

**Server Hardening:**
- **Operating System**: 
  - Latest LTS version (Ubuntu 22.04+ or equivalent)
  - Automatic security updates enabled
  - Unnecessary services disabled
  - SELinux/AppArmor enabled (if applicable)
- **Firewall**: 
  - Restrict access to necessary ports only
  - Default deny policy
  - IP whitelisting for admin access
  - Rate limiting on firewall level
- **SSH Security**: 
  - Key-based authentication only (RSA 4096-bit or Ed25519)
  - Disable password authentication
  - Disable root login
  - Use SSH bastion host for production
  - Two-factor authentication for SSH (optional but recommended)
  - SSH connection timeout: 5 minutes
- **File System**: 
  - Separate partitions for /var, /tmp, /home
  - /tmp mounted with noexec, nosuid
  - Disk encryption at rest (LUKS or cloud provider encryption)

**Database Security:**
- **Access Control**: 
  - No public access, internal network only
  - IP whitelisting for admin access
  - Separate users for application (read/write) and admin (full access)
  - Database user with least privilege
- **Encryption**: 
  - TLS/SSL for all connections (TLS 1.2+)
  - Encryption at rest enabled
  - Key rotation every 90 days
- **Backup Security**: 
  - Encrypted backups
  - Backup access restricted to backup service account only
  - Backup verification and testing

**Redis Security:**
- **Access Control**: 
  - Password protected (strong password, minimum 32 characters)
  - Internal network only (no public access)
  - IP whitelisting if exposed
- **Encryption**: 
  - TLS/SSL for all connections (TLS 1.2+)
  - Encryption at rest (if supported by provider)
- **Configuration**: 
  - Disable dangerous commands (FLUSHALL, CONFIG, etc.)
  - Use Redis ACLs for fine-grained access control

**Secrets Management:**
- **Storage**: 
  - Use secret management service (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault, etc.)
  - Never commit secrets to version control
  - Encrypt secrets at rest and in transit
- **Rotation**: 
  - Automatic rotation where possible
  - Manual rotation every 90 days minimum
  - Rotation procedures documented and tested
- **Access Control**: 
  - Least privilege access to secrets
  - Audit logging for secret access
  - Separate secrets per environment

#### Network Security

**Network Segmentation:**
- **VPC/Private Network**: 
  - Private network for all internal services
  - Public-facing services in DMZ only
  - Database and Redis in private subnet only
  - Network ACLs configured
- **Security Groups/Firewall Rules**: 
  - Least privilege access (deny all, allow explicitly)
  - Source IP restrictions where possible
  - Port restrictions (only necessary ports open)
  - Regular review and cleanup of unused rules
- **Network Monitoring**: 
  - Intrusion detection system (IDS)
  - Network flow logging
  - Anomaly detection
  - Regular security audits

**DDoS Protection:**
- **Cloud Provider DDoS Protection**: 
  - Enable cloud provider DDoS protection (AWS Shield, Azure DDoS Protection, etc.)
  - Configure rate limiting at load balancer level
  - Geographic IP blocking for known bad actors
- **Application-Level Protection**: 
  - Rate limiting at application level
  - Request throttling
  - CAPTCHA for suspicious traffic
  - IP reputation checking

**Web Application Firewall (WAF):**
- **WAF Rules**: 
  - OWASP Top 10 protection
  - SQL injection prevention
  - XSS prevention
  - Rate limiting rules
  - Geographic restrictions (if needed)
- **WAF Providers**: 
  - AWS WAF, Azure Application Gateway WAF, Cloudflare WAF
  - Custom rules for application-specific threats
  - Regular rule updates

**TLS/SSL Security:**
- **Certificate Management**: 
  - Valid SSL/TLS certificates (no self-signed in production)
  - Automatic renewal (Let's Encrypt or managed certificates)
  - Certificate pinning for mobile apps (if applicable)
- **TLS Configuration**: 
  - TLS 1.2 minimum, TLS 1.3 preferred
  - Strong cipher suites only
  - Perfect Forward Secrecy (PFS) enabled
  - HSTS enabled with preload
  - OCSP stapling enabled

#### Vulnerability Management

**Vulnerability Scanning:**
- **Container Images**: 
  - Scan on every build
  - Block deployment if critical vulnerabilities found
  - Weekly scans of running containers
- **Dependencies**: 
  - Regular dependency updates
  - Automated vulnerability scanning (Snyk, Dependabot, etc.)
  - Security patches applied within 48 hours for critical issues
- **Infrastructure**: 
  - Regular infrastructure scans
  - Penetration testing annually
  - Security audits quarterly

**Patch Management:**
- **Application**: 
  - Security patches applied within 48 hours
  - Regular updates (monthly for non-critical)
  - Test patches in staging before production
- **Infrastructure**: 
  - OS security updates: Automatic
  - Database updates: Tested in staging, applied during maintenance window
  - Container base images: Updated monthly

#### Compliance & Governance

**Data Protection:**
- **GDPR Compliance**: 
  - User data export capabilities
  - User data deletion (right to be forgotten)
  - Data processing agreements
  - Privacy policy and terms of service
  - Cookie consent management
- **Data Encryption**: 
  - Encryption at rest (AES-256)
  - Encryption in transit (TLS 1.2+)
  - Key management and rotation
- **Data Retention**: 
  - Defined retention policies per data type
  - Automated data purging after retention period
  - Backup retention aligned with data retention

**Access Control & Audit:**
- **Access Logging**: 
  - All admin actions logged
  - Authentication attempts logged
  - Failed access attempts logged
  - Log retention: 90 days minimum
- **Audit Trail**: 
  - Complete audit trail for compliance
  - Immutable audit logs
  - Regular audit log reviews
  - Alert on suspicious activities
- **Access Reviews**: 
  - Quarterly access reviews
  - Remove unused accounts
  - Principle of least privilege

**Incident Response:**
- **Security Incident Response Plan**: 
  - Defined incident response procedures
  - Incident response team identified
  - Communication plan for security incidents
  - Regular incident response drills
- **Breach Notification**: 
  - Procedures for data breach notification
  - Compliance with regulatory requirements (GDPR, etc.)
  - Customer notification procedures

**Compliance Standards:**
- **SOC 2**: Security controls and audit logging
- **ISO 27001**: Information security management
- **PCI DSS**: If handling payment data (not applicable for community platform)
- **HIPAA**: If handling health data (not applicable for community platform)

---

## Environment-Specific Configurations

This section provides detailed infrastructure resource requirements for each environment. Use these specifications when provisioning infrastructure.

### Local Development

**Database Configuration:**
- **Database Name**: `community_local` (or from `COMMUNITY_DB_NAME`)
- **Database User**: `community` (or from `COMMUNITY_DB_USER`)
- **Database Password**: From `COMMUNITY_DB_PASSWORD` env var
- **Max Connections**: 20
- **Extensions Required**: `pg_trgm`, `hstore`, `pg_stat_statements`
- **Tables**: All 200+ tables created via migrations
- **Indexes**: All indexes created automatically

**Redis Configuration:**
- **Database**: 0 (default)
- **Password**: Optional (not required for local)
- **Memory**: 256 MB
- **Key Namespace**: `community_local`
- **Key Patterns**: All standard patterns (see Redis Key Patterns section)

**Storage:**
- **Total**: 20 GB
- **Database Volume**: 5 GB
- **Uploads Volume**: 5 GB
- **Backups Volume**: 5 GB
- **Logs Volume**: 1 GB
- **Temp Volume**: 1 GB
- **Type**: Local Docker volumes

**Resources:**
- 1 application container (2 CPU, 4 GB RAM)
- 1 Sidekiq container (1 CPU, 2 GB RAM)
- 1 PostgreSQL container (1 CPU, 2 GB RAM)
- 1 Redis container (0.5 CPU, 256 MB RAM)
- 1 Nginx container (0.5 CPU, 128 MB RAM)

**Network:**
- **Hostname**: `localhost`
- **HTTP Port**: 8080
- **HTTPS Port**: 8443
- **Internal Docker Network**: `sira-network` (bridge)
- **Database Port**: 5432 (internal only)
- **Redis Port**: 6379 (internal only)

**File System:**
- **Base Path**: `./` (project directory)
- **Uploads Path**: `./public/uploads`
- **Backups Path**: `./public/backups`
- **Logs Path**: `./log`
- **Temp Path**: `./tmp`

### Development Server

**Database Configuration:**
- **Database Name**: `community_dev` (or from `COMMUNITY_DB_NAME`)
- **Database User**: `community` (or from `COMMUNITY_DB_USER`)
- **Database Password**: Strong password (32+ chars, from `COMMUNITY_DB_PASSWORD`)
- **Max Connections**: 50
- **Extensions Required**: `pg_trgm`, `hstore`, `pg_stat_statements`
- **Tables**: All 200+ tables created via migrations
- **Indexes**: All indexes created automatically
- **Backup**: Daily at 2 AM UTC, 14-day retention

**Redis Configuration:**
- **Database**: 0 (default)
- **Password**: Required (from `COMMUNITY_REDIS_PASSWORD`)
- **Memory**: 512 MB
- **Key Namespace**: `community_dev`
- **Key Patterns**: All standard patterns
- **Persistence**: AOF enabled

**Storage:**
- **Total**: 100 GB
- **Database Volume**: 20 GB (SSD recommended)
- **Uploads Volume**: 30 GB (SSD)
- **Backups Volume**: 30 GB (standard)
- **Logs Volume**: 5 GB (standard)
- **Temp Volume**: 5 GB (standard)
- **Type**: Persistent volumes with snapshots

**Resources:**
- 2 application containers (2 CPU, 4 GB RAM each)
- 2 Sidekiq containers (1 CPU, 2 GB RAM each)
- PostgreSQL (managed or container, 2 CPU, 4 GB RAM)
- Redis (managed or container, 1 CPU, 512 MB RAM)
- 2 Nginx containers (0.5 CPU, 128 MB RAM each, load balanced)

**Network:**
- **Hostname**: `community-dev.sira.ai`
- **HTTP Port**: 80
- **HTTPS Port**: 443
- **SSL Certificate**: Required (Let's Encrypt or commercial)
- **Internal Docker Network**: `sira-network` (bridge)
- **Database Port**: 5432 (internal only, firewall restricted)
- **Redis Port**: 6379 (internal only, firewall restricted)

**File System:**
- **Base Path**: `/var/www/community` (or container mount)
- **Uploads Path**: `/var/www/community/public/uploads`
- **Backups Path**: `/var/www/community/public/backups`
- **Logs Path**: `/var/www/community/log`
- **Temp Path**: `/var/www/community/tmp`
- **Permissions**: All directories 755, owned by app user (UID 1000+)

### Test Server

**Database Configuration:**
- **Database Name**: `community_test` (or from `COMMUNITY_DB_NAME`)
- **Database User**: `community` (or from `COMMUNITY_DB_USER`)
- **Database Password**: Strong password (32+ chars, from `COMMUNITY_DB_PASSWORD`)
- **Max Connections**: 100
- **Extensions Required**: `pg_trgm`, `hstore`, `pg_stat_statements`
- **Tables**: All 200+ tables created via migrations
- **Indexes**: All indexes created automatically
- **Backup**: Daily at 2 AM UTC, 30-day retention
- **Replica**: Optional read replica for load testing

**Redis Configuration:**
- **Database**: 0 (default)
- **Password**: Required (from `COMMUNITY_REDIS_PASSWORD`)
- **Memory**: 1 GB
- **Key Namespace**: `community_test`
- **Key Patterns**: All standard patterns
- **Persistence**: AOF enabled
- **Replica**: Optional for testing failover

**Storage:**
- **Total**: 200 GB
- **Database Volume**: 50 GB (SSD)
- **Uploads Volume**: 50 GB (SSD)
- **Backups Volume**: 70 GB (standard)
- **Logs Volume**: 10 GB (standard)
- **Temp Volume**: 10 GB (standard)
- **Type**: Persistent volumes with daily snapshots

**Resources:**
- 2 application containers (2 CPU, 4 GB RAM each)
- 2 Sidekiq containers (1 CPU, 2 GB RAM each)
- PostgreSQL (managed, 2 CPU, 4 GB RAM, replica optional)
- Redis (managed, 1 CPU, 1 GB RAM, replica optional)
- 2 Nginx containers (0.5 CPU, 128 MB RAM each)

**Network:**
- **Hostname**: `community-test.sira.ai`
- **HTTP Port**: 80
- **HTTPS Port**: 443
- **SSL Certificate**: Required (Let's Encrypt or commercial)
- **Internal Docker Network**: `sira-network` (bridge)
- **Database Port**: 5432 (internal only, firewall restricted)
- **Redis Port**: 6379 (internal only, firewall restricted)

**File System:**
- **Base Path**: `/var/www/community` (or container mount)
- **Uploads Path**: `/var/www/community/public/uploads`
- **Backups Path**: `/var/www/community/public/backups`
- **Logs Path**: `/var/www/community/log`
- **Temp Path**: `/var/www/community/tmp`
- **Permissions**: All directories 755, owned by app user (UID 1000+)

### Staging Server

**Database Configuration:**
- **Database Name**: `community_staging` (or from `COMMUNITY_DB_NAME`)
- **Database User**: `community` (or from `COMMUNITY_DB_USER`)
- **Database Password**: Strong password (32+ chars, from `COMMUNITY_DB_PASSWORD`)
- **Max Connections**: 150
- **Extensions Required**: `pg_trgm`, `hstore`, `pg_stat_statements`
- **Tables**: All 200+ tables created via migrations
- **Indexes**: All indexes created automatically
- **Backup**: Daily at 2 AM UTC, 30-day retention
- **High Availability**: Primary + replica, automated failover
- **Connection Pooling**: PgBouncer recommended

**Redis Configuration:**
- **Database**: 0 (default)
- **Password**: Required (from `COMMUNITY_REDIS_PASSWORD`)
- **Memory**: 1 GB
- **Key Namespace**: `community_staging`
- **Key Patterns**: All standard patterns
- **Persistence**: AOF enabled
- **High Availability**: Primary + replica, Redis Sentinel

**Storage:**
- **Total**: 500 GB
- **Database Volume**: 100 GB (SSD, high IOPS)
- **Uploads Volume**: 150 GB (SSD)
- **Backups Volume**: 200 GB (standard)
- **Logs Volume**: 20 GB (standard)
- **Temp Volume**: 20 GB (standard)
- **Type**: Persistent volumes with daily backups and snapshots

**Resources:**
- 3 application containers (2 CPU, 4 GB RAM each)
- 3 Sidekiq containers (1 CPU, 2 GB RAM each)
- PostgreSQL (managed, high availability, 4 CPU, 8 GB RAM)
- Redis (managed, high availability, 2 CPU, 1 GB RAM)
- 2 Nginx containers (0.5 CPU, 128 MB RAM each, load balanced)

**Network:**
- **Hostname**: `community-staging.sira.ai`
- **HTTP Port**: 80
- **HTTPS Port**: 443
- **SSL Certificate**: Required (Let's Encrypt or commercial)
- **Internal Docker Network**: `sira-network` (bridge)
- **Database Port**: 5432 (internal only, firewall restricted)
- **Redis Port**: 6379 (internal only, firewall restricted)
- **Load Balancer**: Application load balancer recommended

**File System:**
- **Base Path**: `/var/www/community` (or container mount)
- **Uploads Path**: `/var/www/community/public/uploads`
- **Backups Path**: `/var/www/community/public/backups`
- **Logs Path**: `/var/www/community/log`
- **Temp Path**: `/var/www/community/tmp`
- **Permissions**: All directories 755, owned by app user (UID 1000+)

### Production Server

**Database Configuration:**
- **Database Name**: `community_prod` (or from `COMMUNITY_DB_NAME`)
- **Database User**: `community` (or from `COMMUNITY_DB_USER`)
- **Database Password**: Strong password (32+ chars, from `COMMUNITY_DB_PASSWORD`, rotated quarterly)
- **Max Connections**: 200
- **Extensions Required**: `pg_trgm`, `hstore`, `pg_stat_statements`
- **Tables**: All 200+ tables created via migrations
- **Indexes**: All indexes created automatically (monitored for performance)
- **Backup**: Daily at 2 AM UTC, 90-day retention, point-in-time recovery enabled
- **High Availability**: Multi-zone primary + replicas, automated failover (< 30 seconds)
- **Connection Pooling**: PgBouncer required (transaction pooling)
- **Read Replicas**: 2+ read replicas for read scaling
- **Monitoring**: Query performance monitoring, slow query logging

**Redis Configuration:**
- **Database**: 0 (default)
- **Password**: Required (from `COMMUNITY_REDIS_PASSWORD`, rotated quarterly)
- **Memory**: 2 GB
- **Key Namespace**: `community_prod`
- **Key Patterns**: All standard patterns (monitored for memory usage)
- **Persistence**: AOF enabled, fsync every second
- **High Availability**: Multi-zone primary + replicas, Redis Sentinel (3+ sentinels)
- **Failover Time**: < 10 seconds
- **Monitoring**: Memory usage, hit rate, latency monitoring

**Storage:**
- **Total**: 1 TB+ (scales with usage)
- **Database Volume**: 200 GB+ (SSD, 3000+ IOPS, < 5ms latency)
- **Uploads Volume**: 500 GB+ (SSD, 1000+ IOPS, < 10ms latency)
- **Backups Volume**: 500 GB+ (standard, can use object storage)
- **Logs Volume**: 50 GB+ (standard, with log rotation)
- **Temp Volume**: 50 GB+ (standard)
- **Type**: Persistent volumes with automated backups, snapshots, and replication
- **Backup Strategy**: Daily full backups + continuous WAL archiving

**Resources:**
- 4+ application containers (auto-scaling, 4 CPU, 8 GB RAM each, scale based on load)
- 4+ Sidekiq containers (auto-scaling, 2 CPU, 4 GB RAM each)
- PostgreSQL (managed, multi-zone high availability, 8 CPU, 16 GB RAM minimum)
- Redis (managed, multi-zone high availability, 4 CPU, 8 GB RAM)
- 2+ Nginx containers (1 CPU, 256 MB RAM each, load balanced)
- Load Balancer: Application load balancer with health checks

**Network:**
- **Hostname**: `community.sira.ai`
- **HTTP Port**: 80 (redirects to HTTPS)
- **HTTPS Port**: 443
- **SSL Certificate**: Required (Let's Encrypt with auto-renewal or commercial)
- **Internal Docker Network**: `sira-network` (bridge)
- **Database Port**: 5432 (internal only, VPC/private network, firewall restricted)
- **Redis Port**: 6379 (internal only, VPC/private network, firewall restricted)
- **CDN**: CloudFlare, AWS CloudFront, or Azure CDN for static assets
- **DDoS Protection**: Cloud provider DDoS protection enabled
- **WAF**: Web Application Firewall configured

**File System:**
- **Base Path**: `/var/www/community` (or container mount)
- **Uploads Path**: `/var/www/community/public/uploads` (with quota management)
- **Backups Path**: `/var/www/community/public/backups` (with remote replication)
- **Logs Path**: `/var/www/community/log` (with log aggregation)
- **Temp Path**: `/var/www/community/tmp` (with automatic cleanup)
- **Permissions**: All directories 755, owned by app user (UID 1000+)
- **Monitoring**: Disk usage alerts at 80%, 90%, 95%

**Additional Production Requirements:**
- **Monitoring**: Full application and infrastructure monitoring (Prometheus, Datadog, etc.)
- **Logging**: Centralized log aggregation (ELK stack, Loki, CloudWatch)
- **Alerting**: Critical alerts configured (PagerDuty, Slack, email)
- **Backup Verification**: Weekly automated backup restore tests
- **Disaster Recovery**: Documented DR procedures, quarterly DR drills
- **Security**: Regular security audits, vulnerability scanning, penetration testing
- **Compliance**: GDPR compliance, data retention policies, audit logging

---

## Integration Points

### SIRA AI Application Integration

#### Network Integration

- **Docker Network**: `sira-network` (shared)
- **Service Discovery**: Docker DNS or service mesh
- **Communication**: Internal network only

#### API Integration

- **Community Service Port**: 3005 (SIRA AI app)
- **Community URL**: `https://community.sira.ai`
- **API Key**: Required for all API calls
- **SSO Secret**: For single sign-on

#### Redis Integration

- **Redis DB 1**: Reserved for SIRA AI app community service
- **Connection**: Same Redis instance, different database
- **Password**: Shared Redis password

### External Integrations

#### Email Service (SendGrid)

- **SMTP**: `smtp.sendgrid.net:587`
- **Authentication**: API Key
- **Rate Limits**: Based on SendGrid plan

#### CDN (Optional)

- **Purpose**: Static asset delivery
- **Configuration**: Set `cdn_url` in Discourse config
- **Providers**: CloudFlare, AWS CloudFront, Azure CDN

---

## Resource Sizing Recommendations

### Small Deployment (< 1,000 users)

**Compute:**
- 2 application containers (2 CPU, 4 GB RAM each)
- 2 Sidekiq containers (1 CPU, 2 GB RAM each)
- Total: 6 CPU cores, 12 GB RAM

**Database:**
- PostgreSQL: 2 CPU, 4 GB RAM, 50 GB storage

**Redis:**
- Redis: 1 CPU, 2 GB RAM

**Storage:**
- Total: 200 GB

### Medium Deployment (1,000-10,000 users)

**Compute:**
- 4 application containers (2 CPU, 4 GB RAM each)
- 4 Sidekiq containers (1 CPU, 2 GB RAM each)
- Total: 12 CPU cores, 24 GB RAM

**Database:**
- PostgreSQL: 4 CPU, 8 GB RAM, 200 GB storage

**Redis:**
- Redis: 2 CPU, 4 GB RAM

**Storage:**
- Total: 500 GB

### Large Deployment (10,000+ users)

**Compute:**
- 8+ application containers (4 CPU, 8 GB RAM each)
- 8+ Sidekiq containers (2 CPU, 4 GB RAM each)
- Total: 48+ CPU cores, 96+ GB RAM

**Database:**
- PostgreSQL: 8 CPU, 16 GB RAM, 500 GB+ storage
- Read replicas: 2+ replicas

**Redis:**
- Redis: 4 CPU, 8 GB RAM
- Redis replicas: 2+ replicas

**Storage:**
- Total: 1 TB+

---

## Deployment Checklist

### Pre-Deployment

**Infrastructure:**
- [ ] Infrastructure provisioned (servers, databases, Redis)
- [ ] Docker and Docker Compose installed and updated
- [ ] Network configured (`sira-network`) with proper segmentation
- [ ] DNS records configured and verified
- [ ] SSL certificates obtained, installed, and validated
- [ ] Load balancer configured with health checks
- [ ] WAF configured with security rules
- [ ] DDoS protection enabled

**Configuration:**
- [ ] Environment variables configured (`.env` files)
- [ ] Secrets generated and stored in secret management service
  - [ ] Secret key base (128-char hex, unique per environment)
  - [ ] Database passwords (32+ chars, strong)
  - [ ] Redis passwords (32+ chars, strong)
  - [ ] API keys (32+ chars, cryptographically secure)
  - [ ] SSO secrets (32+ chars, cryptographically secure)
- [ ] Storage volumes created with proper sizing
- [ ] Firewall rules configured (least privilege)
- [ ] Security groups configured (internal services isolated)

**Security:**
- [ ] Container images scanned for vulnerabilities
- [ ] Base images updated to latest secure versions
- [ ] Non-root user configured for containers
- [ ] Resource limits configured for containers
- [ ] Network policies configured
- [ ] Secrets management service configured
- [ ] Access control and IAM configured

**Monitoring & Logging:**
- [ ] Monitoring tools installed and configured
- [ ] Log aggregation system configured
- [ ] Alerting rules configured
- [ ] Dashboards created
- [ ] On-call rotation configured
- [ ] Incident response procedures documented

### Application Deployment

- [ ] Application code deployed (Git clone/pull)
- [ ] Docker images built
- [ ] Database migrations run
- [ ] Database seeded (initial data)
- [ ] Assets precompiled
- [ ] Containers started
- [ ] Health checks passing
- [ ] Load balancer configured

### Post-Deployment

- [ ] Application accessible via domain
- [ ] SSL certificate valid
- [ ] Admin account created
- [ ] Email sending tested
- [ ] API integration tested
- [ ] Monitoring alerts configured
- [ ] Backup jobs scheduled
- [ ] Documentation updated

### Ongoing Maintenance

**Daily:**
- [ ] Backup verification (automated with alerts)
- [ ] Health check review
- [ ] Error log review
- [ ] Security alert review
- [ ] Performance metrics review

**Weekly:**
- [ ] Security updates applied (test in staging first)
- [ ] Backup restore test (automated)
- [ ] Capacity planning review
- [ ] Log analysis for anomalies
- [ ] Access log review for suspicious activity
- [ ] Dependency updates review

**Monthly:**
- [ ] Full security audit
- [ ] Capacity planning deep dive
- [ ] Cost optimization review
- [ ] Performance optimization review
- [ ] Access control review (remove unused access)
- [ ] Secret rotation (if not automated)
- [ ] Documentation updates

**Quarterly:**
- [ ] Disaster recovery drill (full test)
- [ ] Penetration testing (external)
- [ ] Security compliance review
- [ ] Infrastructure architecture review
- [ ] Backup strategy review
- [ ] Incident response procedure review
- [ ] Training and knowledge sharing

**Ad-Hoc:**
- [ ] Security patches applied within 48 hours (critical)
- [ ] Incident post-mortem (within 1 week of incident)
- [ ] Log rotation configured and verified
- [ ] Monitoring dashboards reviewed and updated
- [ ] Alert tuning based on false positives

---

## Additional Resources

### Documentation

- **Integration Guide**: `INTEGRATION_GUIDE.md`
- **Database Tables**: `docs/DATABASE_TABLES.md`
- **Docker Deployment**: `docker/README.md`
- **Environment Setup**: `docker/ENVIRONMENT_SETUP.md`

### Support Contacts

- **Infrastructure Team**: [Contact Information]
- **Development Team**: [Contact Information]
- **On-Call**: [Contact Information]

### Emergency Procedures

- **Application Down**: [Procedure]
- **Database Issues**: [Procedure]
- **Security Incident**: [Procedure]

---

## Appendix

### A. Environment Variable Reference

See `docker/env.prod` for complete production environment variables.

### B. Docker Compose Reference

See `docker-compose.yml` for complete Docker Compose configuration.

### C. Network Diagram

See Architecture Overview section for network diagrams.

### D. Cost Estimates

**Cloud Provider Cost Estimates (Monthly):**

| Environment | Compute | Database | Storage | Total (Est.) |
|------------|---------|----------|---------|--------------|
| **Development** | $100 | $50 | $20 | $170 |
| **Test** | $150 | $100 | $40 | $290 |
| **Staging** | $300 | $200 | $80 | $580 |
| **Production** | $800+ | $400+ | $200+ | $1,400+ |

*Note: Costs vary by cloud provider and region*

---

**Document End**

For questions or clarifications, please contact the Infrastructure Team.

