#!/bin/bash

# Verify Temporal Search Attributes
# This script verifies that the required search attributes have been properly configured

set -e

echo "🔍 Verifying Temporal search attributes..."

# Check if Temporal container is available
if ! docker ps | grep -q "temporal"; then
    echo "❌ Temporal container is not running"
    echo "Please start Temporal services first: ./start-with-temporal.sh"
    exit 1
fi

echo "📋 Current search attributes in Temporal cluster:"
echo ""

# Get search attributes using the correct command
search_attrs=$(docker exec temporal tctl admin cluster get-search-attributes 2>/dev/null || echo "Failed to get search attributes")

echo "$search_attrs"

echo ""
echo "🎯 Checking for required search attributes:"

# Check for specific required attributes
required_attrs=("tenantId" "userId" "agent" "idPostfix")
all_found=true

for attr in "${required_attrs[@]}"; do
    if echo "$search_attrs" | grep -q "$attr"; then
        echo "  ✅ $attr: Found"
    else
        echo "  ❌ $attr: Not found"
        all_found=false
    fi
done

echo ""
if [ "$all_found" = true ]; then
    echo "🎉 All required search attributes are properly configured!"
    exit 0
else
    echo "⚠️  Some search attributes are missing. Run setup again:"
    echo "    ./temporal/setup-search-attributes.sh"
    exit 1
fi 