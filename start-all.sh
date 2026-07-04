#!/bin/bash

# XiansAi Community Edition
# Starts the simplified platform: MongoDB, XiansAi Server, PostgreSQL, Temporal
# and Agent Studio. After the server is healthy, it bootstraps the platform to
# mint the first API key and injects it into Agent Studio.

set -e

# Load environment variables from .env if present
if [ -f ".env" ]; then
    echo "🧪 Loading environment variables from .env"
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

# Default Configuration (can be overridden by .env or via command line)
: "${VERSION:=latest}"
: "${COMPOSE_PROJECT_NAME:=xians-community-edition}"
: "${SERVER_EXTERNAL_PORT:=5001}"
: "${STUDIO_EXTERNAL_PORT:=3001}"

SERVER_URL="http://localhost:${SERVER_EXTERNAL_PORT}"
STUDIO_URL="http://localhost:${STUDIO_EXTERNAL_PORT}"
STUDIO_ENV_FILE="studio/.env.local"

# Set (or replace) a KEY=VALUE line in an env file, appending if absent.
set_env_var() {
    local file="$1"
    local key="$2"
    local value="$3"

    [ -f "$file" ] || return 0

    local tmp
    tmp=$(mktemp)
    while IFS= read -r line; do
        if [[ $line =~ ^${key}= ]]; then
            echo "${key}=${value}" >> "$tmp"
        else
            echo "$line" >> "$tmp"
        fi
    done < "$file"
    grep -q "^${key}=" "$tmp" || echo "${key}=${value}" >> "$tmp"
    mv "$tmp" "$file"
}

echo "🚀 Starting XiansAi Community Edition..."

# Generate secure secrets before starting services
echo "🔐 Generating secure secrets..."
if [ -f "./scripts/create-secrets.sh" ]; then
    ./scripts/create-secrets.sh
else
    echo "⚠️  create-secrets.sh not found, using existing .env.local files"
fi

# Parse command line arguments
OBSERVABILITY=false
OBSERVABILITY_AZURE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --observability)
            OBSERVABILITY=true
            shift
            ;;
        --observability-azure)
            OBSERVABILITY_AZURE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --version VERSION    Docker image version (default: latest)"
            echo "  --observability          Start Aspire Dashboard for OTel traces/metrics/logs"
            echo "  --observability-azure    Start OTEL Collector for Azure App Insights export"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                            # Start with defaults (latest)"
            echo "  $0 -v v2.0.2                  # Start with specific version"
            echo "  $0 --observability            # Start with Aspire Dashboard"
            echo "  $0 --observability-azure      # Start with OTEL Collector -> Azure App Insights"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Set final configuration based on arguments
export COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT_NAME"
export SERVER_IMAGE="${SERVER_IMAGE:-99xio/xiansai-server:$VERSION}"
export STUDIO_IMAGE="${STUDIO_IMAGE:-99xio/agent-studio:$VERSION}"

echo "📋 Configuration:"
echo "   Project: $COMPOSE_PROJECT_NAME"
echo "   Server Image: $SERVER_IMAGE"
echo "   Studio Image: $STUDIO_IMAGE"
echo ""

# ---------------------------------------------------------------------------
# Health/readiness helpers — abort startup if a critical service fails to start.
# ---------------------------------------------------------------------------
container_status() {
    docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null || echo "missing"
}

# Wait for a container's healthcheck to report "healthy"; abort on exit/timeout.
wait_for_healthy() {
    local name="$1" label="$2" retries="${3:-30}" delay="${4:-5}"
    echo "⏳ Waiting for ${label} to be healthy..."
    for _ in $(seq 1 "$retries"); do
        local status health
        status=$(container_status "$name")
        if [ "$status" = "exited" ] || [ "$status" = "dead" ] || [ "$status" = "missing" ]; then
            echo "❌ ${label} container '${name}' is ${status}. Startup aborted."
            echo "   Check logs with: docker logs ${name}"
            exit 1
        fi
        health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "missing")
        if [ "$health" = "healthy" ]; then
            echo "✅ ${label} is healthy!"
            return 0
        fi
        echo "  ${label} not ready yet (status=${status}, health=${health})..."
        sleep "$delay"
    done
    echo "❌ ${label} did not become healthy in time. Startup aborted."
    echo "   Check logs with: docker logs ${name}"
    exit 1
}

