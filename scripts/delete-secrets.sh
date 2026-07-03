#!/bin/bash

# Script to delete .env.local files from specified directories
# Usage: ./scripts/delete-secrets.sh

set -e

echo "🗑️  Deleting .env.local files..."

# Define directories to check
DIRECTORIES=("postgresql" "temporal" "server" "mongodb" "studio")

# Counter for deleted files
deleted_count=0

# Function to delete .env.local file if it exists
delete_env_file() {
    local dir=$1
    local env_file="$dir/.env.local"
    
    if [ -f "$env_file" ]; then
        echo "  ❌ Deleting $env_file"
        rm "$env_file"
        deleted_count=$((deleted_count + 1))
    else
        echo "  ℹ️  $env_file does not exist (skipping)"
    fi
}

# Check and delete .env.local files in each directory
for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        delete_env_file "$dir"
    else
        echo "  ⚠️  Directory '$dir' does not exist (skipping)"
    fi
done

# Summary
if [ $deleted_count -eq 0 ]; then
    echo "✅ No .env.local files found to delete"
else
    echo "✅ Successfully deleted $deleted_count .env.local file(s)"
fi

echo "🔒 Secret cleanup completed!"
