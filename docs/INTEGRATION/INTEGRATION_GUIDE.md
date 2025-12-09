# SIRA Community Integration Guide

## Table of Contents

1. [Overview](#overview)
2. [Integration Methods](#integration-methods)
3. [Implementation Architecture](#implementation-architecture)
4. [REST API Integration](#rest-api-integration)
5. [Single Sign-On (SSO) Integration](#single-sign-on-sso-integration)
6. [OAuth 2.0 Integration](#oauth-20-integration)
7. [Webhooks Integration](#webhooks-integration)
8. [Embedding Integration](#embedding-integration)
9. [Common Use Cases](#common-use-cases)
10. [Code Examples](#code-examples)
11. [Best Practices](#best-practices)
12. [Security Considerations](#security-considerations)
13. [Troubleshooting](#troubleshooting)

---

## Overview

SIRA Community is a powerful, open-source community platform built on Discourse. It provides comprehensive community features including discussions, real-time chat, user management, moderation tools, and extensive customization options.

This guide explains how external applications (such as SIRA AI) can integrate with SIRA Community to leverage its community functionality, enabling seamless user experiences and unified community management.

### Key Features Available for Integration

- **User Management**: Create, update, and manage user accounts
- **Content Management**: Create topics, posts, and manage discussions
- **Real-time Chat**: Integrate chat functionality
- **Authentication**: Single Sign-On (SSO) and OAuth 2.0 support
- **Notifications**: Webhook-based event notifications
- **Search**: Full-text search across community content
- **Moderation**: Automated moderation and content management
- **Analytics**: Access to community statistics and reports

---

## Integration Methods

SIRA Community supports multiple integration methods, each suited for different use cases:

1. **REST API** - For programmatic access to community features
2. **Single Sign-On (SSO)** - For seamless user authentication
3. **OAuth 2.0** - For third-party authentication providers
4. **Webhooks** - For real-time event notifications
5. **Embedding** - For embedding community content in external sites

---

## Implementation Architecture

This section provides guidance for implementing a community service integration within the SIRA AI application architecture, following established patterns and best practices.

### Service Configuration

#### Port Configuration

Use port **3005** for the community service (next available after profile-service at 3003):

```bash
COMMUNITY_SERVICE_PORT=3005
```

**Port Allocation Reference:**
- auth-service: 3001
- user-service: 3002
- profile-service: 3003
- (reserved: 3004)
- community-service: 3005

#### Service Structure

Follow the same architectural pattern as `user-service` for consistency:

```
community-service/
├── src/
│   ├── config/
│   │   ├── database.js
│   │   ├── redis.js
│   │   └── discourse.js
│   ├── middleware/
│   │   ├── auth.js
│   │   ├── errorHandler.js
│   │   ├── logger.js
│   │   └── rateLimiter.js
│   ├── models/
│   │   ├── CommunityUser.js
│   │   ├── CommunityTopic.js
│   │   └── CommunityPost.js
│   ├── services/
│   │   ├── discourseClient.js
│   │   ├── userSyncService.js
│   │   ├── contentService.js
│   │   └── webhookService.js
│   ├── controllers/
│   │   ├── usersController.js
│   │   ├── topicsController.js
│   │   └── webhooksController.js
│   ├── routes/
│   │   ├── users.js
│   │   ├── topics.js
│   │   └── webhooks.js
│   ├── utils/
│   │   ├── sso.js
│   │   └── validators.js
│   └── app.js
├── tests/
├── .env.example
└── package.json
```

**Middleware Pattern:**
- Use the same middleware stack as `user-service`:
  - Authentication middleware (JWT validation)
  - Error handling middleware
  - Request logging middleware
  - Rate limiting middleware
  - HTTPS enforcement (in production)

**Security Pattern:**
- Follow the same security practices:
  - Input validation and sanitization
  - SQL injection prevention
  - XSS protection
  - CORS configuration
  - Security headers

### Implementation Order

**Recommended Approach: Option A** - Start with API client, then build up:

1. **Phase 1: Discourse API Client** (Foundation)
   - Create `discourseClient.js` service
   - Implement core API methods (topics, posts, users)
   - Add error handling and retry logic
   - Write unit tests

2. **Phase 2: Service Layer** (Business Logic)
   - Create service classes that use the API client
   - Implement user synchronization service
   - Implement content management service
   - Add caching layer

3. **Phase 3: Database Models** (Data Persistence)
   - Create models for synced data
   - Implement sync tracking tables
   - Add indexes for performance

4. **Phase 4: Routes & Controllers** (API Layer)
   - Create REST endpoints
   - Implement controllers
   - Add request validation
   - Add response formatting

5. **Phase 5: Webhooks** (Real-time Updates)
   - Implement webhook receiver
   - Add signature verification
   - Create webhook handlers

**Why Option A?**
- Faster initial development and testing
- Can test API integration immediately
- Database schema evolves based on actual needs
- Easier to iterate and refine

**Alternative: Option B** (if you prefer database-first)
- Start with database models if you need to track complex relationships
- Useful if you're building extensive caching or analytics
- Better if you need to store historical data

### Redis Configuration

#### Connection Pattern

Use the same Redis connection pattern as `auth-service`:

```javascript
// src/config/redis.js
const redis = require('redis');
const { createClient } = redis;

const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD,
  db: parseInt(process.env.REDIS_DB_COMMUNITY) || 1, // Use DB 1 for community
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  }
};

const client = createClient(redisConfig);

client.on('error', (err) => {
  console.error('Redis Client Error:', err);
});

client.on('connect', () => {
  console.log('Redis Client Connected');
});

module.exports = client;
```

#### Redis Database Allocation

Use **REDIS_DB_COMMUNITY=1** for community-specific caching:

```bash
# .env
REDIS_DB_COMMUNITY=1
```

**Redis DB Allocation Reference:**
- DB 0: Default/general
- DB 1: Community service (caching, rate limiting)
- DB 2: Auth service
- DB 3: User service
- DB 4: Profile service

**Caching Strategy:**
- Cache API responses (TTL: 5-15 minutes)
- Cache user profiles (TTL: 30 minutes)
- Cache topic lists (TTL: 5 minutes)
- Cache search results (TTL: 2 minutes)
- Use cache invalidation on webhook events

### Environment Variables

#### Required Environment Variables

Create a `.env.example` file with the following variables:

```bash
# Service Configuration
COMMUNITY_SERVICE_PORT=3005
NODE_ENV=development

# Discourse Configuration
DISCOURSE_URL=https://community.sira.ai
DISCOURSE_API_KEY=your_api_key_here
DISCOURSE_API_USERNAME=system
DISCOURSE_SSO_SECRET=your_sso_secret_here

# Discourse Category IDs (configure as needed)
DISCOURSE_CATEGORY_GENERAL=5
DISCOURSE_CATEGORY_ANNOUNCEMENTS=6
DISCOURSE_CATEGORY_SUPPORT=7
DISCOURSE_CATEGORY_FEEDBACK=8

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB_COMMUNITY=1

# Database Configuration (if using local DB)
DATABASE_URL=postgresql://user:password@localhost:5432/sira_ai
DB_POOL_MIN=2
DB_POOL_MAX=10

# Security
JWT_SECRET=your_jwt_secret
API_RATE_LIMIT=100
API_RATE_WINDOW=900000

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# Webhook Configuration
WEBHOOK_SECRET=your_webhook_secret
WEBHOOK_TIMEOUT=30000
```

#### Environment Variable Validation

Create a validation utility:

```javascript
// src/config/env.js
require('dotenv').config();

const requiredEnvVars = [
  'DISCOURSE_URL',
  'DISCOURSE_API_KEY',
  'DISCOURSE_API_USERNAME',
  'DISCOURSE_SSO_SECRET'
];

const validateEnv = () => {
  const missing = requiredEnvVars.filter(
    (varName) => !process.env[varName]
  );
  
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}`
    );
  }
  
  // Validate URL format
  try {
    new URL(process.env.DISCOURSE_URL);
  } catch (error) {
    throw new Error('DISCOURSE_URL must be a valid URL');
  }
  
  // Validate category IDs are numbers
  const categoryVars = Object.keys(process.env)
    .filter(key => key.startsWith('DISCOURSE_CATEGORY_'));
  
  categoryVars.forEach(varName => {
    const value = process.env[varName];
    if (value && isNaN(parseInt(value))) {
      throw new Error(`${varName} must be a valid number`);
    }
  });
};

module.exports = {
  validateEnv,
  config: {
    port: process.env.COMMUNITY_SERVICE_PORT || 3005,
    discourse: {
      url: process.env.DISCOURSE_URL,
      apiKey: process.env.DISCOURSE_API_KEY,
      apiUsername: process.env.DISCOURSE_API_USERNAME,
      ssoSecret: process.env.DISCOURSE_SSO_SECRET,
      categories: {
        general: parseInt(process.env.DISCOURSE_CATEGORY_GENERAL) || 5,
        announcements: parseInt(process.env.DISCOURSE_CATEGORY_ANNOUNCEMENTS) || 6,
        support: parseInt(process.env.DISCOURSE_CATEGORY_SUPPORT) || 7,
        feedback: parseInt(process.env.DISCOURSE_CATEGORY_FEEDBACK) || 8
      }
    },
    redis: {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD,
      db: parseInt(process.env.REDIS_DB_COMMUNITY) || 1
    }
  }
};
```

### Dependencies

#### HTTP Client Recommendation

**Use `axios`** for HTTP requests (recommended):

**Pros:**
- Better error handling
- Request/response interceptors
- Automatic JSON parsing
- Better TypeScript support
- More features (timeouts, retries, etc.)
- Widely used in Node.js ecosystem

**Installation:**
```bash
npm install axios
```

**Example Usage:**
```javascript
const axios = require('axios');

const discourseClient = axios.create({
  baseURL: process.env.DISCOURSE_URL,
  timeout: 30000,
  headers: {
    'Api-Key': process.env.DISCOURSE_API_KEY,
    'Api-Username': process.env.DISCOURSE_API_USERNAME,
    'Content-Type': 'application/json'
  }
});

// Add request interceptor for logging
discourseClient.interceptors.request.use(
  (config) => {
    console.log(`Making request to: ${config.url}`);
    return config;
  },
  (error) => Promise.reject(error)
);

// Add response interceptor for error handling
discourseClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      console.error('API Error:', error.response.status, error.response.data);
    }
    return Promise.reject(error);
  }
);
```

**Alternative: Node.js Built-in Fetch (Node 18+)**

If you prefer using built-in fetch (Node.js 18+):

**Pros:**
- No additional dependency
- Native browser compatibility
- Modern async/await syntax

**Cons:**
- Less feature-rich than axios
- Requires Node.js 18+
- Less community support for advanced features

**Example Usage:**
```javascript
async function fetchFromDiscourse(endpoint, options = {}) {
  const url = `${process.env.DISCOURSE_URL}${endpoint}`;
  
  const response = await fetch(url, {
    ...options,
    headers: {
      'Api-Key': process.env.DISCOURSE_API_KEY,
      'Api-Username': process.env.DISCOURSE_API_USERNAME,
      'Content-Type': 'application/json',
      ...options.headers
    }
  });
  
  if (!response.ok) {
    const error = await response.json();
    throw new Error(`API Error: ${response.status} - ${error.errors?.join(', ')}`);
  }
  
  return response.json();
}
```

#### Recommended Package.json Dependencies

```json
{
  "name": "community-service",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "redis": "^4.6.0",
    "pg": "^8.11.0",
    "dotenv": "^16.3.1",
    "jsonwebtoken": "^9.0.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.0",
    "winston": "^3.11.0",
    "crypto": "^1.0.1",
    "joi": "^17.11.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^6.3.3",
    "nodemon": "^3.0.2",
    "eslint": "^8.54.0"
  }
}
```

### Project Structure Example

Here's a complete example of the recommended project structure:

```
community-service/
├── src/
│   ├── config/
│   │   ├── env.js              # Environment validation
│   │   ├── database.js         # PostgreSQL connection
│   │   ├── redis.js            # Redis connection
│   │   └── discourse.js         # Discourse client config
│   │
│   ├── middleware/
│   │   ├── auth.js             # JWT authentication
│   │   ├── errorHandler.js     # Error handling
│   │   ├── logger.js           # Request logging
│   │   └── rateLimiter.js      # Rate limiting
│   │
│   ├── models/
│   │   ├── CommunityUser.js    # Synced user model
│   │   ├── CommunityTopic.js  # Synced topic model
│   │   └── CommunityPost.js    # Synced post model
│   │
│   ├── services/
│   │   ├── discourseClient.js  # Discourse API client
│   │   ├── userSyncService.js  # User synchronization
│   │   ├── contentService.js   # Content management
│   │   ├── webhookService.js   # Webhook processing
│   │   └── cacheService.js     # Redis caching
│   │
│   ├── controllers/
│   │   ├── usersController.js
│   │   ├── topicsController.js
│   │   ├── postsController.js
│   │   └── webhooksController.js
│   │
│   ├── routes/
│   │   ├── index.js
│   │   ├── users.js
│   │   ├── topics.js
│   │   ├── posts.js
│   │   └── webhooks.js
│   │
│   ├── utils/
│   │   ├── sso.js              # SSO URL generation
│   │   ├── validators.js       # Input validation
│   │   └── errors.js           # Custom error classes
│   │
│   └── app.js                  # Express app setup
│
├── tests/
│   ├── unit/
│   │   ├── services/
│   │   └── utils/
│   └── integration/
│       └── api/
│
├── .env.example
├── .gitignore
├── package.json
├── jest.config.js
└── README.md
```

### Getting Started Checklist

1. **Environment Setup**
   - [ ] Create `.env` file from `.env.example`
   - [ ] Configure `DISCOURSE_URL`
   - [ ] Generate and configure `DISCOURSE_API_KEY`
   - [ ] Set `DISCOURSE_API_USERNAME`
   - [ ] Configure `DISCOURSE_SSO_SECRET`
   - [ ] Set category IDs
   - [ ] Configure Redis connection
   - [ ] Set `COMMUNITY_SERVICE_PORT=3005`

2. **Dependencies**
   - [ ] Install dependencies (`npm install`)
   - [ ] Verify axios is installed
   - [ ] Verify Redis client is installed

3. **Implementation**
   - [ ] Create Discourse API client
   - [ ] Implement service layer
   - [ ] Create database models
   - [ ] Implement routes and controllers
   - [ ] Add middleware (auth, logging, error handling)
   - [ ] Implement webhook receiver

4. **Testing**
   - [ ] Write unit tests for API client
   - [ ] Write integration tests for routes
   - [ ] Test SSO flow
   - [ ] Test webhook signature verification

5. **Deployment**
   - [ ] Configure production environment variables
   - [ ] Set up Redis in production
   - [ ] Configure HTTPS
   - [ ] Set up monitoring and logging

---

## REST API Integration

### Overview

The REST API provides comprehensive programmatic access to SIRA Community features. All API endpoints return JSON responses and support granular permission scoping.

### Authentication

#### API Keys

API keys are the primary method for authenticating API requests. They provide fine-grained access control through scoped permissions.

**Creating an API Key:**

1. Navigate to Admin → API → Keys in your SIRA Community instance
2. Click "New API Key"
3. Configure:
   - **Description**: A descriptive name for the key
   - **User**: The Discourse user to associate with the key (optional)
   - **Scopes**: Select specific permissions (read, write, update, delete, etc.)
   - **Allowed IPs**: Restrict key usage to specific IP addresses (optional)

**API Key Scopes:**

The API supports granular scoping across multiple resources:

- **Global**: Read-only access to all GET endpoints
- **Topics**: Read, write, update, delete, recover, status management
- **Posts**: Edit, delete, recover, list
- **Users**: Show, create, update, bookmarks, sync SSO
- **Categories**: List, show
- **Tags**: List
- **Groups**: Manage members, administer groups
- **Search**: Query and search functionality
- **Badges**: Create, show, update, delete, assign
- **Uploads**: Create and manage file uploads
- **Invites**: Create invitations

**Using API Keys:**

```http
GET /api/topics.json
Api-Key: YOUR_API_KEY
Api-Username: system
```

#### User API Keys

For user-specific operations, you can create API keys associated with specific users:

```http
POST /admin/api/keys.json
Content-Type: application/json
Api-Key: ADMIN_API_KEY
Api-Username: admin

{
  "key": {
    "description": "SIRA AI Integration",
    "username": "sira_ai_user",
    "scopes": [
      {
        "scope_id": "topics:write",
        "allowed_parameters": {
          "category_id": "5"
        }
      },
      {
        "scope_id": "posts:edit"
      }
    ]
  }
}
```

### Base URL

All API requests should be made to:

```
https://your-community-domain.com
```

### API Endpoints

#### Topics

**List Topics:**
```http
GET /latest.json
GET /top.json
GET /new.json
GET /unread.json
```

**Get Topic:**
```http
GET /t/{topic_id}.json
GET /t/{topic_slug}/{topic_id}.json
```

**Create Topic:**
```http
POST /posts.json
Content-Type: application/json
Api-Key: YOUR_API_KEY
Api-Username: username

{
  "title": "Topic Title",
  "raw": "Topic content in markdown",
  "category": 5,
  "tags": ["tag1", "tag2"]
}
```

**Update Topic:**
```http
PUT /t/{topic_id}.json
Content-Type: application/json

{
  "title": "Updated Title",
  "category_id": 6
}
```

**Delete Topic:**
```http
DELETE /t/{topic_id}.json
```

#### Posts

**Get Posts:**
```http
GET /t/{topic_id}/posts.json
```

**Create Post:**
```http
POST /posts.json
Content-Type: application/json

{
  "topic_id": 123,
  "raw": "Post content"
}
```

**Update Post:**
```http
PUT /posts/{post_id}.json
Content-Type: application/json

{
  "post": {
    "raw": "Updated content"
  }
}
```

**Delete Post:**
```http
DELETE /posts/{post_id}.json
```

#### Users

**Get User:**
```http
GET /u/{username}.json
GET /u/by-external/{external_id}.json?external_provider={provider}
```

**Create User:**
```http
POST /users.json
Content-Type: application/json

{
  "name": "User Name",
  "email": "user@example.com",
  "password": "secure_password",
  "username": "username",
  "active": true,
  "approved": true
}
```

**Update User:**
```http
PUT /users/{username}.json
Content-Type: application/json

{
  "name": "Updated Name",
  "bio_raw": "User biography"
}
```

**Sync SSO (for SSO integrations):**
```http
POST /admin/users/sync_sso.json
Content-Type: application/json
Api-Key: ADMIN_API_KEY
Api-Username: admin

{
  "sso": {
    "email": "user@example.com",
    "username": "username",
    "name": "User Name",
    "external_id": "external_user_id",
    "admin": false,
    "moderator": false,
    "groups": "trust_level_1,trust_level_2"
  },
  "sig": "HMAC_SIGNATURE"
}
```

#### Categories

**List Categories:**
```http
GET /categories.json
```

**Get Category:**
```http
GET /c/{category_slug}/{category_id}.json
```

#### Search

**Search:**
```http
GET /search.json?q={query}
GET /search/query.json?term={term}
```

#### Chat (if enabled)

**List Channels:**
```http
GET /chat/api/channels.json
```

**Get Channel:**
```http
GET /chat/api/channels/{channel_id}.json
```

**Create Message:**
```http
POST /chat/api/channels/{channel_id}/messages.json
Content-Type: application/json

{
  "message": {
    "message": "Chat message content"
  }
}
```

### Rate Limiting

API requests are subject to rate limiting. Check response headers:

- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Time when limit resets

### Error Handling

API errors follow this format:

```json
{
  "errors": ["Error message 1", "Error message 2"],
  "error_type": "invalid_parameters"
}
```

Common HTTP status codes:
- `200`: Success
- `201`: Created
- `400`: Bad Request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not Found
- `422`: Unprocessable Entity
- `429`: Too Many Requests
- `500`: Internal Server Error

---

## Single Sign-On (SSO) Integration

### Overview

Discourse Connect (SSO) allows your application to handle authentication and pass user information to SIRA Community, enabling seamless single sign-on.

### How It Works

1. User clicks "Login" in your application
2. Your application redirects to SIRA Community SSO endpoint with a signed payload
3. SIRA Community validates the signature and creates/updates the user
4. User is logged into SIRA Community
5. User can be redirected back to your application

### Configuration

#### In SIRA Community

1. Navigate to Admin → Settings → Login
2. Enable "enable sso"
3. Set "sso url" to your application's SSO endpoint
4. Set "sso secret" to a shared secret (keep this secure!)

#### In Your Application

Generate the SSO payload and signature:

```ruby
require 'base64'
require 'openssl'

def generate_sso_payload(user, sso_secret)
  # Build the payload
  payload = {
    nonce: SecureRandom.hex,
    email: user.email,
    external_id: user.id.to_s,
    username: user.username,
    name: user.name,
    avatar_url: user.avatar_url,
    avatar_force_update: false,
    bio: user.bio,
    admin: user.admin?,
    moderator: user.moderator?,
    suppress_welcome_message: false,
    require_activation: false,
    groups: user.groups.join(','),
    add_groups: '',
    remove_groups: ''
  }
  
  # Encode payload
  query_string = payload.to_query
  encoded_payload = Base64.encode64(query_string).gsub(/\s/, '')
  
  # Generate signature
  signature = OpenSSL::HMAC.hexdigest('sha256', sso_secret, encoded_payload)
  
  {
    sso: encoded_payload,
    sig: signature
  }
end
```

### SSO Endpoints

**Initiate SSO Login:**
```
GET /session/sso?{sso_params}
```

**SSO Provider (for Discourse as provider):**
```
GET /session/sso_provider
```

### SSO Payload Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `nonce` | Yes | Unique random string for this request |
| `email` | Yes | User's email address |
| `external_id` | Yes | Unique identifier from your system |
| `username` | Yes | Desired username (must be unique) |
| `name` | No | User's full name |
| `avatar_url` | No | URL to user's avatar image |
| `avatar_force_update` | No | Force avatar update (true/false) |
| `bio` | No | User biography |
| `admin` | No | Grant admin privileges (true/false) |
| `moderator` | No | Grant moderator privileges (true/false) |
| `groups` | No | Comma-separated list of groups |
| `add_groups` | No | Groups to add |
| `remove_groups` | No | Groups to remove |
| `require_activation` | No | Require email activation (true/false) |
| `suppress_welcome_message` | No | Suppress welcome email (true/false) |

### Example Implementation

**Python:**
```python
import base64
import hmac
import hashlib
import urllib.parse
from secrets import token_hex

def generate_sso_url(user, sso_secret, community_url):
    # Generate nonce
    nonce = token_hex(16)
    
    # Build payload
    payload = {
        'nonce': nonce,
        'email': user.email,
        'external_id': str(user.id),
        'username': user.username,
        'name': user.name,
        'admin': 'false',
        'moderator': 'false'
    }
    
    # Encode payload
    query_string = urllib.parse.urlencode(payload)
    encoded_payload = base64.b64encode(query_string.encode()).decode()
    
    # Generate signature
    signature = hmac.new(
        sso_secret.encode(),
        encoded_payload.encode(),
        hashlib.sha256
    ).hexdigest()
    
    # Build SSO URL
    sso_url = f"{community_url}/session/sso"
    params = {
        'sso': encoded_payload,
        'sig': signature
    }
    
    return f"{sso_url}?{urllib.parse.urlencode(params)}"
```

**JavaScript/Node.js:**
```javascript
const crypto = require('crypto');
const querystring = require('querystring');

function generateSSOUrl(user, ssoSecret, communityUrl) {
  // Generate nonce
  const nonce = crypto.randomBytes(16).toString('hex');
  
  // Build payload
  const payload = {
    nonce: nonce,
    email: user.email,
    external_id: user.id.toString(),
    username: user.username,
    name: user.name,
    admin: 'false',
    moderator: 'false'
  };
  
  // Encode payload
  const queryString = querystring.stringify(payload);
  const encodedPayload = Buffer.from(queryString).toString('base64');
  
  // Generate signature
  const signature = crypto
    .createHmac('sha256', ssoSecret)
    .update(encodedPayload)
    .digest('hex');
  
  // Build SSO URL
  const params = {
    sso: encodedPayload,
    sig: signature
  };
  
  return `${communityUrl}/session/sso?${querystring.stringify(params)}`;
}
```

### Logout

To log users out of SIRA Community:

```http
DELETE /session/{username}.json
Api-Key: YOUR_API_KEY
Api-Username: username
```

---

## OAuth 2.0 Integration

### Overview

SIRA Community supports OAuth 2.0 as both a provider and consumer, allowing integration with external OAuth providers (Google, GitHub, etc.) or allowing SIRA Community to act as an OAuth provider for your application.

### SIRA Community as OAuth Provider

To use SIRA Community as an OAuth provider:

1. Install the OAuth 2.0 Basic plugin (if not already installed)
2. Configure OAuth settings in Admin → Settings → Login
3. Your application requests authorization from SIRA Community
4. User authorizes your application
5. Your application receives an access token

### SIRA Community as OAuth Consumer

To allow users to log in with external OAuth providers:

1. Install the appropriate OAuth plugin (e.g., `discourse-oauth2-basic`)
2. Configure provider settings in Admin → Settings → Login
3. Users can authenticate using the external provider

### OAuth 2.0 Basic Plugin Configuration

**In SIRA Community Admin:**

1. Navigate to Admin → Settings → Login → OAuth 2.0 Basic
2. Configure:
   - `oauth2_client_id`: Your OAuth client ID
   - `oauth2_client_secret`: Your OAuth client secret
   - `oauth2_authorize_url`: Authorization endpoint URL
   - `oauth2_token_url`: Token endpoint URL
   - `oauth2_token_url_method`: HTTP method (GET or POST)
   - `oauth2_scope`: OAuth scopes to request
   - `oauth2_send_auth_header`: Send auth in header (true/false)
   - `oauth2_send_auth_body`: Send auth in body (true/false)

### OAuth Flow Example

```javascript
// Step 1: Redirect user to authorization endpoint
const authUrl = `${communityUrl}/auth/oauth2_basic`;
window.location.href = authUrl;

// Step 2: Handle callback (in your callback handler)
const code = new URLSearchParams(window.location.search).get('code');

// Step 3: Exchange code for token
const tokenResponse = await fetch(`${communityUrl}/auth/oauth2_basic/callback`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ code })
});

const { access_token } = await tokenResponse.json();

// Step 4: Use access token for API requests
const userResponse = await fetch(`${communityUrl}/session/current.json`, {
  headers: {
    'Authorization': `Bearer ${access_token}`
  }
});
```

---

## Webhooks Integration

### Overview

Webhooks allow SIRA Community to send real-time notifications to your application when specific events occur.

### Available Webhook Events

- `topic_created`
- `topic_edited`
- `topic_destroyed`
- `topic_recovered`
- `post_created`
- `post_edited`
- `post_destroyed`
- `post_recovered`
- `user_created`
- `user_updated`
- `user_destroyed`
- `user_logged_out`
- `user_logged_in`
- `group_created`
- `group_updated`
- `group_destroyed`
- `category_created`
- `category_updated`
- `category_destroyed`
- `tag_created`
- `tag_updated`
- `tag_destroyed`

### Creating Webhooks

**Via Admin Interface:**

1. Navigate to Admin → API → Webhooks
2. Click "New Webhook"
3. Configure:
   - **Payload URL**: Your application's webhook endpoint
   - **Content Type**: `application/json` or `application/x-www-form-urlencoded`
   - **Secret**: Shared secret for signature verification
   - **Events**: Select events to subscribe to
   - **Active**: Enable/disable webhook

**Via API:**

```http
POST /admin/api/web_hooks.json
Content-Type: application/json
Api-Key: ADMIN_API_KEY
Api-Username: admin

{
  "web_hook": {
    "payload_url": "https://your-app.com/webhooks/discourse",
    "content_type": 1,
    "secret": "your_webhook_secret",
    "wildcard_web_hook": false,
    "active": true,
    "web_hook_event_type_ids": [1, 2, 3]
  }
}
```

### Webhook Payload Format

```json
{
  "event": "post_created",
  "event_id": 12345,
  "event_name": "post_created",
  "payload": {
    "post": {
      "id": 123,
      "topic_id": 456,
      "user_id": 789,
      "username": "username",
      "raw": "Post content",
      "cooked": "<p>Post content</p>",
      "created_at": "2024-01-01T12:00:00Z"
    }
  }
}
```

### Webhook Signature Verification

SIRA Community signs webhook payloads using HMAC-SHA256. Verify signatures to ensure authenticity:

**Python:**
```python
import hmac
import hashlib

def verify_webhook_signature(payload, signature, secret):
    expected_signature = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected_signature, signature)
```

**JavaScript:**
```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(expectedSignature),
    Buffer.from(signature)
  );
}
```

### Webhook Endpoint Implementation

**Express.js Example:**
```javascript
const express = require('express');
const crypto = require('crypto');