# Ensure a container is running (for services without a healthcheck, e.g. Temporal).
require_running() {
    local name="$1" label="$2"
    local status
    status=$(container_status "$name")
    if [ "$status" != "running" ]; then
        echo "❌ ${label} container '${name}' is not running (status=${status}). Startup aborted."
        echo "   Check logs with: docker logs ${name}"
        exit 1
    fi
}

# Start MongoDB and the XiansAi Server first (NOT Agent Studio yet — it needs the
# bootstrapped API key which is only available once the server is healthy).
echo "🔧 Starting MongoDB and XiansAi Server..."
docker compose -p "$COMPOSE_PROJECT_NAME" up -d mongodb xiansai-server

# Abort immediately if MongoDB is not healthy — nothing else can work without it.
wait_for_healthy xians-mongodb "MongoDB" 30 5

# Wait a moment for the network to be created
sleep 2

# Start PostgreSQL service (datastore for Temporal)
echo "🗄️  Starting PostgreSQL service..."
docker compose -p "$COMPOSE_PROJECT_NAME" -f postgresql/docker-compose.yml --env-file postgresql/.env.local up -d

# Abort if PostgreSQL does not become healthy — Temporal depends on it.
wait_for_healthy postgresql "PostgreSQL" 30 5

# Start Aspire Dashboard (optional — enabled via --observability flag)
if [ "$OBSERVABILITY" = true ]; then
    echo "📡 Starting Aspire Dashboard for observability..."
    docker compose -p "$COMPOSE_PROJECT_NAME" --profile dev up -d aspire-dashboard
    echo "✅ Aspire Dashboard started"
else
    echo "ℹ️  Observability (Aspire Dashboard) skipped — use --observability to enable"
fi

# Start OTEL Collector for Azure export (optional — enabled via --observability-azure flag)
if [ "$OBSERVABILITY_AZURE" = true ]; then
    echo "☁️  Starting OTEL Collector for Azure App Insights export..."
    docker compose -p "$COMPOSE_PROJECT_NAME" --profile observability-azure up -d otel-collector
    echo "✅ OTEL Collector started (OTLP gRPC: localhost:4317)"
else
    echo "ℹ️  Azure observability collector skipped — use --observability-azure to enable"
fi

# Start Temporal services
echo "⚡ Starting Temporal services..."
docker compose -p "$COMPOSE_PROJECT_NAME" -f temporal/docker-compose.yml --env-file temporal/.env.local up -d

# Give Temporal a moment to boot, then abort if it already exited (e.g. a
# PostgreSQL auth failure causes the auto-setup container to exit immediately).
sleep 5
require_running temporal "Temporal"

# Setup Temporal search attributes. This also waits for the Temporal server to be
# ready, so a failure here means the workflow engine is not usable — abort rather
# than continue with a broken Temporal.
echo "🔧 Setting up Temporal search attributes..."
if ! ./temporal/setup-search-attributes.sh; then
    echo "❌ Temporal did not become ready or search attributes could not be registered."
    echo "   Startup aborted. Check logs with: docker logs temporal"
    exit 1
fi

# ---------------------------------------------------------------------------
# Wait for the XiansAi Server to be healthy
# ---------------------------------------------------------------------------
echo "⏳ Waiting for XiansAi Server to be healthy at ${SERVER_URL}/health ..."
SERVER_READY=false
for attempt in $(seq 1 60); do
    if curl -sf "${SERVER_URL}/health" >/dev/null 2>&1; then
        SERVER_READY=true
        echo "✅ XiansAi Server is healthy!"
        break
    fi
    echo "  Attempt ${attempt}/60 - server not ready yet..."
    sleep 5
done

if [ "$SERVER_READY" != true ]; then
    echo "❌ XiansAi Server did not become healthy in time."
    echo "   Check logs with: docker compose logs -f xiansai-server"
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve admin credentials (used for bootstrap AND Agent Studio local login)
# ---------------------------------------------------------------------------
if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "👤  ADMIN ACCOUNT SETUP  (required)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "   These credentials are used to bootstrap the platform AND to log in"
    echo "   to Agent Studio. Enter them below when prompted."
    echo ""
