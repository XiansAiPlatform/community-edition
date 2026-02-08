#!/bin/bash

# XiansAi Community Edition - Secret Recreation Script
# This script generates secure passwords and secrets for all services
# Called by start-all.sh to ensure secure defaults

set -e

# Source certificate generation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/certificate-generator.sh"

echo "🔐 Creating secrets for XiansAi Community Edition..."

# Check which services need .env.local files
echo "🔍 Checking which services need .env.local files..."
SERVICES_TO_GENERATE=""
EXISTING_FILES=""

for service in keycloak postgresql temporal server mongodb ui; do
    if [ -f "${service}/.env.local" ]; then
        EXISTING_FILES="${EXISTING_FILES}${service} "
    else
        SERVICES_TO_GENERATE="${SERVICES_TO_GENERATE}${service} "
    fi
done

if [ -n "$EXISTING_FILES" ]; then
    echo "   ✓ Found existing .env.local files (will skip):"
    for service in $EXISTING_FILES; do
        echo "     • ${service}/.env.local"
    done
fi

if [ -n "$SERVICES_TO_GENERATE" ]; then
    echo "   → Will generate secrets for:"
    for service in $SERVICES_TO_GENERATE; do
        echo "     • ${service}/.env.local"
    done
else
    echo "   ✓ All .env.local files already exist, nothing to generate."
    exit 0
fi

# Function to generate secure random password
generate_password() {
    local length=${1:-32}
    openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
}

# Function to generate base64 encoded secret
generate_base64_secret() {
    local length=${1:-64}
    openssl rand -base64 ${length} | tr -d '\n'
}

# Function to generate alphanumeric password
generate_alphanumeric() {
    local length=${1:-32}
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c${length}
}


# Function to update env file with generated secret
update_env_file() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if [ -f "$file" ]; then
        # Create a temporary file
        local temp_file=$(mktemp)
        
        # Process the file line by line
        while IFS= read -r line; do
            if [[ $line =~ ^${key}= ]]; then
                # Replace the line with the key
                echo "${key}=${value}" >> "$temp_file"
            else
                # Keep the original line
                echo "$line" >> "$temp_file"
            fi
        done < "$file"
        
        # Check if key was found and replaced
        if ! grep -q "^${key}=" "$temp_file"; then
            # Key wasn't found, append it
            echo "${key}=${value}" >> "$temp_file"
        fi
        
        # Replace the original file
        mv "$temp_file" "$file"
    else
        echo "⚠️  Warning: $file not found, skipping..."
    fi
}

# Function to check if a service needs secrets generated
service_needs_secrets() {
    local service="$1"
    echo "$SERVICES_TO_GENERATE" | grep -q "$service"
}

# Generate shared database credentials (used by both Temporal and Keycloak)
echo "🗄️  Generating database credentials..."
POSTGRES_USER="dbuser"
POSTGRES_PASSWORD=$(generate_alphanumeric 32)

# Generate MongoDB credentials
echo "🍃 Generating MongoDB credentials..."
MONGO_ROOT_USERNAME="xiansai_admin"
MONGO_APP_USERNAME="xiansai_app"
MONGO_DB_NAME="xians"
MONGO_ROOT_PASSWORD=$(generate_alphanumeric 32)
MONGO_APP_PASSWORD=$(generate_alphanumeric 32)

# Load values from root .env file (REQUIRED)
echo "📖 Reading configuration from root .env file..."
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Root .env file is in the parent directory of the script
ROOT_ENV_FILE="$(dirname "$SCRIPT_DIR")/.env"

# Check if root .env file exists
if [ ! -f "$ROOT_ENV_FILE" ]; then
    echo "❌ ERROR: Root .env file not found at $ROOT_ENV_FILE"
    echo ""
    echo "The root .env file is required and must contain:"
    echo "  • OPENAI_API_KEY=your_openai_api_key"
    echo "  • KEYCLOAK_ADMIN_PASSWORD=your_admin_password"
    echo ""
    echo "Please create the .env file in the project root directory."
    echo "You can copy .env.example as a starting point."
    exit 1
fi

echo "   Found root .env file, reading required values..."