const app = express();
app.use(express.raw({ type: 'application/json' }));

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET;

app.post('/webhooks/discourse', (req, res) => {
  const signature = req.headers['x-discourse-event-signature'];
  const payload = req.body.toString();
  
  // Verify signature
  if (!verifyWebhookSignature(payload, signature, WEBHOOK_SECRET)) {
    return res.status(401).send('Invalid signature');
  }
  
  const event = JSON.parse(payload);
  
  // Handle event
  switch (event.event_name) {
    case 'post_created':
      handlePostCreated(event.payload);
      break;
    case 'user_created':
      handleUserCreated(event.payload);
      break;
    // ... other events
  }
  
  res.status(200).send('OK');
});
```

---

## Embedding Integration

### Overview

SIRA Community supports embedding community content in external websites via iframes or JavaScript embeds.

### Configuration

1. Navigate to Admin → Customize → Embedding
2. Enable embedding
3. Add allowed domains
4. Configure embedding settings

### Embedding Methods

#### Iframe Embedding

```html
<iframe 
  src="https://your-community.com/embed/topic/{topic_id}"
  width="100%"
  height="600"
  frameborder="0">
</iframe>
```

#### JavaScript Embedding

```html
<div id="discourse-comments"></div>

<script>
  window.DiscourseEmbed = {
    discourseUrl: 'https://your-community.com/',
    discourseEmbedUrl: 'https://your-site.com/article'
  };
  
  (function() {
    var d = document.createElement('script');
    d.type = 'text/javascript';
    d.async = true;
    d.src = window.DiscourseEmbed.discourseUrl + 'javascripts/embed.js';
    (document.getElementsByTagName('head')[0] || 
     document.getElementsByTagName('body')[0]).appendChild(d);
  })();