fi

if [ -z "$ADMIN_EMAIL" ]; then
    read -r -p "   📧 Administrator email  ➜  " ADMIN_EMAIL
    echo ""
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "   🔑 Agent Studio login password for ${ADMIN_EMAIL:-the admin}"
    read -r -s -p "      (leave blank to auto-generate one)  ➜  " ADMIN_PASSWORD
    echo ""
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c16)
        GENERATED_PASSWORD=true
    fi
    echo ""
fi

# ---------------------------------------------------------------------------
# Bootstrap the platform and inject the API key into Agent Studio
# ---------------------------------------------------------------------------
EXISTING_APIKEY=""
if [ -f "$STUDIO_ENV_FILE" ]; then
    EXISTING_APIKEY=$(grep "^XIANS_APIKEY=" "$STUDIO_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
fi

if [ -n "$EXISTING_APIKEY" ]; then
    echo "🔑 Agent Studio already has an API key configured — skipping bootstrap."
else
    if [ -z "$ADMIN_EMAIL" ]; then
        echo "❌ No administrator email provided. Cannot bootstrap the platform."
        echo "   Set ADMIN_EMAIL in .env or re-run and provide it when prompted."
        exit 1
    fi

    echo "🔑 Bootstrapping the platform for ${ADMIN_EMAIL} ..."
    BOOTSTRAP_BODY=$(mktemp)
    HTTP_CODE=$(curl -s -o "$BOOTSTRAP_BODY" -w "%{http_code}" \
        "${SERVER_URL}/api/v1/admin/bootstrap?email=${ADMIN_EMAIL}" || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        API_KEY=$(sed -n 's/.*"apiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$BOOTSTRAP_BODY")
        if [ -n "$API_KEY" ]; then
            set_env_var "$STUDIO_ENV_FILE" "XIANS_APIKEY" "$API_KEY"
            echo ""
            echo "🎉 Platform bootstrapped successfully!"
            echo "   • Admin email:  ${ADMIN_EMAIL}"
            echo "   • API key:      ${API_KEY}"
            echo "   • Stored in:    ${STUDIO_ENV_FILE} (XIANS_APIKEY)"
            echo "   ⚠️  Save this API key now — it is shown only once."
            echo ""
        else
            echo "⚠️  Bootstrap returned 200 but no apiKey could be parsed. Response:"
            cat "$BOOTSTRAP_BODY"
        fi
    elif [ "$HTTP_CODE" = "409" ]; then
        rm -f "$BOOTSTRAP_BODY"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        echo "❌  CANNOT MINT API KEY — platform already bootstrapped (409)"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
        echo "   The platform's MongoDB data volume already exists (it was"
        echo "   bootstrapped on a previous run), but ${STUDIO_ENV_FILE}"
        echo "   has no XIANS_APIKEY. This happens when the studio env file is"
        echo "   regenerated/lost while the Mongo volume persists."
        echo ""
        echo "   The one-time bootstrap endpoint only works on an EMPTY platform,"
        echo "   and a new admin API key cannot be minted without an existing one,"
        echo "   so this key is unrecoverable from the CLI. Starting Agent Studio"
        echo "   now would leave it unable to reach the server."
        echo ""
        echo "   Fix with ONE of the following, then re-run ./start-all.sh:"
        echo ""
        echo "     • Restore the previous key into ${STUDIO_ENV_FILE}:"
        echo "         XIANS_APIKEY=<your existing admin API key>"
        echo ""
        echo "     • Mint a new key from the Agent Studio UI (keeps your data),"
        echo "       then paste it into ${STUDIO_ENV_FILE} as XIANS_APIKEY."
        echo ""
        echo "     • Reset the platform (DELETES ALL DATA) for a clean bootstrap:"
        echo "         ./reset-all.sh"
        echo ""
        echo "   Startup aborted."
        echo "═══════════════════════════════════════════════════════════════════"
        exit 1
    else
        echo "⚠️  Bootstrap request failed (HTTP ${HTTP_CODE}). Response:"
        cat "$BOOTSTRAP_BODY"
        echo ""
        echo "   You can bootstrap manually later with:"
        echo "   curl \"${SERVER_URL}/api/v1/admin/bootstrap?email=${ADMIN_EMAIL}\""
    fi
    rm -f "$BOOTSTRAP_BODY"
fi

# ---------------------------------------------------------------------------
# Configure Agent Studio local login (email/password — no OAuth required)
# ---------------------------------------------------------------------------
if [ -n "$ADMIN_EMAIL" ]; then
    set_env_var "$STUDIO_ENV_FILE" "LOCAL_AUTH_ENABLED" "true"
    set_env_var "$STUDIO_ENV_FILE" "LOCAL_AUTH_USERS" "${ADMIN_EMAIL}:${ADMIN_PASSWORD}"
    echo "🔓 Agent Studio local login configured for ${ADMIN_EMAIL}."
else
    echo "⚠️  ADMIN_EMAIL not set — skipped configuring Agent Studio local login."
fi

# ---------------------------------------------------------------------------
# Start Agent Studio (now that the API key is in place)
# ---------------------------------------------------------------------------
echo "🖥️  Starting Agent Studio..."
docker compose -p "$COMPOSE_PROJECT_NAME" up -d agent-studio

# ---------------------------------------------------------------------------
# Wait for Agent Studio to be healthy (non-fatal — the server is already up)
# ---------------------------------------------------------------------------
echo "⏳ Waiting for Agent Studio to be healthy at ${STUDIO_URL}/api/health ..."
STUDIO_READY=false
for attempt in $(seq 1 60); do
    if curl -sf "${STUDIO_URL}/api/health" >/dev/null 2>&1; then
        STUDIO_READY=true
        echo "✅ Agent Studio is healthy!"
        break
    fi
    echo "  Attempt ${attempt}/60 - Agent Studio not ready yet..."
    sleep 5
done

if [ "$STUDIO_READY" != true ]; then
    echo "⚠️  Agent Studio did not become healthy in time."
    echo "   Check logs with: docker compose logs -f agent-studio"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "🎉  XiansAi Community Edition is up and running!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "👉 NEXT STEP — Log in to Agent Studio:"
echo ""
echo "   1. Open:     ${STUDIO_URL}"
echo "   2. Sign in with your configured credentials:"
echo "        • Email:    ${ADMIN_EMAIL:-<your admin email>}"
if [ "${GENERATED_PASSWORD:-false}" = true ]; then
    echo "        • Password: ${ADMIN_PASSWORD}"
    echo "          ⚠️  This password was auto-generated — save it now, it won't be shown again."
else
    echo "        • Password: (the password you entered during setup)"
fi
echo ""
echo "   Prefer SSO instead? Configure a provider in ${STUDIO_ENV_FILE}, then run:"
echo "     docker compose up -d --force-recreate agent-studio"
echo ""
echo "-------------------------------------------------------------------"
echo "🔗 Service URLs:"
echo ""
echo "   • Agent Studio:        ${STUDIO_URL}"
echo "   • XiansAi Server:      ${SERVER_URL}"
echo "   • Server API docs:     ${SERVER_URL}/api-docs"
echo "   • Server health:       ${SERVER_URL}/health"
echo "   • Temporal Web UI:     http://localhost:8080"
if [ "$OBSERVABILITY" = true ]; then
    echo "   • Aspire Dashboard:    http://localhost:18888  (traces, metrics, logs)"
fi
if [ "$OBSERVABILITY_AZURE" = true ]; then
    echo "   • OTEL Collector:      localhost:4317          (gRPC, for Azure export)"
fi
echo ""
echo "   Internal endpoints (for advanced use / debugging):"
echo "     • Temporal gRPC API:   localhost:7233"
echo "     • MongoDB:             localhost:27017"
echo "     • Temporal PostgreSQL: localhost:5432"
echo ""
echo "-------------------------------------------------------------------"
echo "💡 Useful commands:"
echo ""
echo "   • View logs:   docker compose logs -f [service-name]"
echo "   • Stop all:    ./stop-all.sh"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
