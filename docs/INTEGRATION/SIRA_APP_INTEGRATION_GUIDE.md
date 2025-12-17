# SIRA App ↔ SIRA Community Integration Guide

## Overview

This guide provides comprehensive instructions for integrating SIRA App with SIRA Community (Discourse) to create a seamless user experience where users can navigate between the main application and the community platform as an integral part of their workflow.

## Prerequisites

**Before starting implementation, ensure the Community App team has completed:**
1. Enabled Discourse Connect (SSO) in Discourse admin panel
2. Generated API key and shared it securely
3. Shared SSO secret key securely

See `COMMUNITY_APP_SETUP.md` for details on what the Community App team needs to configure.

**Note:** No code changes are required in the Community App - all integration code is implemented in SIRA App.

**Important:** Throughout this guide you may see example URLs like `https://community.sira.ai:8443`.
Replace them with your actual community origin (i.e. your `DISCOURSE_BASE_URL`), for example:
- Local: `https://local.community.sira.ai:8443`
- Production: `https://community.sira.ai` (typically on port 443)

## Table of Contents

1. [Integration Architecture](#integration-architecture)
2. [Single Sign-On (SSO) Integration](#single-sign-on-sso-integration)
3. [Navigation & UX Flow](#navigation--ux-flow)
4. [API Access for Community Data](#api-access-for-community-data)
5. [Authentication Flow](#authentication-flow)
6. [Implementation Examples](#implementation-examples)
7. [Security Considerations](#security-considerations)
8. [Troubleshooting](#troubleshooting)

---

## Integration Architecture

### High-Level Architecture

```
┌─────────────────┐         ┌──────────────────┐
│   SIRA App      │◄────────┤  Shared Session   │
│  (Main App)     │         │   (JWT/Redis)    │
└────────┬────────┘         └────────┬─────────┘
         │                            │
         │ SSO/OAuth                  │
         │                            │
         ▼                            ▼
┌─────────────────┐         ┌──────────────────┐
│ SIRA Community  │◄────────┤  Discourse API   │
│   (Discourse)    │         │   (REST/GraphQL) │
└─────────────────┘         └──────────────────┘
```

### Key Components

1. **SIRA App** - Main application (Node.js/React)
2. **SIRA Community** - Discourse-based community platform
3. **Shared Authentication** - JWT tokens, Redis session store
4. **API Gateway** - Unified API access point
5. **SSO Provider** - Discourse Connect (OAuth 2.0)

---

## Single Sign-On (SSO) Integration

### Discourse Connect (Recommended)

Discourse Connect is Discourse's built-in SSO solution that allows seamless authentication between SIRA App and SIRA Community.

#### Step 1: Enable Discourse Connect in Discourse

1. **Access Discourse Admin Panel**
   - Navigate to: `https://community.sira.ai:8443/admin/site_settings/category/login`
   - Or: `https://community.sira.ai:8443/admin/site_settings/category/required`

2. **Enable Discourse Connect**
   ```
   enable_discourse_connect = true
   discourse_connect_url = https://app.sira.ai/auth/discourse/callback
   discourse_connect_secret = YOUR_SECRET_KEY_HERE
   ```

3. **Configure Additional Settings**
   ```
   discourse_connect_provider_name = SIRA App
   discourse_connect_overrides_email = true
   discourse_connect_overrides_username = true
   discourse_connect_overrides_name = true
   ```

#### Step 2: Configure SIRA App as SSO Provider

**In SIRA App Backend (`backend/config/discourse.js`):**

```javascript
module.exports = {
  discourse: {
    baseUrl: process.env.DISCOURSE_BASE_URL || 'https://community.sira.ai:8443',
    ssoSecret: process.env.DISCOURSE_SSO_SECRET, // Must match Discourse setting
    ssoUrl: `${process.env.DISCOURSE_BASE_URL}/session/sso_provider`,
    returnUrl: `${process.env.APP_BASE_URL}/auth/discourse/callback`,
  }
};
```

**Environment Variables (`backend/.env`):**

```bash
DISCOURSE_BASE_URL=https://community.sira.ai:8443
DISCOURSE_SSO_SECRET=your_shared_secret_key_here
APP_BASE_URL=https://app.sira.ai
```

#### Step 3: Implement SSO Endpoint in SIRA App

**Backend Route (`backend/routes/auth.js`):**

```javascript
const crypto = require('crypto');
const querystring = require('querystring');
const { discourse } = require('../config/discourse');

/**
 * Initiate SSO login to Discourse
 * GET /auth/discourse/login
 */
router.get('/discourse/login', authenticateUser, async (req, res) => {
  try {
    const user = req.user; // From JWT middleware
    
    // Generate nonce
    const nonce = crypto.randomBytes(16).toString('hex');
    
    // Store nonce in Redis (expires in 5 minutes)
    await redis.setex(`discourse_sso_nonce:${nonce}`, 300, user.id);
    
    // Build SSO payload
    const payload = {
      nonce: nonce,
      email: user.email,
      username: user.username || user.email.split('@')[0],
      name: user.name || user.username,
      external_id: user.id.toString(),
      require_activation: 'false',
      admin: user.role === 'admin' ? 'true' : 'false',
      moderator: user.role === 'moderator' ? 'true' : 'false',
    };
    
    // Base64 encode payload
    const payloadBase64 = Buffer.from(querystring.stringify(payload)).toString('base64');
    
    // Generate signature
    const hmac = crypto.createHmac('sha256', discourse.ssoSecret);
    hmac.update(payloadBase64);
    const signature = hmac.digest('hex');
    
    // Build SSO URL
    const ssoUrl = `${discourse.ssoUrl}?sso=${encodeURIComponent(payloadBase64)}&sig=${signature}`;
    
    res.redirect(ssoUrl);
  } catch (error) {
    console.error('Discourse SSO error:', error);
    res.status(500).json({ error: 'Failed to initiate SSO' });
  }
});

/**
 * Handle Discourse SSO callback
 * GET /auth/discourse/callback
 */
router.get('/discourse/callback', async (req, res) => {
  try {
    const { sso, sig } = req.query;
    
    if (!sso || !sig) {
      return res.status(400).json({ error: 'Missing SSO parameters' });
    }
    
    // Verify signature
    const hmac = crypto.createHmac('sha256', discourse.ssoSecret);
    hmac.update(sso);
    const expectedSig = hmac.digest('hex');
    
    if (sig !== expectedSig) {
      return res.status(403).json({ error: 'Invalid signature' });
    }
    
    // Decode payload
    const payload = querystring.parse(Buffer.from(sso, 'base64').toString());
    const { nonce, return_sso_url } = payload;
    
    // Verify nonce
    const userId = await redis.get(`discourse_sso_nonce:${nonce}`);
    if (!userId) {
      return res.status(403).json({ error: 'Invalid or expired nonce' });
    }
    
    // Clean up nonce
    await redis.del(`discourse_sso_nonce:${nonce}`);
    
    // Get user from database
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Build return payload
    const returnPayload = {
      nonce: nonce,
      email: user.email,
      username: user.username || user.email.split('@')[0],
      name: user.name || user.username,
      external_id: user.id.toString(),
      require_activation: 'false',
      admin: user.role === 'admin' ? 'true' : 'false',
      moderator: user.role === 'moderator' ? 'true' : 'false',
    };
    
    const returnPayloadBase64 = Buffer.from(querystring.stringify(returnPayload)).toString('base64');
    const returnHmac = crypto.createHmac('sha256', discourse.ssoSecret);
    returnHmac.update(returnPayloadBase64);
    const returnSig = returnHmac.digest('hex');
    
    // Redirect back to Discourse
    const returnUrl = `${return_sso_url}?sso=${encodeURIComponent(returnPayloadBase64)}&sig=${returnSig}`;
    res.redirect(returnUrl);
  } catch (error) {
    console.error('Discourse SSO callback error:', error);
    res.status(500).json({ error: 'SSO callback failed' });
  }
});
```

#### Step 4: Frontend Integration

**React Component (`frontend/components/CommunityLink.jsx`):**

```jsx
import React from 'react';
import { useAuth } from '../contexts/AuthContext';

const CommunityLink = ({ children, className }) => {
  const { user, isAuthenticated } = useAuth();
  
  const handleCommunityClick = async (e) => {
    e.preventDefault();
    
    if (!isAuthenticated) {
      // Redirect to login first
      window.location.href = '/login?redirect=/community';
      return;
    }
    
    // Initiate SSO login to Discourse
    try {
      const response = await fetch('/api/auth/discourse/login', {
        method: 'GET',
        credentials: 'include', // Include cookies for authentication
      });
      
      if (response.redirected) {
        // Follow redirect to Discourse SSO
        window.location.href = response.url;
      } else {
        throw new Error('Failed to initiate SSO');
      }
    } catch (error) {
      console.error('Community SSO error:', error);
      // Fallback: direct link to community
      window.open('https://community.sira.ai:8443', '_blank');
    }
  };
  
  return (
    <a
      href="https://community.sira.ai:8443"
      onClick={handleCommunityClick}
      className={className}
      target="_blank"
      rel="noopener noreferrer"
    >
      {children || 'Community'}
    </a>
  );
};

export default CommunityLink;
```

---

## Navigation & UX Flow

### Seamless Navigation Pattern

The goal is to make navigation between SIRA App and SIRA Community feel like a single integrated application.

#### 1. Navigation Menu Integration

**Add Community Link to Main Navigation (`frontend/components/Navigation.jsx`):**

```jsx
import React from 'react';
import { Link } from 'react-router-dom';
import CommunityLink from './CommunityLink';

const Navigation = () => {
  return (
    <nav className="main-navigation">
      <Link to="/dashboard">Dashboard</Link>
      <Link to="/projects">Projects</Link>
      <Link to="/settings">Settings</Link>
      
      {/* Community Link with SSO */}
      <CommunityLink className="nav-link">
        <span className="icon">💬</span>
        Community
      </CommunityLink>
    </nav>
  );
};
```

#### 2. Embedded Community Widget

**Display Recent Community Activity (`frontend/components/CommunityWidget.jsx`):**

```jsx
import React, { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import CommunityLink from './CommunityLink';

const CommunityWidget = () => {
  const { isAuthenticated } = useAuth();
  const [recentTopics, setRecentTopics] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    if (isAuthenticated) {
      fetchCommunityActivity();
    } else {
      setLoading(false);
    }
  }, [isAuthenticated]);
  
  const fetchCommunityActivity = async () => {
    try {
      const response = await fetch('/api/community/recent-topics', {
        credentials: 'include',
      });
      
      if (response.ok) {
        const data = await response.json();
        setRecentTopics(data.topics || []);
      }
    } catch (error) {
      console.error('Failed to fetch community activity:', error);
    } finally {
      setLoading(false);
    }
  };
  
  if (!isAuthenticated) {
    return (
      <div className="community-widget">
        <h3>Join Our Community</h3>
        <p>Connect with other users, share ideas, and get help.</p>
        <CommunityLink className="btn btn-primary">
          Visit Community
        </CommunityLink>
      </div>
    );
  }
  
  if (loading) {
    return <div className="community-widget">Loading community activity...</div>;
  }
  
  return (
    <div className="community-widget">
      <div className="widget-header">
        <h3>Community Activity</h3>
        <CommunityLink className="btn-link">View All</CommunityLink>
      </div>
      
      <ul className="topic-list">
        {recentTopics.map((topic) => (
          <li key={topic.id}>
            <a
              href={`https://community.sira.ai:8443/t/${topic.slug}/${topic.id}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {topic.title}
            </a>
            <span className="meta">
              {topic.posts_count} replies • {topic.views} views
            </span>
          </li>
        ))}
      </ul>
      
      <CommunityLink className="btn btn-secondary">
        Go to Community
      </CommunityLink>
    </div>
  );
};

export default CommunityWidget;
```

#### 3. Deep Linking from SIRA App to Community

**Helper Function (`frontend/utils/community.js`):**

```javascript
/**
 * Navigate to Discourse community with SSO
 * @param {string} path - Discourse path (e.g., '/t/topic-slug/123')
 * @param {boolean} newTab - Open in new tab
 */
export const navigateToCommunity = async (path = '', newTab = false) => {
  const baseUrl = 'https://community.sira.ai:8443';
  const fullPath = path.startsWith('/') ? path : `/${path}`;
  const url = `${baseUrl}${fullPath}`;
  
  // Check if user is authenticated
  const isAuthenticated = await checkAuthStatus();
  
  if (!isAuthenticated) {
    // Redirect to login with community redirect
    window.location.href = `/login?redirect=${encodeURIComponent(url)}`;
    return;
  }
  
  // Initiate SSO login, then redirect to specific path
  try {
    const response = await fetch('/api/auth/discourse/login', {
      method: 'GET',
      credentials: 'include',
    });
    
    if (response.redirected) {
      // Store target path in sessionStorage
      sessionStorage.setItem('discourse_redirect_path', fullPath);
      
      if (newTab) {
        window.open(response.url, '_blank');
      } else {
        window.location.href = response.url;
      }
    } else {
      // Fallback: direct link
      if (newTab) {
        window.open(url, '_blank');
      } else {
        window.location.href = url;
      }
    }
  } catch (error) {
    console.error('Community navigation error:', error);
    // Fallback: direct link
    if (newTab) {
      window.open(url, '_blank');
    } else {
      window.location.href = url;
    }
  }
};

/**
 * Check if user is authenticated
 */
const checkAuthStatus = async () => {
  try {
    const response = await fetch('/api/auth/status', {
      credentials: 'include',
    });
    return response.ok && (await response.json()).authenticated;
  } catch {
    return false;
  }
};
```

---

## API Access for Community Data

### Discourse API Overview

Discourse provides a comprehensive REST API for accessing community data. All API requests require authentication via API keys.

#### Step 1: Generate API Key in Discourse

1. **Access Discourse Admin Panel**
   - Navigate to: `https://community.sira.ai:8443/admin/api/keys`

2. **Create New API Key**
   - Click "New API Key"
   - Set description: "SIRA App Integration"
   - Select scopes:
     - `read` - Read topics, posts, users
     - `write` - Create/update topics and posts
     - `message_bus` - Access message bus
   - Copy the generated API key

#### Step 2: Configure API Key in SIRA App

**Environment Variables (`backend/.env`):**

```bash
DISCOURSE_API_KEY=your_discourse_api_key_here
DISCOURSE_API_USERNAME=system  # Discourse system user for API calls
```

#### Step 3: Create Discourse API Client

**Backend Service (`backend/services/discourseApi.js`):**

```javascript
const axios = require('axios');

class DiscourseApiClient {
  constructor(baseUrl, apiKey, apiUsername) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.apiUsername = apiUsername;
    this.client = axios.create({
      baseURL: baseUrl,
      headers: {
        'Api-Key': apiKey,
        'Api-Username': apiUsername,
      },
    });
  }
  
  /**
   * Get recent topics
   * @param {number} limit - Number of topics to return
   * @param {string} category - Category slug (optional)
   */
  async getRecentTopics(limit = 10, category = null) {
    try {
      const params = {
        order: 'created',
        ascending: false,
        limit: limit,
      };
      
      if (category) {
        params.category = category;
      }
      
      const response = await this.client.get('/latest.json', { params });
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
  
  /**
   * Get topic by ID
   * @param {number} topicId - Topic ID
   */
  async getTopic(topicId) {
    try {
      const response = await this.client.get(`/t/${topicId}.json`);
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
  
  /**
   * Get user by username
   * @param {string} username - Username
   */
  async getUser(username) {
    try {
      const response = await this.client.get(`/users/${username}.json`);
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
  
  /**
   * Create topic
   * @param {string} title - Topic title
   * @param {string} raw - Topic content (raw markdown)
   * @param {string} category - Category ID
   */
  async createTopic(title, raw, category) {
    try {
      const response = await this.client.post('/posts.json', {
        title,
        raw,
        category,
      });
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
  
  /**
   * Search topics
   * @param {string} query - Search query
   * @param {number} limit - Number of results
   */
  async searchTopics(query, limit = 20) {
    try {
      const response = await this.client.get('/search.json', {
        params: {
          q: query,
          limit: limit,
        },
      });
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
  
  /**
   * Get categories
   */
  async getCategories() {
    try {
      const response = await this.client.get('/categories.json');
      return response.data;
    } catch (error) {
      console.error('Discourse API error:', error);
      throw error;
    }
  }
}

module.exports = DiscourseApiClient;
```

#### Step 4: Create API Routes in SIRA App

**Backend Routes (`backend/routes/community.js`):**

```javascript
const express = require('express');
const router = express.Router();
const DiscourseApiClient = require('../services/discourseApi');
const { authenticateUser } = require('../middleware/auth');

// Initialize Discourse API client
const discourseApi = new DiscourseApiClient(
  process.env.DISCOURSE_BASE_URL,
  process.env.DISCOURSE_API_KEY,
  process.env.DISCOURSE_API_USERNAME
);

/**
 * GET /api/community/recent-topics
 * Get recent topics from community
 */
router.get('/recent-topics', authenticateUser, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const category = req.query.category || null;
    
    const data = await discourseApi.getRecentTopics(limit, category);
    
    res.json({
      topics: data.topic_list.topics.map(topic => ({
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        posts_count: topic.posts_count,
        views: topic.views,
        created_at: topic.created_at,
        last_posted_at: topic.last_posted_at,
        category_id: topic.category_id,
      })),
    });
  } catch (error) {
    console.error('Error fetching recent topics:', error);
    res.status(500).json({ error: 'Failed to fetch community topics' });
  }
});

/**
 * GET /api/community/topic/:id
 * Get specific topic
 */
router.get('/topic/:id', authenticateUser, async (req, res) => {
  try {
    const topicId = parseInt(req.params.id);
    const data = await discourseApi.getTopic(topicId);
    
    res.json({
      topic: {
        id: data.id,
        title: data.title,
        slug: data.slug,
        posts_count: data.posts_count,
        views: data.views,
        created_at: data.created_at,
        category_id: data.category_id,
        posts: data.post_stream.posts.map(post => ({
          id: post.id,
          username: post.username,
          name: post.name,
          cooked: post.cooked,
          created_at: post.created_at,
        })),
      },
    });
  } catch (error) {
    console.error('Error fetching topic:', error);
    res.status(500).json({ error: 'Failed to fetch topic' });
  }
});

/**
 * GET /api/community/search
 * Search topics
 */
router.get('/search', authenticateUser, async (req, res) => {
  try {
    const query = req.query.q;
    const limit = parseInt(req.query.limit) || 20;
    
    if (!query) {
      return res.status(400).json({ error: 'Search query required' });
    }
    
    const data = await discourseApi.searchTopics(query, limit);
    
    res.json({
      results: data.topics || [],
    });
  } catch (error) {
    console.error('Error searching topics:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

/**
 * GET /api/community/categories
 * Get all categories
 */
router.get('/categories', authenticateUser, async (req, res) => {
  try {
    const data = await discourseApi.getCategories();
    
    res.json({
      categories: data.category_list.categories.map(cat => ({
        id: cat.id,
        name: cat.name,
        slug: cat.slug,
        description: cat.description,
        topic_count: cat.topic_count,
      })),
    });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

/**
 * POST /api/community/topic
 * Create new topic (requires user's Discourse username)
 */
router.post('/topic', authenticateUser, async (req, res) => {
  try {
    const { title, content, category } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content required' });
    }
    
    // Get user's Discourse username from database
    const user = await User.findById(req.user.id);
    if (!user.discourseUsername) {
      return res.status(400).json({ 
        error: 'User not linked to Discourse account. Please visit community first.' 
      });
    }
    
    // Create topic using user's Discourse username
    const discourseApiForUser = new DiscourseApiClient(
      process.env.DISCOURSE_BASE_URL,
      process.env.DISCOURSE_API_KEY,
      user.discourseUsername // Use user's Discourse username
    );
    
    const data = await discourseApiForUser.createTopic(title, content, category);
    
    res.json({
      topic: {
        id: data.topic_id,
        url: `https://community.sira.ai:8443/t/${data.topic_slug}/${data.topic_id}`,
      },
    });
  } catch (error) {
    console.error('Error creating topic:', error);
    res.status(500).json({ error: 'Failed to create topic' });
  }
});

