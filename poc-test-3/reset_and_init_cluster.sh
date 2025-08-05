#!/usr/bin/env bash
# ============================================================================
# Reset CockroachDB Cluster & Load Initial Fantasy Game Schema
# ============================================================================
# Stops the local docker-compose CockroachDB cluster, removes data volumes so
# you start with a completely clean slate, brings the cluster back online,
# initialises the cluster, and finally executes the SQL schema script so the
# database structure is ready for use.
#
# Usage:
#   ./reset_and_init_cluster.sh                     # run with defaults
#   INIT_SCRIPT=INIT_fantasy_game_setup.sql ./reset_and_init_cluster.sh
#
# Requirements:
#   • docker & docker compose installed
#   • Cluster defined in ./docker-compose.yaml with container names:
#       roach1, roach2, roach3
# ---------------------------------------------------------------------------
set -eu

COMPOSE_FILE="docker-compose.yaml"
INIT_SCRIPT=${INIT_SCRIPT:-"INIT_fantasy_game_setup.sql"}
NODES=(roach1 roach2 roach3)

info()  { echo -e "\033[0;32m[INFO ]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN ]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

[[ -f "$INIT_SCRIPT" ]] || error "Init script not found: $INIT_SCRIPT"

# ---------------------------------------------------------------------------
# 1. Stop cluster & remove volumes
# ---------------------------------------------------------------------------
info "Stopping cluster & removing volumes …"
docker compose -f "$COMPOSE_FILE" down -v

# ---------------------------------------------------------------------------
# 2. Bring cluster back up
# ---------------------------------------------------------------------------
info "Starting CockroachDB nodes …"
docker compose -f "$COMPOSE_FILE" up -d

# ---------------------------------------------------------------------------
# 3. Wait until all nodes answer SQL before continuing
# ---------------------------------------------------------------------------
wait_for_sql() {
  local node=$1 max=60
  until docker compose exec "$node" ./cockroach sql --insecure -e "SELECT 1;" &>/dev/null; do
    ((max--)) || { warn "$node still unavailable after 2 min"; return 1; }
    sleep 2
  done
}

info "Waiting for CockroachDB to finish bootstrapping …"
for node in "${NODES[@]}"; do
  wait_for_sql "$node" || error "Cluster did not start cleanly"
done

# ---------------------------------------------------------------------------
# 4. Initialise the cluster (idempotent – will be skipped if already initialised)
# ---------------------------------------------------------------------------
info "Initialising cluster …"
if ! docker compose exec roach1 ./cockroach node status --insecure &>/dev/null; then
  docker compose exec roach1 ./cockroach init --insecure
fi

# Give the cluster a moment to settle
sleep 5

# ---------------------------------------------------------------------------
# 5. Apply schema
# ---------------------------------------------------------------------------
info "Applying schema from $INIT_SCRIPT …"
docker compose exec -T roach1 ./cockroach sql --insecure < "$INIT_SCRIPT"

info "Cluster reset & schema applied successfully!"