# Read OPENAI_API_KEY from root .env
OPENAI_API_KEY=$(grep "^OPENAI_API_KEY=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
# Read KEYCLOAK_ADMIN_PASSWORD from root .env
KEYCLOAK_ADMIN_PASSWORD=$(grep "^KEYCLOAK_ADMIN_PASSWORD=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
# Read AUTH_HOST from root .env
AUTH_HOST=$(grep "^AUTH_HOST=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
# Read XIANSUI_HOST from root .env
XIANSUI_HOST=$(grep "^XIANSUI_HOST=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
# Read XIANSAPI_HOST from root .env
XIANSAPI_HOST=$(grep "^XIANSAPI_HOST=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
# Read TEMPORAL_HOST from root .env
TEMPORAL_HOST=$(grep "^TEMPORAL_HOST=" "$ROOT_ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")


# Validate that required values are present and not empty
MISSING_VALUES=""

if [ -z "$OPENAI_API_KEY" ]; then
    MISSING_VALUES="${MISSING_VALUES}  • OPENAI_API_KEY\n"
fi

if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    MISSING_VALUES="${MISSING_VALUES}  • KEYCLOAK_ADMIN_PASSWORD\n"
fi

if [ -n "$MISSING_VALUES" ]; then
    echo "❌ ERROR: Required values missing or empty in root .env file:"
    echo -e "$MISSING_VALUES"
    echo "Please set these values in $ROOT_ENV_FILE and try again."
    exit 1
fi

echo "   ✓ OpenAI API Key: [SET] (${#OPENAI_API_KEY} characters)"
echo "   ✓ Keycloak Admin Password: [SET] (${#KEYCLOAK_ADMIN_PASSWORD} characters)"

# Use Keycloak admin credentials from root .env
echo "🔐 Using Keycloak admin credentials from root .env file..."

# Generate server encryption keys and secrets
echo "🔑 Generating server encryption keys..."
ENCRYPTION_BASE_SECRET=$(generate_base64_secret 64)
CONVERSATION_MESSAGE_KEY=$(generate_base64_secret 32)
TENANT_OIDC_SECRET_KEY=$(generate_base64_secret 32)
APP_INTEGRATION_SECRET_KEY=$(generate_base64_secret 32)

# Generate Temporal UI client secret
echo "⏰ Generating Temporal UI client secret..."
TEMPORAL_UI_CLIENT_SECRET=$(generate_alphanumeric 48)

# Generate SSL certificate and password
echo "📜 Generating SSL certificate..."
CERT_PASSWORD=$(generate_alphanumeric 24)
CERT_BASE64=$(generate_ssl_certificate "$CERT_PASSWORD")

# Create .env.local files from .env.example templates (only for services that need them)
echo "📝 Creating .env.local files from templates..."

for service in $SERVICES_TO_GENERATE; do
    example_file="${service}/.env.example"
    local_file="${service}/.env.local"
    
    if [ -f "$example_file" ]; then
        echo "   Creating $local_file from $example_file"
        cp "$example_file" "$local_file"
    else
        echo "   ⚠️  Template $example_file not found, skipping..."
    fi
done

# Update PostgreSQL credentials (only for services that need them)
if service_needs_secrets "postgresql" || service_needs_secrets "temporal"; then
    echo "📝 Updating PostgreSQL credentials..."
    if service_needs_secrets "temporal"; then
        update_env_file "temporal/.env.local" "POSTGRES_USER" "$POSTGRES_USER"
        update_env_file "temporal/.env.local" "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
    fi
    if service_needs_secrets "postgresql"; then
        update_env_file "postgresql/.env.local" "POSTGRES_USER" "$POSTGRES_USER"
        update_env_file "postgresql/.env.local" "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
    fi
fi

# Update Temporal UI client secret and HOST_IP
if service_needs_secrets "temporal"; then
    echo "📝 Updating Temporal UI client secret and HOST_IP..."
    update_env_file "temporal/.env.local" "TEMPORAL_UI_CLIENT_SECRET" "$TEMPORAL_UI_CLIENT_SECRET"
    update_env_file "temporal/.env.local" "AUTH_HOST" "$AUTH_HOST"
    update_env_file "temporal/.env.local" "TEMPORAL_HOST" "$TEMPORAL_HOST"
fi

# Update Keycloak credentials (using same DB credentials)
if service_needs_secrets "keycloak"; then
    echo "📝 Updating Keycloak credentials..."
    update_env_file "keycloak/.env.local" "KEYCLOAK_ADMIN_PASSWORD" "$KEYCLOAK_ADMIN_PASSWORD"
    update_env_file "keycloak/.env.local" "KC_DB_USERNAME" "$POSTGRES_USER"
    update_env_file "keycloak/.env.local" "KC_DB_PASSWORD" "$POSTGRES_PASSWORD"
    update_env_file "keycloak/.env.local" "TEMPORAL_UI_CLIENT_SECRET" "$TEMPORAL_UI_CLIENT_SECRET"
    
    echo "📝 Updating Keycloak URL variables..."
    update_env_file "keycloak/.env.local" "TEMPORAL_HOST" "$TEMPORAL_HOST"
    update_env_file "keycloak/.env.local" "XIANSUI_HOST" "$XIANSUI_HOST"

    update_env_file "keycloak/.env.local" "AUTH_HOST" "$AUTH_HOST"
fi

# Update Server secrets
if service_needs_secrets "server"; then
    echo "📝 Updating server secrets..."
    update_env_file "server/.env.local" "Certificates__AppServerPfxBase64" "$CERT_BASE64"
    update_env_file "server/.env.local" "Certificates__AppServerCertPassword" "$CERT_PASSWORD"
    update_env_file "server/.env.local" "EncryptionKeys__BaseSecret" "$ENCRYPTION_BASE_SECRET"
    update_env_file "server/.env.local" "EncryptionKeys__UniqueSecrets__ConversationMessageKey" "$CONVERSATION_MESSAGE_KEY"
    update_env_file "server/.env.local" "EncryptionKeys__UniqueSecrets__TenantOidcSecretKey" "$TENANT_OIDC_SECRET_KEY"
    update_env_file "server/.env.local" "EncryptionKeys__UniqueSecrets__AppIntegrationSecretKey" "$APP_INTEGRATION_SECRET_KEY"

    echo "📝 Updating server CORS configuration..."
    update_env_file "server/.env.local" "Cors__AllowedOrigins__1" "$XIANSUI_HOST"

    echo "📝 Updating server MongoDB connection string..."
    MONGO_CONNECTION_STRING="mongodb://${MONGO_APP_USERNAME}:${MONGO_APP_PASSWORD}@mongodb:27017/${MONGO_DB_NAME}?replicaSet=rs0&retryWrites=true&w=majority&authSource=${MONGO_DB_NAME}"
    update_env_file "server/.env.local" "MongoDB__ConnectionString" "$MONGO_CONNECTION_STRING"
    
    echo "📝 Updating OpenAI API key in server configuration..."
    update_env_file "server/.env.local" "Llm__ApiKey" "$OPENAI_API_KEY"


    echo "📝 Updating server Keycloak URL..."
    update_env_file "server/.env.local" "Keycloak__AuthServerUrl" "$AUTH_HOST"
    update_env_file "server/.env.local" "Keycloak__ValidIssuer" "$AUTH_HOST/realms/xiansai"
fi

# Update MongoDB credentials
if service_needs_secrets "mongodb"; then
    echo "📝 Updating MongoDB credentials..."
    update_env_file "mongodb/.env.local" "MONGO_INITDB_ROOT_USERNAME" "$MONGO_ROOT_USERNAME"
    update_env_file "mongodb/.env.local" "MONGO_INITDB_ROOT_PASSWORD" "$MONGO_ROOT_PASSWORD"
    update_env_file "mongodb/.env.local" "MONGO_APP_USERNAME" "$MONGO_APP_USERNAME"
    update_env_file "mongodb/.env.local" "MONGO_APP_PASSWORD" "$MONGO_APP_PASSWORD"
    update_env_file "mongodb/.env.local" "MONGO_DB_NAME" "$MONGO_DB_NAME"
fi

# Update UI configuration
if service_needs_secrets "ui"; then
    echo "📝 Updating UI configuration..."
    update_env_file "ui/.env.local" "XIANSAPI_HOST" "$XIANSAPI_HOST"
    update_env_file "ui/.env.local" "AUTH_HOST" "$AUTH_HOST"
fi

echo ""
echo "✅ Secret creation completed successfully!"
echo ""
echo "📊 Generated secrets for services: $SERVICES_TO_GENERATE"

if service_needs_secrets "postgresql" || service_needs_secrets "temporal" || service_needs_secrets "keycloak"; then
    echo "   🗄️  PostgreSQL password: ${POSTGRES_PASSWORD:0:8}... (32 chars)"
fi

if service_needs_secrets "mongodb"; then
    echo "   🍃 MongoDB root password: ${MONGO_ROOT_PASSWORD:0:8}... (32 chars)"
    echo "   🍃 MongoDB app password: ${MONGO_APP_PASSWORD:0:8}... (32 chars)"
fi

if service_needs_secrets "keycloak"; then
    echo "   🔐 Keycloak admin password: ${KEYCLOAK_ADMIN_PASSWORD:0:8}... (${#KEYCLOAK_ADMIN_PASSWORD} chars)"
fi

if service_needs_secrets "temporal"; then
    echo "   ⏰ Temporal UI client secret: ${TEMPORAL_UI_CLIENT_SECRET:0:8}... (48 chars)"
fi

if service_needs_secrets "server"; then
    echo "   📜 SSL certificate password: ${CERT_PASSWORD:0:8}... (24 chars)"
    echo "   📜 SSL certificate (PFX): ${CERT_BASE64:0:32}... (base64, ~4KB)"
    echo "   🌐 WebSocket secrets: 2 secrets generated (32 chars each)"
    echo "   🔑 Encryption keys: 3 keys generated (base64 encoded)"
fi

if service_needs_secrets "ui"; then
    echo "   🖥️  UI Host IP: $HOST_IP"
fi
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   • This script only generates secrets for services missing .env.local files"
echo "   • Existing .env.local files are preserved and skipped"
echo "   • All database passwords have been randomly generated for security"
echo "   • PostgreSQL credentials are shared between Temporal and Keycloak"
echo "   • MongoDB has separate admin and application users for security"
echo "   • Keycloak admin password and OpenAI API key are read from root .env file (REQUIRED)"
echo "   • Root .env file must exist and contain valid OPENAI_API_KEY and KEYCLOAK_ADMIN_PASSWORD"
echo "   • These secrets are now stored in .env.local files (not in git)"
echo ""
