# XiansAi Platform Community Edition - Complete Setup Guide

This guide walks you through setting up the XiansAi Platform Community Edition on your local machine. The Community Edition deploys a minimal, self-contained stack:

- **XiansAi Server** - core platform API and orchestration engine
- **MongoDB** (replica set) - primary data store
- **Temporal** (+ its own PostgreSQL) - workflow orchestration engine
- **Agent Studio** - the web console for the platform

## 📋 Table of Contents

- [System Requirements](#system-requirements)
- [Prerequisites Installation](#prerequisites-installation)
- [Project Setup](#project-setup)
- [Configuration](#configuration)
- [Starting the Platform](#starting-the-platform)
- [Bootstrap and Sign-in](#bootstrap-and-sign-in)
- [Accessing Services](#accessing-services)
- [Development Workflow](#development-workflow)
- [Service-Specific Guides](#service-specific-guides)

## 🖥️ System Requirements

### Minimum Requirements

- **Operating System**: macOS 10.15+, Ubuntu 20.04+, or Windows 10/11
- **RAM**: 8GB (4GB minimum, but 8GB recommended)
- **Storage**: 10GB free space
- **CPU**: 2 cores minimum, 4 cores recommended
- **Internet**: Stable connection for downloading Docker images

### Recommended Requirements

- **RAM**: 16GB
- **Storage**: 20GB free space
- **CPU**: 4+ cores
- **Docker Desktop**: Latest stable version

## 🔧 Prerequisites Installation

### 1. Docker and Docker Compose

#### macOS

```bash
# Install Docker Desktop (includes Docker Compose)
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop
```

#### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker
```

#### Windows

1. Download Docker Desktop from https://www.docker.com/products/docker-desktop
2. Install and restart your computer
3. Start Docker Desktop

### 2. Git

```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get install git

# Windows: download from https://git-scm.com/download/win
```

### 3. Verify Installation

```bash
docker --version
docker compose version
git --version
```

## 🚀 Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/XiansAiPlatform/community-edition.git
cd community-edition
```

### 2. Verify Project Structure

```bash
ls -la
# You should see:
# - start-all.sh
# - stop-all.sh
# - reset-all.sh
# - docker-compose.yml
# - postgresql/
# - temporal/
# - server/
# - studio/
# - mongodb/
```

### 3. Host File Entry (recommended)

MongoDB is referenced by the hostname `mongodb` inside the connection string.
Add a host entry so tools on your machine can resolve it too:

```bash
grep -q "mongodb" /etc/hosts || echo "127.0.0.1   mongodb" | sudo tee -a /etc/hosts
```

On Windows, ensure `C:\Windows\System32\drivers\etc\hosts` contains
`127.0.0.1   host.docker.internal` (edit as Administrator).

## ⚙️ Configuration

All configuration starts from the root `.env` file. The `start-all.sh` script
reads it and generates per-service `.env.local` files (via
`scripts/create-secrets.sh`) with randomly generated secrets.

### 1. Create the root `.env`

```bash
cp .env.example .env
```

Edit `.env` and set:

| Variable | Required | Description |
|----------|----------|-------------|
| `ADMIN_EMAIL` | Yes* | Email of the first administrator. Bootstraps the platform, becomes your `SysAdmin` identity, and is your Agent Studio login username. If empty, `start-all.sh` prompts for it. |
| `ADMIN_PASSWORD` | Yes* | Password for the Agent Studio local login. If empty, `start-all.sh` prompts for one (or generates and prints it). |
| `OPENAI_API_KEY` | Yes | OpenAI API key used by the server. |
| OAuth provider | Optional | Google, Microsoft/Azure AD, or Visma Connect credentials — only if you prefer SSO over the local login. |

Example:

```bash
ADMIN_EMAIL=admin@your-domain.com
ADMIN_PASSWORD=choose-a-strong-password
OPENAI_API_KEY=sk-your-openai-api-key-here
```

Get an OpenAI API key at https://platform.openai.com/api-keys.

### 2. Generated files

On first `./start-all.sh`, secrets are generated into:

- `server/.env.local` - MongoDB connection string, encryption keys, certificate, OpenAI key, CORS
- `mongodb/.env.local` - MongoDB users/passwords
- `postgresql/.env.local` and `temporal/.env.local` - shared PostgreSQL credentials
- `studio/.env.local` - `NEXTAUTH_SECRET`, local login (`LOCAL_AUTH_ENABLED`, `LOCAL_AUTH_USERS`), any OAuth credentials, and `XIANS_APIKEY` (filled at bootstrap)

These files are not committed to git. Existing `.env.local` files are preserved
and never overwritten.

## 🏃 Starting the Platform

### Quick Start

```bash
./start-all.sh
```

This will:

1. Generate secrets (first run only).
2. Start MongoDB and the XiansAi Server.
3. Start PostgreSQL and Temporal, then register Temporal search attributes.
4. Wait for the server to become healthy.
5. Bootstrap the platform and inject the API key into `studio/.env.local`.
6. Start Agent Studio and print access URLs.

### Options

```bash
# Specific image version
./start-all.sh -v v2.1.0

# With Aspire Dashboard (local OTel traces/metrics/logs)
./start-all.sh --observability

# With OTEL Collector exporting to Azure App Insights
./start-all.sh --observability-azure

# Show all options
./start-all.sh --help
```

## 🔑 Bootstrap and Sign-in

### Bootstrap (automatic)

A fresh server has no users. On first start, `start-all.sh` calls:

```bash
curl "http://localhost:5001/api/v1/admin/bootstrap?email=$ADMIN_EMAIL"
```

This creates the first `SysAdmin`, ensures a tenant exists, and returns a
one-time **API key**. The script prints it and stores it in
`studio/.env.local` as `XIANS_APIKEY`. **Save the key** - it is shown only once.

If the platform is already bootstrapped, the endpoint returns `409 Conflict`.
To recover a key later, sign in to Agent Studio and mint a new one, or run
`./reset-all.sh` to start over (this deletes all data).

### Sign-in (local login, default)

By default, Agent Studio uses its built-in email/password login - no external
provider required. `start-all.sh` enables it and configures a user from your
bootstrap admin by writing to `studio/.env.local`:

```bash
LOCAL_AUTH_ENABLED=true
LOCAL_AUTH_USERS=<ADMIN_EMAIL>:<ADMIN_PASSWORD>
```

Sign in at http://localhost:3000 with `ADMIN_EMAIL` / `ADMIN_PASSWORD`. This
resolves to the bootstrapped `SysAdmin` because the emails match.

> Local login is for local/evaluation use only. Never enable it on a publicly
> reachable deployment.

### Sign-in via OAuth (optional)

If you prefer SSO, configure one provider instead of (or in addition to) local login:

1. Set the provider credentials in `.env` before your first start (they are
   copied into `studio/.env.local`), or edit `studio/.env.local` afterwards and
   restart Agent Studio:

   ```bash
   docker compose up -d --force-recreate agent-studio
   ```

2. Register the redirect URI with your provider:
   `http://localhost:3000/api/auth/callback/<provider>`
   (e.g. `.../callback/google`, `.../callback/azure-ad`, `.../callback/visma-connect`).
3. Sign in with an identity whose email equals `ADMIN_EMAIL`, otherwise your
   account will not resolve to the bootstrapped `SysAdmin`.

## 🌐 Accessing Services

### Primary Services

- **Agent Studio**: http://localhost:3000
- **XiansAi Server API**: http://localhost:5001/api-docs
- **Temporal Web UI**: http://localhost:8080 (unauthenticated, local only)

### Database Services

- **MongoDB**: localhost:27017
- **PostgreSQL** (Temporal): localhost:5432

### Verify Services

```bash
docker compose ps

curl -s http://localhost:3000/api/health > /dev/null && echo "✅ Agent Studio is running"
curl -s http://localhost:8080 > /dev/null && echo "✅ Temporal UI is running"
curl -s http://localhost:5001/health > /dev/null && echo "✅ XiansAi Server is running"
```

## 🛠️ Development Workflow

```bash
# Start all services
./start-all.sh

# Monitor logs
docker compose logs -f
docker compose logs -f xiansai-server
docker compose logs -f agent-studio

# Stop all services
./stop-all.sh

# Complete reset (removes all data)
./reset-all.sh
./reset-all.sh -f      # skip confirmation

# Update to the latest images
./pull-latest.sh
./stop-all.sh && ./start-all.sh
```

## 📚 Service-Specific Guides

### MongoDB Service

- **Purpose**: Primary database for the XiansAi platform (runs as a replica set)
- **Port**: 27017
- **Health Check**: `mongodb/mongo-healthcheck.js`
- **Credentials**: Randomly generated into `mongodb/.env.local`; the server's
  connection string is written into `server/.env.local`.

### PostgreSQL Service

- **Purpose**: Datastore for Temporal
- **Port**: 5432
- **Credentials**: Randomly generated into `postgresql/.env.local` /
  `temporal/.env.local`.

### Temporal Service

- **Purpose**: Workflow orchestration
- **Ports**: 8080 (UI), 7233 (gRPC)
- **Visibility**: PostgreSQL-based (SQL) - no Elasticsearch required
- **Search attributes**: Registered by `temporal/setup-search-attributes.sh`
  (`tenantId`, `userId`, `agent`, `idPostfix`)

### XiansAi Server

- **Purpose**: Backend API service
- **Port**: 5001
- **Auth mode**: Admin-API-key-only (no OIDC provider). The bootstrapped API key
  authorizes Admin APIs; agents authenticate with certificates.
- **Dependencies**: MongoDB (and Temporal for workflows)

### Agent Studio

- **Purpose**: Web console for the platform
- **Port**: 3000
- **Dependencies**: A healthy XiansAi Server and a valid `XIANS_APIKEY`
- **Sign-in**: Built-in local email/password login by default (`ADMIN_EMAIL` /
  `ADMIN_PASSWORD`); OAuth providers optional (see above)

## 🎯 Next Steps

After successful setup:

1. Sign in to Agent Studio: http://localhost:3000
2. Explore the API documentation: http://localhost:5001/api-docs
3. Monitor workflows in Temporal: http://localhost:8080
4. Read the contributing guide: [CONTRIBUTING.md](../CONTRIBUTING.md)

---

**Note**: This setup is intended for development and evaluation. For production
deployment, refer to the platform's production documentation.
