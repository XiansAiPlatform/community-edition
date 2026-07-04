# XiansAi Platform Community Edition - Troubleshooting Guide

This guide covers common issues you might encounter when setting up and running
the XiansAi Platform Community Edition (Server, MongoDB, Temporal + PostgreSQL,
and Agent Studio), along with their solutions.

## 📋 Quick Diagnosis

### 1. Check Service Status

```bash
docker ps            # running containers
docker ps -a         # including stopped containers
docker compose ps    # health status
```

### 2. Check Service Logs

```bash
docker compose logs
docker compose logs xiansai-server
docker compose logs agent-studio
docker compose logs mongodb

# Temporal / PostgreSQL run from their own compose files
docker logs temporal
docker logs postgresql

# Follow logs in real-time
docker compose logs -f
```

### 3. Check Network Status

```bash
docker network ls
docker network inspect xians-community-edition-network
```

## 🚨 Common Issues and Solutions

### Issue 1: Container Name Conflicts

**Symptoms:**

```
Error response from daemon: Conflict. The container name "/xians-mongodb" is already in use
```

**Solution:**

```bash
# Cleanly stop everything first
./stop-all.sh

# If names are still held, remove the containers
docker rm -f xians-mongodb xians-server xians-agent-studio temporal temporal-ui postgresql

# Restart
./start-all.sh
```

**Prevention:** Always use `./stop-all.sh` before starting again, or
`./reset-all.sh` for a clean slate.

### Issue 2: Port Already in Use

**Symptoms:**

```
Error starting userland proxy: listen tcp 0.0.0.0:5001: bind: address already in use
```

**Solution:**

```bash
# Find what is using the port
lsof -i :3001   # Agent Studio
lsof -i :5001   # XiansAi Server
lsof -i :8080   # Temporal UI
lsof -i :27017  # MongoDB
lsof -i :5432   # PostgreSQL

# Stop the conflicting process, or change the host port mapping in the
# corresponding docker-compose.yml
```

### Issue 3: Missing `.env` / Environment Variable Not Set

**Symptoms:**

```
❌ ERROR: Root .env file not found
The "POSTGRESQL_VERSION" variable is not set. Defaulting to a blank string.
```

**Solution:**

```bash
# Ensure the root .env exists and has the required values
cp .env.example .env
# Set ADMIN_EMAIL and ADMIN_PASSWORD, then:
./start-all.sh
```

`start-all.sh` generates the per-service `.env.local` files. If a service
`.env.local` is missing or corrupt, delete it and re-run:

```bash
rm postgresql/.env.local temporal/.env.local
./start-all.sh
```

### Issue 4: Server Never Becomes Healthy

**Symptoms:** `start-all.sh` reports "XiansAi Server did not become healthy".

**Diagnosis:**

```bash
docker compose logs xiansai-server
docker inspect xians-server | grep -A 10 "Health"
```

**Common causes:**

- MongoDB not reachable or not a replica set - check `MongoDB__ConnectionString`
  in `server/.env.local` (must include `replicaSet=rs0`).
- A required secret is missing - re-generate by removing `server/.env.local`
  and re-running `./start-all.sh`.

### Issue 5: Bootstrap Fails or Returns 409

**Symptoms:** `start-all.sh` prints a bootstrap warning.

- **`409 Conflict`**: The platform already has users. Bootstrap only works on an
  empty platform. Sign in to Agent Studio and mint a new API key from the UI, or
  reset with `./reset-all.sh` (deletes all data).
- **Other HTTP error**: The server may not be fully ready. Re-run the call
  manually once healthy:

  ```bash
  curl "http://localhost:5001/api/v1/admin/bootstrap?email=admin@your-domain.com"
  ```

  Then paste the returned `apiKey` into `studio/.env.local` as `XIANS_APIKEY`
  and restart Agent Studio:

  ```bash
  docker compose up -d --force-recreate agent-studio
  ```

### Issue 6: Cannot Sign in to Agent Studio

**Symptoms:** No sign-in options, redirect loop, or "first user isn't admin".

**Solutions:**

- **Local login not showing / rejected**: The default local login needs
  `LOCAL_AUTH_ENABLED=true` and `LOCAL_AUTH_USERS=<email>:<password>` in
  `studio/.env.local`. `start-all.sh` sets these from `ADMIN_EMAIL` /
  `ADMIN_PASSWORD`. Verify them and restart Studio:

  ```bash
  grep -E "LOCAL_AUTH_" studio/.env.local
  docker compose up -d --force-recreate agent-studio
  ```

  Log in with the exact email and password in `LOCAL_AUTH_USERS`.
- **Using OAuth instead — no providers configured**: Set Google/Azure/Visma
  credentials in `studio/.env.local` and restart Studio (command above).
- **Redirect/callback error (OAuth)**: Register the exact redirect URI with your
  provider: `http://localhost:3001/api/auth/callback/<provider>`. Confirm
  `NEXTAUTH_URL=http://localhost:3001` in `studio/.env.local`.
- **First user isn't admin**: The signed-in identity's email must match
  `ADMIN_EMAIL` used at bootstrap.

### Issue 7: Memory Issues

**Symptoms:** Services fail to start, Docker crashes, "out of memory".

**Solution:**

1. Increase Docker Desktop memory to 8GB+ (Settings → Resources → Advanced).
2. Close other applications.
3. Restart Docker Desktop.

```bash
# macOS
top -l 1 | grep PhysMem
# Linux
free -h
```

### Issue 8: LLM Errors

**Symptoms:** Agent responses fail with authentication or provider errors.

**Solution:** LLM provider credentials are managed in-app. Sign in to Agent
Studio and configure the LLM provider and API key in the platform settings.
No server environment variable is required for this.

### Issue 9: Image Pull Failures

**Symptoms:**

```
Error response from daemon: manifest for 99xio/agent-studio:latest not found
```

**Solution:**

```bash
docker pull 99xio/xiansai-server:latest
docker pull 99xio/agent-studio:latest
# or
./pull-latest.sh
```

### Issue 10: MongoDB Start Errors on Windows

**Solution:** Ensure `mongodb/mongo-startup.sh` uses LF (not CRLF) line endings.

### Issue 11: Temporal Search Attributes Not Registered

**Symptoms:** Workflow search/filtering by `tenantId`/`agent` doesn't work.

**Solution:**

```bash
# Re-run the setup (Temporal must be running)
./temporal/setup-search-attributes.sh

# Verify
./temporal/verify-search-attributes.sh
```

## 🔧 Advanced Troubleshooting

### Inter-service Connectivity

```bash
# From the server to MongoDB (service name on the shared network)
docker exec xians-server ping mongodb

docker network inspect xians-community-edition-network
```

### Inspect Environment

```bash
docker exec xians-server env
docker exec postgresql env | grep POSTGRES
```

### Resource Usage

```bash
docker stats
docker system df
docker system prune -a   # careful: removes unused images/containers
```

## 🔄 Recovery Procedures

### Complete Reset

```bash
./stop-all.sh
./reset-all.sh -f
./start-all.sh
```

### Partial Reset (single service)

```bash
docker compose stop xiansai-server
docker compose rm -f xiansai-server
docker compose up -d xiansai-server
```

## 🆘 Getting Help

Before asking for help, collect:

```bash
docker --version
docker compose version
uname -a
docker ps -a
docker compose logs
```

- **GitHub Issues**: bug reports and feature requests
- **GitHub Discussions**: questions and community help

When filing a bug, include the exact error message, steps to reproduce, system
information, and relevant logs.
