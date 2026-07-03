#!/bin/bash

# XiansAi Community Edition Docker Image Pull Script
# This script pulls the latest images from DockerHub for all services

set -e

# Default Configuration (can be overridden via command line)
VERSION="latest"
COMPOSE_PROJECT_NAME="xians-community-edition"

echo "📥 Pulling latest XiansAi Community Edition images from DockerHub..."

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -v, --version VERSION    Docker image version to pull (default: latest)"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "This script pulls the latest XiansAi docker images."
            echo ""
            echo "Examples:"
            echo "  $0                       # Pull latest images"
            echo "  $0 -v v2.1.0             # Pull specific version"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "📋 Configuration:"
echo "   Version: $VERSION"
echo ""

# Pull main XiansAi images
echo "🔧 Pulling main XiansAi application images..."
echo "   • Pulling XiansAi Server image..."
docker pull 99xio/xiansai-server:$VERSION

echo "   • Pulling Agent Studio image..."
docker pull 99xio/agent-studio:$VERSION

echo ""
echo "✅ All images pulled successfully!"
echo ""
echo "📋 Pulled images:"
echo "   • XiansAi Server: 99xio/xiansai-server:$VERSION"
echo "   • Agent Studio: 99xio/agent-studio:$VERSION"
echo ""
echo "💡 Next steps:"
echo "   • Start services: ./start-all.sh"
echo "   • View images: docker images"
echo "" 