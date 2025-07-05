#!/bin/bash

# XiansAi Community Edition with Temporal Workflow Engine
# This script starts both the main application and Temporal services

set -e

echo "🚀 Starting XiansAi Community Edition with Temporal and Keycloak..."

# Parse command line arguments
VERSION="v2.1.0-beta"
DETACHED=true

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
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --version            Specify version to use .config.[version] file"
            echo "  -d, --detached           Run in detached mode"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                       # Start with latest version (.config.v2.1.0-beta)"
            echo "  $0 -v v2.0.0             # Start with version file .config.v2.0.0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Determine which environment file to use
VERSION_FILE=".config.$VERSION"


# Check if environment-specific .env file exists
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ $VERSION_FILE file not found. This file is required."
    echo "   Available environment files:"
    ls -1 .config.* 2>/dev/null | sed 's/^/     /' || echo "     No .config.* files found"
    exit 1
fi

echo "📋 version file: $VERSION_FILE"

# Load environment variables
if [ -f "$VERSION_FILE" ]; then
    echo "📁 Loading version from $VERSION_FILE"
    # Export variables one by one, skipping comments and problematic lines
    while IFS= read -r line; do
        if [[ $line =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[].*$ ]]; then
            export "$line"
        fi
    done < <(grep -v '^#' "$VERSION_FILE" | grep -v '^\s*$')
fi

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
# Set environment variables
export POSTGRESQL_VERSION=16
docker compose -p xians-community-edition -f postgresql/docker-compose.yml up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 15

# Initialize Keycloak database
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

# Start Keycloak service
echo "🔐 Starting Keycloak service..."
docker compose -p xians-community-edition -f keycloak/docker-compose.yml --env-file keycloak/.env.local up -d

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to initialize..."
sleep 20

# Start Temporal services with environment configuration
echo "⚡ Starting Temporal services..."
docker compose -p xians-community-edition -f temporal/docker-compose.yml --env-file temporal/.env.local up -d

# Setup Temporal search attributes
echo "🔧 Setting up Temporal search attributes..."
./temporal/setup-search-attributes.sh

echo ""
echo "✅ All services started successfully!"
echo ""
echo "📊 Access Points:"
echo "  • Your Application UI:    http://localhost:3001"
echo "  • Your Application API:   http://localhost:5001"
echo "  • Keycloak Admin Console: http://localhost:18080/admin"
echo "  • Temporal Web UI:        http://localhost:8080"
echo "  • Temporal gRPC API:      localhost:7233"
echo "  • MongoDB:                localhost:27017"
echo "  • Temporal PostgreSQL:    localhost:5432"
echo ""
echo "🔧 Useful commands:"
echo "  • View logs:              docker compose logs -f [service-name]"
echo "  • Stop all:               ./stop-all.sh"
echo "" 