</script>
```

### Embedding Endpoints

- `/embed/topic/{topic_id}` - Embed a specific topic
- `/embed/comments` - Embed comments for a URL

---

## Common Use Cases

### Use Case 1: User Synchronization

**Scenario:** Keep user accounts synchronized between SIRA AI and SIRA Community.

**Solution:** Use SSO for authentication and API for user updates.

```python
def sync_user_to_community(user):
    # Create or update user via SSO
    sso_url = generate_sso_url(user, SSO_SECRET, COMMUNITY_URL)
    
    # Or use API to update user
    response = requests.put(
        f"{COMMUNITY_URL}/users/{user.username}.json",
        headers={
            "Api-Key": API_KEY,
            "Api-Username": "system"
        },
        json={
            "name": user.name,
            "bio_raw": user.bio
        }
    )
    
    return response.json()
```

### Use Case 2: Content Creation

**Scenario:** Automatically create community discussions from SIRA AI content.

**Solution:** Use the Topics API to create topics.

```python
def create_community_topic(title, content, category_id, tags=None):
    response = requests.post(
        f"{COMMUNITY_URL}/posts.json",
        headers={
            "Api-Key": API_KEY,
            "Api-Username": "sira_ai_bot"
        },
        json={
            "title": title,
            "raw": content,
            "category": category_id,
            "tags": tags or []
        }
    )
    
    return response.json()
