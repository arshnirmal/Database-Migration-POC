#!/usr/bin/env bash

set -eu

COMPOSE_FILE="docker-compose.yaml"
INIT_SCRIPT=${INIT_SCRIPT:-"INIT_fantasy_game_setup.sql"}

info() { echo -e "\033[0;32m[INFO ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN ]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

[[ -f "$INIT_SCRIPT" ]] || error "Init script not found: $INIT_SCRIPT"

# 1. Stop cluster & remove volumes
info "Stopping cluster & removing volumes..."
docker compose -f "$COMPOSE_FILE" down -v

# 2. Start cluster
info "Starting CockroachDB nodes..."
docker compose -f "$COMPOSE_FILE" up -d

# 3. Wait for containers to be ready
info "Waiting for containers to start (60 seconds)..."
sleep 60

# 4. Verify network connectivity
info "Testing network connectivity..."
docker compose exec roach1 ping -c 2 roach2 || warn "roach1 -> roach2 ping failed"
docker compose exec roach1 ping -c 2 roach3 || warn "roach1 -> roach3 ping failed"

# 5. Initialize cluster (this must come before SQL readiness checks)
info "Initializing cluster..."
max_retries=30
retries=0

until docker compose exec roach1 /cockroach/cockroach init --insecure; do
    retries=$((retries+1))
    if [ "$retries" -ge "$max_retries" ]; then
        error "Failed to initialize cluster after $max_retries attempts"
    fi
    info "Init attempt $retries failed, retrying in 5 seconds..."
    sleep 5
done

info "✅ Cluster initialized successfully!"

# 6. Wait for cluster to be ready
info "Waiting for cluster to be fully ready..."
sleep 10

# 7. Verify cluster status
info "Checking cluster status..."
docker compose exec roach1 /cockroach/cockroach node status --insecure

# 8. Create database
info "Creating fantasy_game database..."
docker compose exec roach1 /cockroach/cockroach sql --insecure -e "CREATE DATABASE IF NOT EXISTS fantasy_game;"

# 9. Apply schema
if [[ -f "$INIT_SCRIPT" ]]; then
    info "Applying schema from $INIT_SCRIPT..."
    docker compose exec -T roach1 /cockroach/cockroach sql --insecure --database=fantasy_game < "$INIT_SCRIPT"
else
    warn "Init script $INIT_SCRIPT not found, skipping schema application"
fi

info "🎉 Cluster setup completed successfully!"
echo ""
info "📊 Access points:"
info "   Node 1 UI: http://localhost:8080"
info "   Node 2 UI: http://localhost:8081"  
info "   Node 3 UI: http://localhost:8082"
echo ""
info "🔗 Connect to cluster:"
info "   docker compose exec roach1 /cockroach/cockroach sql --insecure"
