#!/bin/bash

# XiansAi Community Edition with Temporal Workflow Engine
# This script starts both the main application and Temporal services

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

echo "🚀 Starting XiansAi Community Edition with Temporal and Keycloak..."

# Generate secure secrets before starting services
echo "🔐 Generating secure secrets..."
if [ -f "./scripts/create-secrets.sh" ]; then
    ./scripts/create-secrets.sh
else
    echo "⚠️  create-secrets.sh not found, using existing .env.local files"
fi

# Parse command line arguments
DETACHED=true
SKIP_KEYCLOAK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--detached)
            DETACHED=true
            shift
            ;;
        --skip-keycloak)
            SKIP_KEYCLOAK=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --version VERSION    Docker image version (default: latest)"
            echo "  -d, --detached           Run in detached mode (default)"
            echo "  --skip-keycloak          Skip Keycloak service deployment"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                       # Start with defaults (latest)"
            echo "  $0 -v v2.0.2             # Start with specific version"
            echo "  $0 --skip-keycloak       # Start without Keycloak service"
            echo "  $0 -v v2.0.2 --skip-keycloak # Start with specific version, no Keycloak"
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
export SERVER_IMAGE="99xio/xiansai-server:local"
export UI_IMAGE="99xio/xiansai-ui:$VERSION"

echo "📋 Configuration:"
echo "   Project: $COMPOSE_PROJECT_NAME"
echo "   Server Image: $SERVER_IMAGE"
echo "   UI Image: $UI_IMAGE"
echo ""

# Start the main application services first
echo "🔧 Starting main application services..."
if [ "$DETACHED" = true ]; then
    docker compose up -d
else
    docker compose up
fi

# Wait a moment for the network to be created
sleep 2

# Start PostgreSQL service first
echo "🗄️  Starting PostgreSQL service..."
docker compose -p $COMPOSE_PROJECT_NAME -f postgresql/docker-compose.yml --env-file postgresql/.env.local up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 15

# Initialize Keycloak database (if not skipping Keycloak)
if [ "$SKIP_KEYCLOAK" = false ]; then
    echo "🔧 Initializing Keycloak database..."
    if [ -f "keycloak/init-keycloak-db.sh" ]; then
        if ./keycloak/init-keycloak-db.sh; then
            echo "✅ Keycloak database initialization completed successfully"
        else
            echo "⚠️  Keycloak database initialization encountered issues, but continuing..."
            echo "   (Keycloak may still work if database already exists)"
        fi
    else
        echo "⚠️  keycloak/init-keycloak-db.sh not found, skipping manual initialization"
        echo "   (Relying on PostgreSQL init script)"
    fi
else
    echo "⏭️  Skipping Keycloak database initialization (--skip-keycloak enabled)"
fi

# Start Keycloak service (if not skipping Keycloak)
if [ "$SKIP_KEYCLOAK" = false ]; then
    echo "🔐 Starting Keycloak service..."
    docker compose -p $COMPOSE_PROJECT_NAME -f keycloak/docker-compose.yml --env-file keycloak/.env.local up -d

    # Wait for Keycloak to be ready
    echo "⏳ Waiting for Keycloak to initialize..."
    sleep 20
else
    echo "⏭️  Skipping Keycloak service startup (--skip-keycloak enabled)"
fi

# Start Temporal services with environment configuration
echo "⚡ Starting Temporal services..."
docker compose -p $COMPOSE_PROJECT_NAME -f temporal/docker-compose.yml --env-file temporal/.env.local up -d

# Wait for Elasticsearch to be ready
echo "⏳ Waiting for Elasticsearch to be ready..."
sleep 30

# Setup Elasticsearch for Temporal visibility
echo "🔍 Setting up Elasticsearch for Temporal visibility..."
./temporal/setup-elasticsearch.sh

# Setup Temporal search attributes (asynchronous process)
echo "🔧 Setting up Temporal search attributes..."
echo "  Note: Search attributes setup may take time and run in background"
./temporal/setup-search-attributes.sh

echo ""
echo "✅ All services started successfully!"
echo ""
echo "📊 Access Points:"
echo "  • XiansAi UI:    http://localhost:3001"
echo "  • XiansAi Server API:   http://localhost:5001/api-docs"
if [ "$SKIP_KEYCLOAK" = false ]; then
    echo "  • Keycloak Admin Console: http://localhost:18080/admin"
fi
echo "  • Temporal Web UI:        http://localhost:8080"
echo "  • Temporal gRPC API:      localhost:7233"
echo "  • Elasticsearch:          http://localhost:9200"
echo "  • MongoDB:                localhost:27017"
echo "  • Temporal PostgreSQL:    localhost:5432"
echo ""
echo "�� Useful commands:"
echo "  • View logs:              docker compose logs -f [service-name]"
echo "  • Stop all:               ./stop-all.sh"
echo "" 