```

### Use Case 3: Real-time Notifications

**Scenario:** Notify SIRA AI when users interact with community content.

**Solution:** Set up webhooks to receive real-time events.

```python
@app.route('/webhooks/community', methods=['POST'])
def handle_community_webhook():
    event = request.json
    
    if event['event_name'] == 'post_created':
        # Notify SIRA AI about new post
        notify_sira_ai(event['payload'])
    
    return 'OK', 200
```

### Use Case 4: Unified Search

**Scenario:** Search across both SIRA AI and community content.

**Solution:** Use the Search API and combine results.

```python
def unified_search(query):
    # Search community
    community_results = requests.get(
        f"{COMMUNITY_URL}/search.json",
        params={"q": query},
        headers={
            "Api-Key": API_KEY,
            "Api-Username": "system"
        }
    ).json()
    
    # Search SIRA AI
    ai_results = search_sira_ai(query)
    
    # Combine and rank results
    return combine_results(community_results, ai_results)
```

### Use Case 5: User Activity Dashboard

**Scenario:** Display user's community activity in SIRA AI dashboard.

**Solution:** Fetch user data and activity via API.

```python
def get_user_activity(username):
    # Get user profile
    user = requests.get(
        f"{COMMUNITY_URL}/u/{username}.json",
        headers={
            "Api-Key": API_KEY,
            "Api-Username": "system"
        }
    ).json()
    
    # Get user's topics
    topics = requests.get(
        f"{COMMUNITY_URL}/users/{username}/activity/topics.json",
        headers={
            "Api-Key": API_KEY,
            "Api-Username": "system"
        }
    ).json()
    
    return {
        "user": user,
        "topics": topics
    }
