#!/bin/bash
# Setup script for PostgreSQL read replica
# Creates base backup from primary and configures streaming replication

set -e

echo "Setting up PostgreSQL read replica..."

# Wait for primary to be ready
echo "Waiting for primary database to be ready..."
until pg_isready -h "$POSTGRES_PRIMARY_HOST" -p "$POSTGRES_PRIMARY_PORT" -U "$POSTGRES_REPLICA_USER"; do
  echo "Primary database not ready, waiting..."
  sleep 2
done

echo "Primary database is ready, proceeding with replica setup..."

# Create .pgpass file for authentication
echo "$POSTGRES_PRIMARY_HOST:$POSTGRES_PRIMARY_PORT:*:$POSTGRES_REPLICA_USER:$POSTGRES_REPLICA_PASSWORD" > ~/.pgpass
chmod 600 ~/.pgpass

# Only setup if data directory is empty
if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
    echo "Data directory is empty, creating base backup..."
    
    # Remove any existing data
    rm -rf /var/lib/postgresql/data/*
    
    # Create base backup from primary
    PGPASSWORD="$POSTGRES_REPLICA_PASSWORD" pg_basebackup \
        -h "$POSTGRES_PRIMARY_HOST" \
        -p "$POSTGRES_PRIMARY_PORT" \
        -D /var/lib/postgresql/data \
        -U "$POSTGRES_REPLICA_USER" \
        -v -P -W
    
    echo "Base backup completed successfully"
    
    # Create recovery configuration
    cat > /var/lib/postgresql/data/recovery.conf << EOF
standby_mode = 'on'
primary_conninfo = 'host=$POSTGRES_PRIMARY_HOST port=$POSTGRES_PRIMARY_PORT user=$POSTGRES_REPLICA_USER password=$POSTGRES_REPLICA_PASSWORD'
trigger_file = '/tmp/postgresql.trigger'
recovery_target_timeline = 'latest'
EOF

    echo "Recovery configuration created"
    
    # Set proper permissions
    chown -R postgres:postgres /var/lib/postgresql/data
    chmod 700 /var/lib/postgresql/data
    
    echo "Replica setup completed successfully"
else
    echo "Data directory already exists, skipping base backup"
fi

echo "Starting PostgreSQL replica server..."