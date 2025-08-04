#!/bin/bash
# ============================================================================
# Reset ScyllaDB Cluster & Load Initial Fantasy Game Schema
# ============================================================================
# Stops the local docker compose ScyllaDB cluster, removes data volumes so
# you start with a completely clean slate, brings the cluster back online, and
# finally executes the schema script on each node so replication is
# guaranteed.
#
# Usage:
#   ./reset_and_init_cluster.sh              # run with defaults
#   INIT_SCRIPT=INIT_fantasy_game_scylladb_setup.cql ./reset_and_init_cluster.sh
#
# Requirements:
#   • docker & docker compose installed
#   • Cluster defined in ./docker-compose.yaml with container names:
#       fantasy-scylla-node1, fantasy-scylla-node2, fantasy-scylla-node3
# ----------------------------------------------------------------------------
set -euo pipefail

COMPOSE_FILE="docker-compose.yaml"
INIT_SCRIPT=${INIT_SCRIPT:-"INIT_fantasy_game_scylladb_setup.cql"}
CONTAINERS=(fantasy-scylla-node1 fantasy-scylla-node2 fantasy-scylla-node3)
# Maximum time to wait for each node to accept CQL connections (seconds)
WAIT_SECONDS=${WAIT_SECONDS:-300}

info()  { echo -e "\033[0;32m[INFO ]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN ]\033[0m $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

[[ -f "$INIT_SCRIPT" ]] || error "Init script not found: $INIT_SCRIPT"

# -----------------------------------------------------------------------------
# 1. Stop cluster & remove volumes
# -----------------------------------------------------------------------------
info "Stopping cluster & removing volumes …"
docker compose -f "$COMPOSE_FILE" down -v

# Optional: clear local log directory
if [[ -d ./scylla-logs ]]; then
  info "Clearing old log files …"
  rm -rf ./scylla-logs/*
fi

# -----------------------------------------------------------------------------
# 2. Bring cluster back up
# -----------------------------------------------------------------------------
info "Starting ScyllaDB nodes …"
docker compose -f "$COMPOSE_FILE" up -d

# -----------------------------------------------------------------------------
# 2b. Wait until *all* ScyllaDB nodes are reachable on CQL port
# -----------------------------------------------------------------------------
wait_for_cql() {
  local node=$1
  local retries=$((WAIT_SECONDS / 2))
  until docker exec "$node" cqlsh -e "SELECT now() FROM system.local" &>/dev/null; do
    ((retries--)) || { warn "$node still unavailable after ${WAIT_SECONDS}s"; return 1; }
    sleep 2
  done
}

info "Waiting for ScyllaDB to finish bootstrapping …"
for node in "${CONTAINERS[@]}"; do
  wait_for_cql "$node" || error "Cluster did not start cleanly"
done

# -----------------------------------------------------------------------------
# 3. Execute init schema once (it will propagate via gossip)
#    – adjust RF to the current node count automatically
# -----------------------------------------------------------------------------

NODE_COUNT=${#CONTAINERS[@]}
info "Applying schema (RF=$NODE_COUNT) …"

# Create a temp copy with the right replication factor
TMP_CQL=$(mktemp)
sed "s/'replication_factor': *[0-9]\+/'replication_factor': $NODE_COUNT/" "$INIT_SCRIPT" > "$TMP_CQL"

# Apply only on the first node; schema spreads to the rest
docker exec -i "${CONTAINERS[0]}" cqlsh < "$TMP_CQL"
rm -f "$TMP_CQL"

info "Cluster reset & schema applied successfully!"