```

---

## Code Examples

### Complete Integration Example (Python)

```python
import requests
import hmac
import hashlib
import base64
import urllib.parse
from secrets import token_hex

class SIRACommunityClient:
    def __init__(self, base_url, api_key, api_username, sso_secret=None):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.api_username = api_username
        self.sso_secret = sso_secret
        self.headers = {
            "Api-Key": api_key,
            "Api-Username": api_username,
            "Content-Type": "application/json"
        }
    
    def get_topic(self, topic_id):
        """Get a topic by ID"""
        response = requests.get(
            f"{self.base_url}/t/{topic_id}.json",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def create_topic(self, title, content, category_id, tags=None):
        """Create a new topic"""
        data = {
            "title": title,
            "raw": content,
            "category": category_id
        }
        if tags:
            data["tags"] = tags
        
        response = requests.post(
            f"{self.base_url}/posts.json",
            headers=self.headers,
            json=data
        )
        response.raise_for_status()
        return response.json()
    
    def create_post(self, topic_id, content):
        """Create a post in a topic"""
        response = requests.post(
            f"{self.base_url}/posts.json",
            headers=self.headers,
            json={
                "topic_id": topic_id,
                "raw": content
            }
        )
        response.raise_for_status()
        return response.json()
    
    def get_user(self, username):
        """Get user information"""
        response = requests.get(
            f"{self.base_url}/u/{username}.json",
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def generate_sso_url(self, user):
        """Generate SSO URL for user login"""
        if not self.sso_secret:
            raise ValueError("SSO secret not configured")
        
        nonce = token_hex(16)
        payload = {
            'nonce': nonce,
            'email': user.email,
            'external_id': str(user.id),
            'username': user.username,
            'name': user.name,
            'admin': 'false',
            'moderator': 'false'
        }
        
        query_string = urllib.parse.urlencode(payload)
        encoded_payload = base64.b64encode(query_string.encode()).decode()
        
        signature = hmac.new(
            self.sso_secret.encode(),
            encoded_payload.encode(),
            hashlib.sha256
        ).hexdigest()
        
        params = {
            'sso': encoded_payload,
            'sig': signature
        }
        
        return f"{self.base_url}/session/sso?{urllib.parse.urlencode(params)}"
    
    def search(self, query):
        """Search community content"""
        response = requests.get(
            f"{self.base_url}/search.json",
            params={"q": query},
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()

# Usage example
client = SIRACommunityClient(
    base_url="https://community.sira.ai",
    api_key="your_api_key",
    api_username="sira_ai_bot",
    sso_secret="your_sso_secret"
)

# Create a topic
topic = client.create_topic(
    title="Welcome to SIRA AI Community",
    content="This is the official community for SIRA AI users.",
    category_id=5,
    tags=["announcement", "welcome"]
)

# Get user info
user = client.get_user("john_doe")

# Generate SSO URL
sso_url = client.generate_sso_url(user)
```

### Complete Integration Example (JavaScript/Node.js)

```javascript
const axios = require('axios');
const crypto = require('crypto');
const querystring = require('querystring');

class SIRACommunityClient {
  constructor(baseUrl, apiKey, apiUsername, ssoSecret = null) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.apiUsername = apiUsername;
    this.ssoSecret = ssoSecret;
    this.headers = {
      'Api-Key': apiKey,
      'Api-Username': apiUsername,
      'Content-Type': 'application/json'
    };
  }
  
  async getTopic(topicId) {
    const response = await axios.get(
      `${this.baseUrl}/t/${topicId}.json`,
      { headers: this.headers }
    );
    return response.data;
  }
  
  async createTopic(title, content, categoryId, tags = null) {
    const data = {
      title,
      raw: content,
      category: categoryId
    };
    if (tags) {
      data.tags = tags;
    }
    
    const response = await axios.post(
      `${this.baseUrl}/posts.json`,
      data,
      { headers: this.headers }
    );
    return response.data;
  }
  
  async createPost(topicId, content) {
    const response = await axios.post(
      `${this.baseUrl}/posts.json`,
      {
        topic_id: topicId,
        raw: content
      },
      { headers: this.headers }
    );
    return response.data;
  }
  
  async getUser(username) {
    const response = await axios.get(
      `${this.baseUrl}/u/${username}.json`,
      { headers: this.headers }
    );
    return response.data;
  }
  
  generateSSOUrl(user) {
    if (!this.ssoSecret) {
      throw new Error('SSO secret not configured');
    }
    
    const nonce = crypto.randomBytes(16).toString('hex');
    const payload = {
      nonce,
      email: user.email,
      external_id: user.id.toString(),
      username: user.username,
      name: user.name,
      admin: 'false',
      moderator: 'false'
    };
    
    const queryString = querystring.stringify(payload);
    const encodedPayload = Buffer.from(queryString).toString('base64');
    
    const signature = crypto
      .createHmac('sha256', this.ssoSecret)
      .update(encodedPayload)
      .digest('hex');
    
    const params = {
      sso: encodedPayload,
      sig: signature
    };
    
    return `${this.baseUrl}/session/sso?${querystring.stringify(params)}`;
  }
  
  async search(query) {
    const response = await axios.get(
      `${this.baseUrl}/search.json`,
      {
        params: { q: query },
        headers: this.headers
      }
    );
    return response.data;
  }
}

// Usage example
const client = new SIRACommunityClient(
  'https://community.sira.ai',
  'your_api_key',
  'sira_ai_bot',
  'your_sso_secret'
);

// Create a topic
const topic = await client.createTopic(
  'Welcome to SIRA AI Community',
  'This is the official community for SIRA AI users.',
  5,
  ['announcement', 'welcome']
);

// Get user info
const user = await client.getUser('john_doe');

// Generate SSO URL
const ssoUrl = client.generateSSOUrl(user);
```

---

## Best Practices

### 1. API Key Management

- **Use separate API keys** for different services/environments
- **Rotate API keys** regularly
- **Use granular scopes** - only grant necessary permissions
- **Restrict by IP** when possible
- **Never commit API keys** to version control

### 2. Error Handling

- **Implement retry logic** with exponential backoff
- **Handle rate limits** gracefully
- **Log errors** for debugging
- **Provide user-friendly error messages**

### 3. Performance

- **Cache API responses** when appropriate
- **Use pagination** for large datasets
- **Batch operations** when possible
- **Monitor API usage** and rate limits

### 4. Security

- **Always verify webhook signatures**
- **Use HTTPS** for all API communications
- **Validate user input** before sending to API
- **Implement proper authentication** for webhook endpoints
- **Keep SSO secrets secure**

### 5. User Experience

- **Handle SSO failures** gracefully
- **Provide clear error messages**
- **Show loading states** during API calls
- **Sync user data** regularly but not excessively

### 6. Testing

- **Test in development/staging** environments first
- **Use test API keys** for development
- **Mock API responses** in unit tests
- **Test error scenarios** thoroughly

---

## Security Considerations

### API Security

1. **API Key Storage**: Store API keys securely (environment variables, secret management)
2. **HTTPS Only**: Always use HTTPS for API communications
3. **IP Restrictions**: Restrict API keys to specific IP addresses when possible
4. **Scope Limitation**: Grant minimum necessary permissions
5. **Key Rotation**: Regularly rotate API keys

### SSO Security

1. **Secret Management**: Keep SSO secrets secure and never expose them
2. **Signature Verification**: Always verify SSO signatures
3. **Nonce Validation**: Use unique nonces for each SSO request
4. **HTTPS**: Always use HTTPS for SSO redirects
5. **User Validation**: Validate user data before creating accounts

### Webhook Security

1. **Signature Verification**: Always verify webhook signatures
2. **HTTPS**: Use HTTPS for webhook endpoints
3. **Idempotency**: Handle duplicate webhook events
4. **Rate Limiting**: Implement rate limiting on webhook endpoints
5. **Secret Rotation**: Regularly rotate webhook secrets

### Data Privacy

1. **GDPR Compliance**: Ensure compliance with data protection regulations
2. **User Consent**: Obtain user consent before sharing data
3. **Data Minimization**: Only request necessary user data
4. **Secure Storage**: Encrypt sensitive data at rest
5. **Access Control**: Implement proper access controls

---

## Troubleshooting

### Common Issues

#### 1. API Authentication Failures

**Problem:** `401 Unauthorized` errors

**Solutions:**
- Verify API key is correct
- Check API username matches the key's associated user
- Ensure API key is not revoked
- Verify IP restrictions (if configured)

#### 2. SSO Signature Mismatch

**Problem:** SSO login fails with signature error

**Solutions:**
- Verify SSO secret matches on both sides
- Check payload encoding (must be base64)
- Ensure signature uses HMAC-SHA256
- Verify nonce is unique for each request

#### 3. Rate Limiting

**Problem:** `429 Too Many Requests` errors

**Solutions:**
- Implement exponential backoff
- Reduce request frequency
- Cache responses when possible
- Use webhooks instead of polling

#### 4. Webhook Not Receiving Events

**Problem:** Webhooks not firing

**Solutions:**
- Verify webhook is active in admin panel
- Check webhook URL is accessible
- Verify SSL certificate is valid
- Check webhook event subscriptions
- Review webhook logs in admin panel

#### 5. User Creation Failures

**Problem:** Users not created via SSO or API

**Solutions:**
- Verify email is unique
- Check username format (alphanumeric, underscores, hyphens)
- Ensure required fields are provided
- Check user approval settings
- Verify SSO is enabled

### Debugging Tips

1. **Enable API Debugging**: Check response headers for error details
2. **Review Logs**: Check SIRA Community logs for errors
3. **Test Endpoints**: Use tools like Postman or curl to test endpoints
4. **Check Permissions**: Verify API key has necessary scopes
5. **Validate Data**: Ensure request payload matches expected format

### Getting Help

- **Community Support**: Visit the SIRA Community meta site
- **Documentation**: Check Discourse documentation
- **GitHub Issues**: Report bugs on GitHub
- **Admin Logs**: Review admin logs for detailed error messages

---

## Additional Resources

### Official Documentation

- [Discourse API Documentation](https://docs.discourse.org/)
- [Discourse SSO Documentation](https://meta.discourse.org/t/discourseconnect-official-single-sign-on-for-discourse-sso/13045)
- [Discourse Webhooks Documentation](https://meta.discourse.org/t/official-discourse-webhooks/54484)

### Community Resources

- [Discourse Meta Community](https://meta.discourse.org/)
- [Discourse Developer Documentation](https://meta.discourse.org/c/dev)

### API Reference

- [Discourse API Endpoints](https://docs.discourse.org/)
- [API Key Scopes Reference](https://github.com/discourse/discourse/blob/main/app/models/api_key_scope.rb)

---

## Conclusion

This integration guide provides comprehensive information for integrating SIRA Community with external applications like SIRA AI. By following the methods and best practices outlined in this document, you can create seamless integrations that leverage the full power of SIRA Community's community features.

For additional support or questions, please refer to the resources listed above or contact the SIRA Community development team.

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Maintained By:** SIRA Community Team

