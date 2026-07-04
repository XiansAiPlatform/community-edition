#!/bin/bash

# XiansAi Community Edition - Certificate Generation Functions
# This script contains functions for generating SSL certificates and related cryptographic operations

# Function to generate SSL certificate and return base64 encoded PFX
generate_ssl_certificate() {
    local password="$1"
    local temp_dir="./temp_cert_$$"
    mkdir -p "$temp_dir"
    
    echo "📜 Generating root CA certificate compatible with CertificateGenerator..." >&2
    
    # Root CA config with proper v3 extensions (UPDATED to match server expectations)
    cat > "$temp_dir/rootCA.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = default
OU = admin
CN = XiansAi Root CA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,keyCertSign,cRLSign
EOF

    # Generate root CA key. The temp key is created, used, and deleted within this
    # function, so it does not need on-disk encryption — only the exported PFX is
    # password-protected (below). Encrypting it with -des3 produces a PKCS#8
    # "ENCRYPTED PRIVATE KEY" that OpenSSL 3.x's `req -passin pass:` fails to read
    # (it falls back to a TTY passphrase prompt and aborts). Keep it unencrypted.
    openssl genrsa -out "$temp_dir/rootCA.key" 4096
    
    # Generate root CA certificate with proper CA extensions
    openssl req -x509 -new -nodes -key "$temp_dir/rootCA.key" -sha256 -days 18250 \
        -config "$temp_dir/rootCA.conf" \
        -extensions v3_ca \
        -out "$temp_dir/rootCA.crt" \
        -set_serial $(date -u +%s)
    
    echo "📜 Creating PFX with ONLY the root CA certificate and its private key..." >&2
    
    # CRITICAL FIX: Create PFX with ONLY the root CA certificate and its private key
    # This is what CertificateGenerator expects - a CA that can sign client certificates
    openssl pkcs12 -export \
        -out "$temp_dir/rootCA.pfx" \
        -inkey "$temp_dir/rootCA.key" \
        -in "$temp_dir/rootCA.crt" \
        -passout pass:"$password" \
        -name "XiansAi Root CA"
    
    # Output base64 for .env usage
    if [ -f "$temp_dir/rootCA.pfx" ]; then
        echo "✅ Root CA certificate generated successfully" >&2
        
        # Verify the certificate has proper CA extensions
        echo "🔍 Verifying certificate extensions..." >&2
        openssl x509 -in "$temp_dir/rootCA.crt" -noout -text | grep -A5 "X509v3 Basic Constraints" >&2
        
        cat "$temp_dir/rootCA.pfx" | base64 | tr -d '\n\r '
        rm -rf "$temp_dir"
    else
        echo "❌ Failed to generate certificate" >&2
        rm -rf "$temp_dir"
        return 1
    fi
}