module.exports = router;
```

---

## Authentication Flow

### Complete Authentication Flow Diagram

```
┌──────────┐                    ┌──────────────┐                    ┌─────────────┐
│ SIRA App │                    │  SIRA App    │                    │   Discourse │
│  (User)  │                    │  (Backend)   │                    │  (Community)│
└────┬─────┘                    └──────┬───────┘                    └──────┬──────┘
     │                                  │                                  │
     │ 1. Click "Community"            │                                  │
     │─────────────────────────────────>│                                  │
     │                                  │                                  │
     │                                  │ 2. Generate SSO payload          │
     │                                  │    (nonce, user data)            │
     │                                  │                                  │
     │                                  │ 3. Redirect to Discourse SSO    │
     │                                  │─────────────────────────────────>│
     │                                  │                                  │
     │                                  │                                  │ 4. Verify signature
     │                                  │                                  │    & nonce
     │                                  │                                  │
     │                                  │ 5. Redirect to callback          │
     │                                  │<─────────────────────────────────│
     │                                  │                                  │
     │                                  │ 6. Build return payload          │
     │                                  │    (user data, signature)        │
     │                                  │                                  │
     │                                  │ 7. Redirect back to Discourse    │
     │                                  │─────────────────────────────────>│
     │                                  │                                  │
     │                                  │                                  │ 8. Create/update user
     │                                  │                                  │    & log in
     │                                  │                                  │
     │ 9. User logged into Community   │                                  │
     │<─────────────────────────────────│                                  │
     │                                  │                                  │
