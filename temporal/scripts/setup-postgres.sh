#!/bin/sh
# Creates the Temporal databases and applies/upgrades their schemas.
#
# Runs once per startup inside the temporalio/admin-tools image, before the
# Temporal server starts. It is idempotent: on an existing installation the
# databases are left in place and only pending schema migrations are applied,
# which is how an upgrade of TEMPORAL_VERSION migrates the stored data.
set -eu

: "${POSTGRES_SEEDS:?POSTGRES_SEEDS is required}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${SQL_PASSWORD:?SQL_PASSWORD is required}"

DB_PORT=${DB_PORT:-5432}
SCHEMA_DIR=/etc/temporal/schema/postgresql/v12

sql_tool() {
    temporal-sql-tool --plugin postgres12 --ep "$POSTGRES_SEEDS" -u "$POSTGRES_USER" -p "$DB_PORT" "$@"
}

echo "Waiting for PostgreSQL at ${POSTGRES_SEEDS}:${DB_PORT}..."
attempt=1
until nc -z -w 5 "$POSTGRES_SEEDS" "$DB_PORT"; do
    if [ "$attempt" -ge 30 ]; then
        echo "PostgreSQL did not become reachable"
        exit 1
    fi
    attempt=$((attempt + 1))
    sleep 2
done

# Every step is idempotent: `create` and `setup-schema -v 0.0` are no-ops on an
# existing database, and `update-schema` only applies pending migrations.
setup_db() {
    db="$1"
    schema="$2"
    echo "Setting up database '$db'..."
    sql_tool --db "$db" create
    sql_tool --db "$db" setup-schema -v 0.0
    sql_tool --db "$db" update-schema -d "$SCHEMA_DIR/$schema/versioned"
}

setup_db temporal temporal
setup_db temporal_visibility visibility

echo "Temporal schema setup complete"
