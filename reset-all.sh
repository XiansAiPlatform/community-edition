#!/bin/bash

# XiansAi Platform Reset Script
# This script completely resets the XiansAi platform (DESTRUCTIVE)

set -e

# Project configuration
COMPOSE_PROJECT_NAME="xians-community-edition"

echo "💥 XiansAi Platform Reset Script"
echo "================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Parse command line arguments
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -f, --force              Skip confirmation prompts"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "⚠️  WARNING: This script will:"
            echo "     - Stop all XiansAi services"
            echo "     - Remove all volumes (DELETE ALL DATA)"
            echo "     - Clean up Docker system (dangling images/networks)"
            echo ""
            echo "This script resets all XiansAi services regardless of version or environment."
            echo ""
            echo "Examples:"
            echo "  $0                       # Reset with confirmation prompt"
            echo "  $0 -f                    # Reset without prompts"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

PROJECT_NAME="$COMPOSE_PROJECT_NAME"

echo "📋 Project: $COMPOSE_PROJECT_NAME"
echo ""

# Confirmation prompt (unless forced)
if [ "$FORCE" = false ]; then
    echo ""
    echo "⚠️  WARNING: This will completely reset the XiansAi platform!"
    echo "    This action will:"
    echo "    • Stop all running services"
    echo "    • DELETE ALL DATA (volumes will be removed)"
    echo "    • Clean up Docker system (dangling images/networks)"
    echo ""
    read -p "Are you sure you want to continue? Type 'RESET' to confirm: " confirmation
    
    if [ "$confirmation" != "RESET" ]; then
        echo "❌ Reset cancelled."
        exit 1
    fi
fi

echo ""
echo "💥 Starting complete reset..."

# Step 1: Stop and remove containers and volumes
echo "🛑 Stopping services and removing volumes..."

# Stop main application services
echo "   • Stopping main application services..."
docker compose -p $PROJECT_NAME down -v --remove-orphans

# Stop Temporal services (if running)
echo "   • Stopping Temporal services..."
docker compose -p $PROJECT_NAME -f temporal/docker-compose.yml down -v --remove-orphans 2>/dev/null || echo "     (Temporal services not running)"

# Stop PostgreSQL services (if running)
echo "   • Stopping PostgreSQL services..."
docker compose -p $PROJECT_NAME -f postgresql/docker-compose.yml down -v --remove-orphans 2>/dev/null || echo "     (PostgreSQL services not running)"

# Step 2: Clean up Docker system
echo "🧹 Cleaning up Docker system..."
docker system prune -f

# Step 3: Remove any remaining volumes
echo "🗑️  Removing any remaining XiansAi volumes..."

# Show all volumes for debugging
echo "   • Current volumes:"
docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.CreatedAt}}" | head -20

# Get all volumes and filter for XiansAi-related ones
echo "   • Scanning for XiansAi-related volumes..."
docker volume ls --format "{{.Name}}" | grep -E "(xians|xiansai|community-edition|temporal|postgres)" | while read -r volume; do
    if [ -n "$volume" ]; then
        echo "   • Removing volume: $volume"
        docker volume rm "$volume" 2>/dev/null || echo "     (Volume in use or not found: $volume)"
    fi
done

# Also check for volumes with project name prefixes that might be missed
echo "   • Scanning for project-specific volumes..."
docker volume ls --format "{{.Name}}" | grep -E "^(xians-community-edition|community-edition)" | while read -r volume; do
    if [ -n "$volume" ]; then
        echo "   • Removing project volume: $volume"
        docker volume rm "$volume" 2>/dev/null || echo "     (Volume in use or not found: $volume)"
    fi
done

# Remove specific volumes that commonly cause project name conflicts
echo "   • Removing specific known volumes..."
specific_volumes=(
    "xians-mongodb-configdb"
    "xians-community-edition-data" 
    "xians-mongodb-data"
)

for volume in "${specific_volumes[@]}"; do
    if docker volume ls --format "{{.Name}}" | grep -q "^${volume}$"; then
        echo "   • Removing specific volume: $volume"
        docker volume rm "$volume" 2>/dev/null || echo "     (Volume in use: $volume)"
    fi
done

# Step 4: Remove anonymous volumes (created by containers but not used)
echo "🗑️  Removing unused anonymous volumes..."
unused_volumes=$(docker volume ls -q --filter "dangling=true")
if [ -n "$unused_volumes" ]; then
    echo "$unused_volumes" | while read -r volume; do
        if [ -n "$volume" ]; then
            echo "   • Removing anonymous volume: $volume"
            docker volume rm "$volume" 2>/dev/null || echo "     (Volume in use: $volume)"
        fi
    done
else
    echo "   • No unused anonymous volumes found"
fi

# Step 5: Clean up environment files
echo "🔒 Cleaning up environment files..."
if [ -f "scripts/delete-secrets.sh" ]; then
    ./scripts/delete-secrets.sh
else
    echo "   ⚠️  scripts/delete-secrets.sh not found (skipping)"
fi

echo ""
echo "✅ XiansAi platform reset completed successfully!"
echo ""
echo "📋 Next steps:"
echo "   - Start fresh: ./start-all.sh"
echo "   - Configure: Edit environment files as needed"
echo ""
echo "ℹ️  Note: You may need to reconfigure your environment files"
echo "   if this was your first time running the platform." 