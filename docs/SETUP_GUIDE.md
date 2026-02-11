# XiansAi Platform Community Edition - Complete Setup Guide

This comprehensive guide will help you set up the XiansAi Platform Community Edition on your local machine. This guide is designed for tech-savvy users who want to get the platform running independently without external help.

## 📋 Table of Contents

- [System Requirements](#system-requirements)
- [Prerequisites Installation](#prerequisites-installation)
- [Project Setup](#project-setup)
- [Configuration](#configuration)
- [Starting the Platform](#starting-the-platform)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
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
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start Docker service
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

# Windows
# Download from https://git-scm.com/download/win
```

### 3. Verify Installation
```bash
# Check Docker
docker --version
docker compose version

# Check Git
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
# - keycloak/
# - postgresql/
# - temporal/
# - server/
# - ui/
```

### 3. Check Available Environment Files
```bash
# Check for example environment files
find . -name ".env.example" -type f

# Check for local environment files (already configured)
find . -name ".env.local" -type f

# You should see:
# Example files:
# - server/.env.example
# - ui/.env.example
# - postgresql/.env.example
# - keycloak/.env.example
# - temporal/.env.example
#
# Local files (already configured):
# - server/.env.local
# - ui/.env.local
# - postgresql/.env.local
# - keycloak/.env.local
# - temporal/.env.local
```
Manually create a .env file in the root of the community-edition cloned repo and then run the  ./start-all.sh command it will create the following files .
# - server/.env.local
# - ui/.env.local
# - postgresql/.env.local
# - keycloak/.env.local
# - temporal/.env.local


**Note**: The `.env.local` files are already included in the repository and contain the community edition configuration. You only need to set your OpenAI API key in `server/.env.local`.

## ⚙️ Configuration

### 1. Environment Variables Setup

**Good News**: The project is already configured with community edition settings! The `.env.local` files contain all the necessary configuration for the community edition to run.

**Project Pattern:**
1. **`.env.example` files** - Show the pattern/structure of environment variables
2. **`.env.local` files** - Contain the actual values for community edition to run (already included)
3. **Scripts use `.env.local` files** - The startup scripts reference `.env.local` files

**Available Files:**
- **Example files** (for reference): `server/.env.example`, `ui/.env.example`, etc.
- **Local files** (already configured): `server/.env.local`, `ui/.env.local`, etc.

**Only Required Action**: Set your OpenAI API key in `server/.env.local`

#### Environment Files Status ✅

**All environment files are already configured!** The project includes `.env.local` files with community edition settings:

- ✅ `postgresql/.env.local` - PostgreSQL configuration (already set)
- ✅ `keycloak/.env.local` - Keycloak configuration (already set)
- ✅ `temporal/.env.local` - Temporal configuration (already set)
- ✅ `ui/.env.local` - UI configuration (already set)
- ✅ `server/.env.local` - Server configuration (needs API key)

**No manual setup required** - the community edition is pre-configured!

### 2. API Key Configuration

**Important**: You need to set up your OpenAI API key for the platform to work. The `server/.env.local` file already exists but needs your API key:

```bash
# Navigate to server directory
cd server

# Edit the existing .env.local file to add your API key
# Find the line: Llm__ApiKey=
# Replace it with: Llm__ApiKey=your-actual-api-key-here
```

**Get an OpenAI API Key:**
1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Add your API key to the `Llm__ApiKey=` line in `server/.env.local`

**Quick Setup:**
```bash
# Set your API key (replace with your actual key)
cd server
sed -i '' 's/Llm__ApiKey=/Llm__ApiKey=your-actual-api-key-here/' .env.local
```

### 3. Network Configuration

The project uses a shared Docker network. The network will be created automatically when you start services.

## 🏃‍♂️ Starting the Platform

### 1. Quick Start (Recommended)
```bash
# From the project root
./start-all.sh
```

This script will:
- Create the Docker network
- Start all services (MongoDB, PostgreSQL, Keycloak, Temporal, XiansAi Server, XiansAi UI)
- Wait for services to be healthy
- Display access URLs



### 2. Advanced Start Options
```bash
# Start with specific version
./start-all.sh -v v2.1.0

# Start with specific environment
./start-all.sh -e staging

# Start with both version and environment
./start-all.sh -v v2.1.0 -e production

# Show all options
./start-all.sh --help
```

### 3. Individual Service Start (For Development)
```bash
# Start PostgreSQL first
cd postgresql
docker compose up -d

# Start Keycloak
cd ../keycloak
docker-compose --env-file .env.local up -d

# Start Temporal
cd ../temporal
docker compose up -d

# Start main services
cd ..
docker compose up -d
```

**Note**: The services use `.env.local` files which are already configured in the community edition.

## 🌐 Accessing Services

Once all services are running, you can access them at:

### Primary Services

- **XiansAi UI**: http://localhost:3001
- **XiansAi Server API**: http://localhost:5001/api-docs
- **Keycloak Admin Console**: http://localhost:18080/admin
- **Temporal Web UI**: http://localhost:8080

### Database Services

- **MongoDB**: localhost:27017
- **PostgreSQL**: localhost:5432

### Default Credentials

- **Keycloak Admin**: `admin` / `admin`
- **PostgreSQL**: `temporal` / `temporal`
- **MongoDB**: No authentication required (development setup)

## 🔍 Troubleshooting

### Common Issues and Solutions



#### 1. Container Name Conflicts

**Error**: `Error response from daemon: Conflict. The container name "/xians-mongodb" is already in use`

**Solution**:

```bash
# Stop and remove conflicting containers
docker stop xians-mongodb xians-server xians-ui keycloak postgresql
docker rm xians-mongodb xians-server xians-ui keycloak postgresql

# Then restart
./start-all.sh
```

#### 2. Port Already in Use

**Error**: `Error starting userland proxy: listen tcp 0.0.0.0:27017: bind: address already in use`

**Solution**:

```bash
# Check what's using the port
lsof -i :27017

# Stop the conflicting service or change the port in docker-compose.yml
```

#### 3. Environment Variable Not Set

**Error**: `The "POSTGRESQL_VERSION" variable is not set. Defaulting to a blank string.`

**Solution**:

```bash
# Check if .env.local file exists
ls -la postgresql/.env.local

# If missing, create it from example
cd postgresql && cp .env.example .env.local && cd ..
./start-all.sh
```

#### 4. Docker Network Issues

**Error**: `network with name xians-community-edition-network exists but was not created`

**Solution**:

```bash
# This is just a warning, not an error. The network exists and will be used.
# If you want to clean up networks:
docker network prune
```

#### 5. Service Health Check Failures

**Error**: Services show as unhealthy

**Solution**:

```bash
# Check service logs
docker compose logs xians-server
docker compose logs xians-ui
docker compose logs keycloak

# Restart specific service
docker compose restart xians-server
```

#### 6. Memory Issues

**Error**: Services fail to start due to insufficient memory

**Solution**:

- Increase Docker Desktop memory limit (8GB+ recommended)
- Close other applications to free up RAM
- Restart Docker Desktop

#### 7. API Key Issues

**Error**: Server fails to start or returns authentication errors

**Solution**:

```bash
# Verify API key is set
cd server
cat .env.local

# If missing, create it:
echo "Llm__ApiKey=your-actual-api-key" > .env.local
```

#### 8. Error when starting MongoDB server in windows 


**Solution**: error in MongoDB can be resolved by changing the line sequence to LF from CRLF in mongo-startup.sh File 


### Health Check Commands

#### MongoDB Health Check

```bash
# Test MongoDB connection
mongosh --eval "db.adminCommand('ping')" --quiet

# Run health check script
mongosh --eval "$(cat mongodb/mongo-healthcheck.js)" --quiet
```

#### PostgreSQL Health Check

```bash
# Test PostgreSQL connection
docker exec postgresql pg_isready -U temporal
```

#### Keycloak Health Check

```bash
# Check Keycloak health
curl http://localhost:18080/health/ready
```

#### Elasticsearch Health Check

```bash
# Check Elasticsearch health
curl http://localhost:9200/_cluster/health

# Check Temporal visibility index
curl http://localhost:9200/temporal_visibility_v1_dev/_search?size=0

# Verify Elasticsearch is accessible from Temporal
docker exec temporal curl -f http://elasticsearch:9200/_cluster/health
```

### Log Monitoring

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f xians-server
docker compose logs -f keycloak
docker compose logs -f postgresql
```

## 🛠️ Development Workflow

### 1. Starting Development

```bash
# Start all services
./start-all.sh

# Monitor logs
docker compose logs -f
```

### 2. Stopping Services

```bash
# Stop all services
./stop-all.sh

# Or stop individual services
docker compose down
```

### 3. Resetting Everything

```bash
# Complete reset (removes all data)
./reset-all.sh

# Force reset without confirmation
./reset-all.sh -f
```

### 4. Updating Services

```bash
# Pull latest images
docker compose pull

# Restart services
./stop-all.sh
./start-all.sh
```

## 📚 Service-Specific Guides

### MongoDB Service

- **Purpose**: Primary database for XiansAi platform
- **Port**: 27017
- **Health Check**: `mongodb/mongo-healthcheck.js`
- **No authentication required** (development setup)

### PostgreSQL Service

- **Purpose**: Database for Keycloak and Temporal
- **Port**: 5432
- **Credentials**: temporal/temporal
- **Environment**: Requires `POSTGRESQL_VERSION=16` in `.env.local`

### Keycloak Service

- **Purpose**: Identity and Access Management
- **Port**: 18080
- **Admin**: admin/admin
- **Dependencies**: Requires PostgreSQL running first

### Temporal Service

- **Purpose**: Workflow orchestration
- **Port**: 8080 (UI), 7233 (gRPC)
- **Dependencies**: Requires PostgreSQL and Elasticsearch running first
- **Visibility**: Uses Elasticsearch for advanced workflow search and filtering

### Elasticsearch Service

- **Purpose**: Temporal visibility store for advanced search capabilities
- **Port**: 9200 (HTTP API)
- **Index**: temporal_visibility_v1_dev
- **Configuration**: Single-node cluster optimized for development

### XiansAi Server

- **Purpose**: Backend API service
- **Port**: 5001
- **Dependencies**: Requires MongoDB and Keycloak
- **Configuration**: Requires OpenAI API key in `server/.env.local`

### XiansAi UI

- **Purpose**: Frontend web application
- **Port**: 3001
- **Dependencies**: Requires XiansAi Server running

## 🔄 Maintenance

### Regular Tasks

1. **Update Docker images**: `docker compose pull`
2. **Clean up unused resources**: `docker system prune`
3. **Monitor disk usage**: `docker system df`
4. **Backup data** (if needed): Export volumes before major updates

### Backup and Restore

```bash
# Backup PostgreSQL data
docker exec postgresql pg_dump -U temporal keycloak > backup.sql

# Backup MongoDB data
docker exec xians-mongodb mongodump --out /backup

# Restore PostgreSQL
docker exec -i postgresql psql -U temporal keycloak < backup.sql
```

## 📞 Getting Help

If you encounter issues not covered in this guide:

1. **Check the logs**: `docker compose logs -f [service-name]`
2. **Search existing issues**: GitHub Issues
3. **Create a new issue**: Include logs, error messages, and system details
4. **Join discussions**: GitHub Discussions

## 🎯 Next Steps

After successful setup:
1. **Explore the UI**: http://localhost:3001
2. **Check API documentation**: http://localhost:5001/api-docs
3. **Configure Keycloak**: http://localhost:18080/admin
4. **Monitor workflows**: http://localhost:8080
5. **Read the contributing guide**: [CONTRIBUTING.md](../CONTRIBUTING.md)

---

**Note**: This setup is for development and testing only. For production deployment, refer to the production deployment guide. 