```

### Implementation Details

1. **User clicks "Community" link** in SIRA App
2. **SIRA App backend** generates SSO payload with user data
3. **Redirect to Discourse** with SSO payload
4. **Discourse verifies** signature and nonce
5. **Discourse redirects** to callback URL
6. **SIRA App builds** return payload with user data
7. **Redirect back to Discourse** with return payload
8. **Discourse creates/updates user** and logs them in
9. **User is authenticated** in both applications

---

## Implementation Examples

### Example 1: Community Dashboard Widget

**Frontend Component (`frontend/components/CommunityDashboard.jsx`):**

```jsx
import React, { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { navigateToCommunity } from '../utils/community';

const CommunityDashboard = () => {
  const { user } = useAuth();
  const [stats, setStats] = useState(null);
  const [recentActivity, setRecentActivity] = useState([]);
  
  useEffect(() => {
    fetchCommunityStats();
    fetchRecentActivity();
  }, []);
  
  const fetchCommunityStats = async () => {
    try {
      const response = await fetch('/api/community/stats', {
        credentials: 'include',
      });
      if (response.ok) {
        const data = await response.json();
        setStats(data);
      }
    } catch (error) {
      console.error('Failed to fetch community stats:', error);
    }
  };
  
  const fetchRecentActivity = async () => {
    try {
      const response = await fetch('/api/community/recent-topics?limit=5', {
        credentials: 'include',
      });
      if (response.ok) {
        const data = await response.json();
        setRecentActivity(data.topics || []);
      }
    } catch (error) {
      console.error('Failed to fetch recent activity:', error);
    }
  };
  
  return (
    <div className="community-dashboard">
      <div className="dashboard-header">
        <h2>Community</h2>
        <button
          onClick={() => navigateToCommunity('', false)}
          className="btn btn-primary"
        >
          Visit Community
        </button>
      </div>
      
      {stats && (
        <div className="stats-grid">
          <div className="stat-card">
            <h3>{stats.total_topics}</h3>
            <p>Topics</p>
          </div>
          <div className="stat-card">
            <h3>{stats.total_posts}</h3>
            <p>Posts</p>
          </div>
          <div className="stat-card">
            <h3>{stats.total_users}</h3>
            <p>Members</p>
          </div>
        </div>
      )}
      
      <div className="recent-activity">
        <h3>Recent Activity</h3>
        <ul>
          {recentActivity.map((topic) => (
            <li key={topic.id}>
              <a
                href={`https://community.sira.ai:8443/t/${topic.slug}/${topic.id}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                {topic.title}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default CommunityDashboard;
```

### Example 2: Create Topic from SIRA App

**Frontend Component (`frontend/components/CreateCommunityTopic.jsx`):**

```jsx
import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';

const CreateCommunityTopic = ({ onSuccess }) => {
  const { user } = useAuth();
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [category, setCategory] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch('/api/community/topic', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          title,
          content,
          category,
        }),
      });
      
      if (response.ok) {
        const data = await response.json();
        if (onSuccess) {
          onSuccess(data.topic);
        }
        // Reset form
        setTitle('');
        setContent('');
        setCategory('');
      } else {
        const errorData = await response.json();
        setError(errorData.error || 'Failed to create topic');
      }
    } catch (error) {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <form onSubmit={handleSubmit} className="create-topic-form">
      <h3>Create Community Topic</h3>
      
      {error && <div className="error-message">{error}</div>}
      
      <div className="form-group">
        <label>Title</label>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
      </div>
      
      <div className="form-group">
        <label>Content</label>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          rows={10}
          required
        />
      </div>
      
      <div className="form-group">
        <label>Category</label>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          <option value="">Select category</option>
          {/* Categories loaded from API */}
        </select>
      </div>
      
      <button
        type="submit"
        disabled={loading}
        className="btn btn-primary"
      >
        {loading ? 'Creating...' : 'Create Topic'}
      </button>
    </form>
  );
};

export default CreateCommunityTopic;
```

---

## Security Considerations

### 1. SSO Secret Security

- **Never commit SSO secret to git**
- Store in environment variables
- Use different secrets for development and production
- Rotate secrets periodically

### 2. API Key Security

- **Store API keys in environment variables**
- Use read-only API keys when possible
- Limit API key scopes to minimum required
- Monitor API key usage

### 3. HTTPS Only

- Always use HTTPS for SSO redirects
- Verify SSL certificates
- Use secure cookies for session management

### 4. Nonce Management

- Generate cryptographically secure nonces
- Store nonces in Redis with expiration (5 minutes)
- Verify nonce before processing SSO callback
- Delete nonce after use

### 5. User Data Validation

- Validate all user data before sending to Discourse
- Sanitize user input
- Verify user permissions before API calls

---

## Troubleshooting

### Common Issues

#### 1. SSO Signature Mismatch

**Problem:** Discourse rejects SSO with "Invalid signature" error.

**Solution:**
- Verify `DISCOURSE_SSO_SECRET` matches in both applications
- Check that signature is generated using HMAC-SHA256
- Ensure payload is base64 encoded correctly

#### 2. User Not Created in Discourse

**Problem:** User is redirected but not logged in.

**Solution:**
- Check Discourse logs: `/var/www/discourse/log/production.log`
- Verify `discourse_connect_overrides_email` is enabled
- Ensure user data (email, username) is provided correctly

#### 3. API Authentication Failed

**Problem:** API calls return 403 Forbidden.

**Solution:**
- Verify API key is correct
- Check API key has required scopes
- Ensure `Api-Username` header is set correctly

#### 4. CORS Errors

**Problem:** Browser blocks requests to Discourse API.

**Solution:**
- Configure CORS in Discourse (Admin → Settings → CORS)
- Add SIRA App domain to allowed origins
- Use backend proxy for API calls (recommended)

---

## Next Steps

1. **Implement SSO endpoints** in SIRA App backend
2. **Add Community navigation** to SIRA App frontend
3. **Create API client** for Discourse API
4. **Test authentication flow** end-to-end
5. **Add community widgets** to dashboard
6. **Implement error handling** and fallbacks
7. **Monitor integration** for issues

---

## Additional Resources

- [Discourse Connect Documentation](https://meta.discourse.org/t/discourseconnect-official-single-sign-on-for-discourse-sso/13045)
- [Discourse API Documentation](https://docs.discourse.org/)
- [Discourse API Examples](https://github.com/discourse/discourse_api)

---

**Last Updated:** December 16, 2025  
**Version:** 1.0.0

