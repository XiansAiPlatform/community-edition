#!/bin/sh
# Registers the default Temporal namespace once the server is up.
# Runs inside the temporalio/admin-tools image; safe to re-run.
set -eu

NAMESPACE=${DEFAULT_NAMESPACE:-default}
RETENTION=${DEFAULT_NAMESPACE_RETENTION:-24h}
MAX_ATTEMPTS=30

echo "Waiting for Temporal server at ${TEMPORAL_ADDRESS}..."
attempt=1
until temporal operator cluster health >/dev/null 2>&1; do
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
        echo "Temporal server did not become healthy"
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep 5
done

if temporal operator namespace describe -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace '$NAMESPACE' already exists"
else
    temporal operator namespace create -n "$NAMESPACE" --retention "$RETENTION"
    echo "Namespace '$NAMESPACE' created"
fi
