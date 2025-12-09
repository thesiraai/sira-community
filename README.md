# SIRA Community

The online home for your community.

SIRA Community is a powerful, open-source community platform built for the SIRA AI ecosystem. It provides comprehensive community features including discussions, real-time chat, user management, moderation tools, and extensive customization options.

> **Note**: SIRA Community is a fork of [Discourse](https://github.com/discourse/discourse), an open-source community platform. We are grateful to the Discourse team and community for their excellent work.

**With SIRA Community, you can:**

* 💬 **Create discussion topics** to foster meaningful conversations.
* ⚡️ **Connect in real-time** with built-in chat.
* 🎨 **Customize your experience** with themes and plugins.
* 🤖 **Enhance your community** with AI-powered features and integrations.

## Quick Start

### Prerequisites

- Docker and Docker Compose
- SIRA Infrastructure services running
- SSL certificates from infrastructure (mTLS required)
- Domain name (for production)
- SMTP server credentials (for email)

### Local Deployment (Production-Grade)

For local deployment with **100% production-grade standards** (NO shortcuts):

```bash
# See README-LOCAL-DEPLOYMENT.md for quick start
# Or follow: docs/DEPLOYMENT/LOCAL_DEPLOYMENT_GUIDE.md
```

**Quick commands:**
```bash
# Generate secret key
ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"

# Deploy (after configuring secrets)
./docker/scripts/deploy-local.sh
```

### Production Deployment

1. **Configure environment:**
   ```bash
   cp docker/env.community.app.prod .env
   # Edit .env with your production configuration
   ```

2. **Generate secret key:**
   ```bash
   ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"
   # Add to .env as COMMUNITY_SECRET_KEY_BASE
   ```

3. **Create production config:**
   ```bash
   cp config/discourse.conf.example config/discourse.conf
   # Edit config/discourse.conf with production values
   ```

4. **Build and start:**
   ```bash
   docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod build
   docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod up -d
   ```

5. **Initialize database:**
   ```bash
   docker compose -f docker/docker-compose.sira-community.app.yml --env-file docker/env.community.app.prod exec app bundle exec rake db:migrate
   ```

See `docs/DEPLOYMENT/DOCKER_DEPLOYMENT_GUIDE.md` for detailed deployment instructions.

## Development

### Using Docker (Recommended)

```bash
# Start development environment
bin/docker/boot_dev

# Run commands in container
bin/docker/exec bundle exec rails console
bin/docker/exec bundle exec rspec
```

### Local Development

Before you get started, ensure you have the following minimum versions:
- [Ruby 3.3+](https://www.ruby-lang.org/en/downloads/)
- [PostgreSQL 13](https://www.postgresql.org/download/)
- [Redis 7](https://redis.io/download)
- [Node.js 20+](https://nodejs.org/)
- [pnpm 9+](https://pnpm.io/)

```bash
# Install dependencies
bundle install
pnpm install

# Setup database
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed_fu

# Start development server
bundle exec rails server
```

## Requirements

SIRA Community supports the **latest, stable releases** of all major browsers and platforms:

| Browsers              | Tablets      | Phones       |
| --------------------- | ------------ | ------------ |
| Apple Safari          | iPadOS       | iOS          |
| Google Chrome         | Android      | Android      |
| Microsoft Edge        |              |              |
| Mozilla Firefox       |              |              |

Additionally, we aim to support Safari on iOS 16.4+.

## Built With

- [Ruby on Rails](https://github.com/rails/rails) — Our back end API is a Rails app. It responds to requests RESTfully in JSON.
- [Ember.js](https://github.com/emberjs/ember.js) — Our front end is an Ember.js app that communicates with the Rails API.
- [PostgreSQL](https://www.postgresql.org/) — Our main data store is in Postgres.
- [Redis](https://redis.io/) — We use Redis as a cache and for transient data.

## Integration with SIRA AI

SIRA Community is designed to integrate seamlessly with the SIRA AI application. See `docs/INTEGRATION/INTEGRATION_GUIDE.md` for comprehensive integration documentation including:

- REST API integration
- Single Sign-On (SSO)
- Webhooks
- OAuth 2.0
- Embedding options

## Docker Deployment

SIRA Community is deployed using Docker for production. See `docs/DEPLOYMENT/DOCKER_DEPLOYMENT_GUIDE.md` for:

- Production deployment guide
- Configuration options
- Integration with SIRA app ecosystem
- Maintenance and troubleshooting

## Security

We take security very seriously. All code is open source and peer reviewed. Please read our [security guide](docs/SECURITY/SECURITY.md) for an overview of security measures, or if you wish to report a security issue.

## Contributing

SIRA Community is **100% free** and **open source**. We encourage and support an active, healthy community that accepts contributions from the public.

Before contributing:

1. Read [**CONTRIBUTING.MD**](CONTRIBUTING.md)
2. Always strive to collaborate with mutual respect
3. Follow our code of conduct

> **Note**: For contributions that would benefit the broader community, we encourage you to also contribute upstream to the [official Discourse repository](https://github.com/discourse/discourse).

## License

SIRA Community is licensed under the GNU General Public License Version 2.0 (or later), 
inheriting the license from Discourse.

Copyright 2014 - 2025 Civilized Discourse Construction Kit, Inc. (original Discourse code)
Copyright 2025 SIRA AI (SIRA Community modifications and additions)

Licensed under the GNU General Public License Version 2.0 (or later);
you may not use this work except in compliance with the License.
You may obtain a copy of the License in the LICENSE file, or at:

   https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Discourse logo and "Discourse Forum" ® are trademarks of Civilized Discourse Construction Kit, Inc.

## Credits and Acknowledgments

SIRA Community is based on [Discourse](https://github.com/discourse/discourse), a powerful open-source community platform created by [Civilized Discourse Construction Kit, Inc.](https://www.discourse.org/).

We extend our sincere gratitude to:

- **The Discourse Team** - For creating and maintaining an exceptional community platform
- **The Discourse Community** - For their contributions, feedback, and support over the years
- **All Discourse Contributors** - For their code contributions, bug reports, and feature suggestions

Discourse has been battle-tested for over a decade and continues to evolve. SIRA Community builds upon this solid foundation to provide integrated community functionality for the SIRA AI ecosystem.

### Original Discourse Resources

- **Official Website**: [discourse.org](https://www.discourse.org/)
- **Source Code**: [github.com/discourse/discourse](https://github.com/discourse/discourse)
- **Community Forum**: [meta.discourse.org](https://meta.discourse.org/)
- **Documentation**: [docs.discourse.org](https://docs.discourse.org/)

## Accessibility

To guide our ongoing effort to build accessible software we follow the [W3C's Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/TR/WCAG21/). If you'd like to report an accessibility issue, please open an issue on GitHub.
