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
export SERVER_IMAGE="99xio/xiansai-server:$VERSION"
export STUDIO_IMAGE="99xio/agent-studio:$VERSION"

echo "📋 Configuration:"
echo "   Project: $COMPOSE_PROJECT_NAME"
echo "   Server Image: $SERVER_IMAGE"
echo "   Studio Image: $STUDIO_IMAGE"
echo ""

# Start MongoDB and the XiansAi Server first (NOT Agent Studio yet — it needs the
# bootstrapped API key which is only available once the server is healthy).
echo "🔧 Starting MongoDB and XiansAi Server..."
docker compose -p "$COMPOSE_PROJECT_NAME" up -d mongodb xiansai-server

# Wait a moment for the network to be created
sleep 2

# Start PostgreSQL service (datastore for Temporal)
echo "🗄️  Starting PostgreSQL service..."
docker compose -p "$COMPOSE_PROJECT_NAME" -f postgresql/docker-compose.yml --env-file postgresql/.env.local up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 10

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

# Setup Temporal search attributes (asynchronous process)
echo "🔧 Setting up Temporal search attributes..."
echo "  Note: Search attributes setup may take time and run in background"
./temporal/setup-search-attributes.sh || echo "⚠️  Search attribute setup reported issues; continuing..."

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
if [ -z "$ADMIN_EMAIL" ]; then
    echo ""
    read -r -p "📧 Enter the administrator email: " ADMIN_EMAIL
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    read -r -s -p "🔑 Enter an Agent Studio login password for ${ADMIN_EMAIL:-the admin} (blank = generate): " ADMIN_PASSWORD
    echo ""
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c16)
        GENERATED_PASSWORD=true
    fi
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
        echo "⚠️  Platform already bootstrapped (409 Conflict) and no API key is stored."
        echo "   The bootstrap endpoint only works on an empty platform."
        echo "   Recover a key by signing in to Agent Studio and minting a new one,"
        echo "   or reset the platform with ./reset-all.sh (deletes all data)."
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
echo "✅ All services started successfully!"
echo ""
echo "📊 Access Points:"
echo "  • Agent Studio:           ${STUDIO_URL}"
echo "  • XiansAi Server API:     ${SERVER_URL}/api-docs"
echo "  • Temporal Web UI:        http://localhost:8080"
echo "  • Temporal gRPC API:      localhost:7233"
echo "  • MongoDB:                localhost:27017"
echo "  • Temporal PostgreSQL:    localhost:5432"
if [ "$OBSERVABILITY" = true ]; then
    echo "  • Aspire Dashboard:       http://localhost:18888  (traces, metrics, logs)"
fi
if [ "$OBSERVABILITY_AZURE" = true ]; then
    echo "  • OTEL Collector gRPC:    localhost:4317          (for Azure export)"
fi
echo ""
echo "🔐 Agent Studio sign-in (local login):"
echo "   • URL:      ${STUDIO_URL}"
echo "   • Email:    ${ADMIN_EMAIL:-<your admin email>}"
if [ "${GENERATED_PASSWORD:-false}" = true ]; then
    echo "   • Password: ${ADMIN_PASSWORD}   (auto-generated — save it now)"
else
    echo "   • Password: (the ADMIN_PASSWORD you provided)"
fi
echo "   Prefer SSO instead? Configure a provider in ${STUDIO_ENV_FILE} and restart:"
echo "     docker compose up -d --force-recreate agent-studio"
echo ""
echo "💡 Useful commands:"
echo "  • View logs:              docker compose logs -f [service-name]"
echo "  • Stop all:               ./stop-all.sh"
echo ""
