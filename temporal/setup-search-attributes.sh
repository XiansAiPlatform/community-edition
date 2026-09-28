#!/bin/bash

# Setup Temporal Search Attributes
# Registers the search attributes required by the XiansAi platform in the
# Temporal cluster. Uses SQL-based (PostgreSQL) visibility, so attributes are
# registered directly in Temporal metadata via the modern `temporal` CLI.

set -e

# The Temporal server image ships no CLI; commands run in the admin-tools
# container, which is preconfigured with TEMPORAL_ADDRESS.
TEMPORAL_CLI="docker exec temporal-admin-tools temporal"

echo "🔧 Setting up Temporal search attributes..."

# Function to check if Temporal is ready
wait_for_temporal() {
    echo "⏳ Waiting for Temporal server to be ready..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        # First check if the service is serving
        if $TEMPORAL_CLI operator cluster health >/dev/null 2>&1; then
            echo "✅ Temporal server is ready!"

            # Now check if the default namespace exists
            echo "⏳ Waiting for default namespace to be available..."
            local namespace_attempts=15
            local namespace_attempt=1

            while [ $namespace_attempt -le $namespace_attempts ]; do
                if $TEMPORAL_CLI operator namespace describe --namespace default >/dev/null 2>&1; then
                    echo "✅ Default namespace is available!"
                    return 0
                fi

                echo "  Namespace attempt $namespace_attempt/$namespace_attempts - Default namespace not ready yet..."
                sleep 3
                ((namespace_attempt++))
            done

            echo "❌ Default namespace failed to become available after $namespace_attempts attempts"
            return 1
        fi

        echo "  Attempt $attempt/$max_attempts - Temporal not ready yet..."
        sleep 5
        ((attempt++))
    done

    echo "❌ Temporal server failed to become ready after $max_attempts attempts"
    return 1
}

# Function to setup search attributes
setup_search_attributes() {
    echo "🏷️  Adding search attributes..."

    # Required search attributes and their types
    local names=("tenantId" "userId" "agent" "idPostfix")
    local types=("Keyword" "Keyword" "Keyword" "Keyword")

    # Snapshot of currently registered attributes (best-effort)
    local existing_attrs
    existing_attrs=$($TEMPORAL_CLI operator search-attribute list --namespace default 2>/dev/null || echo "")

    for i in "${!names[@]}"; do
        local name="${names[$i]}"
        local type="${types[$i]}"

        if echo "$existing_attrs" | grep -q "$name"; then
            echo "  ✓ $name search attribute already exists"
            continue
        fi

        echo "    - Adding $name as $type..."
        $TEMPORAL_CLI operator search-attribute create \
            --namespace default --name "$name" --type "$type" 2>/dev/null && {
            echo "      ✅ $name registered successfully!"
        } || {
            echo "      ⚠️  $name registration failed (it may already exist)"
        }
    done

    echo "✅ Search attributes setup completed!"
}

# Main execution
if wait_for_temporal; then
    setup_search_attributes
else
    echo "❌ Failed to setup search attributes - Temporal server not ready"
    exit 1
fi

echo "🎉 Temporal search attributes configuration complete!"
