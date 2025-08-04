#!/bin/bash

# ====================================================================
# Cassandra Cluster Manager for Fantasy Game Application
# ====================================================================
# Production-grade cluster management script with complete operations
# Author: DevOps Team
# Version: 1.0

set -euo pipefail

# Configuration
CLUSTER_NAME="FantasyGameCluster"
COMPOSE_FILE="docker-compose.yaml"
KEYSPACE="fantasy_game"
BACKUP_DIR="./backups"
LOG_DIR="./logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Create necessary directories
setup_directories() {
    log "Setting up directories..."
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "./monitoring"
}

# Function to check if cluster is healthy
check_cluster_health() {
    log "Checking cluster health..."
    
    # Check if all nodes are running
    local running_nodes=$(docker ps --filter "name=cassandra-dc" --filter "status=running" --format "table {{.Names}}" | wc -l)
    if [ "$running_nodes" -lt 6 ]; then
        warn "Only $running_nodes nodes are running out of 6 expected"
        return 1
    fi
    
    # Check cluster status via nodetool
    log "Checking cluster status..."
    docker exec cassandra-dc1-rack1-node1 nodetool status
    
    # Check if keyspace exists
    log "Checking keyspace replication..."
    docker exec cassandra-dc1-rack1-node1 cqlsh -e "DESCRIBE KEYSPACE $KEYSPACE;" || {
        warn "Keyspace $KEYSPACE not found or not properly replicated"
        return 1
    }
    
    log "Cluster health check completed successfully!"
    return 0
}

# Start the cluster
start_cluster() {
    log "Starting Cassandra cluster..."
    setup_directories
    
    log "Bringing up Docker Compose services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log "Waiting for cluster to initialize (this may take 5-10 minutes)..."
    sleep 120  # Give time for first node to start
    
    # Wait for cluster to be healthy
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log "Health check attempt $attempt/$max_attempts..."
        if check_cluster_health; then
            log "Cluster is ready!"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "Cluster failed to start after $max_attempts attempts"
        fi
        
        log "Waiting 30 seconds before next health check..."
        sleep 30
        ((attempt++))
    done
    
    log "Cassandra cluster started successfully!"
    log "Web UI available at: http://localhost:3000"
    log "CQL access: docker exec -it cassandra-dc1-rack1-node1 cqlsh"
}

# Stop the cluster
stop_cluster() {
    log "Stopping Cassandra cluster..."
    docker-compose -f "$COMPOSE_FILE" down
    log "Cluster stopped successfully!"
}

# Restart the cluster
restart_cluster() {
    log "Restarting Cassandra cluster..."
    stop_cluster
    sleep 10
    start_cluster
}

# Scale cluster (add nodes)
scale_cluster() {
    local new_nodes=${1:-1}
    log "Scaling cluster by adding $new_nodes node(s)..."
    
    warn "This operation requires manual configuration. Please:"
    echo "1. Add new service definitions to docker-compose.yaml"
    echo "2. Update CASSANDRA_SEEDS environment variable"
    echo "3. Run 'docker-compose up -d' to add new nodes"
    echo "4. Run nodetool cleanup on existing nodes"
}

# Backup cluster data
backup_cluster() {
    log "Creating cluster backup..."
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Take snapshots on all nodes
    for node in cassandra-dc1-rack1-node1 cassandra-dc1-rack2-node2 cassandra-dc1-rack3-node3 \
               cassandra-dc2-rack1-node4 cassandra-dc2-rack2-node5 cassandra-dc2-rack3-node6; do
        log "Taking snapshot on $node..."
        docker exec "$node" nodetool snapshot "$KEYSPACE" -t "backup_$backup_timestamp"
        
        log "Copying snapshot data from $node..."
        docker cp "$node:/var/lib/cassandra/data/$KEYSPACE" "$backup_path/${node}_data"
    done
    
    # Export schema
    log "Exporting schema..."
    docker exec cassandra-dc1-rack1-node1 cqlsh -e "DESCRIBE KEYSPACE $KEYSPACE;" > "$backup_path/schema.cql"
    
    # Create backup metadata
    cat > "$backup_path/backup_metadata.json" <<EOF
{
    "timestamp": "$backup_timestamp",
    "cluster_name": "$CLUSTER_NAME",
    "keyspace": "$KEYSPACE",
    "nodes": [
        "cassandra-dc1-rack1-node1",
        "cassandra-dc1-rack2-node2", 
        "cassandra-dc1-rack3-node3",
        "cassandra-dc2-rack1-node4",
        "cassandra-dc2-rack2-node5",
        "cassandra-dc2-rack3-node6"
    ],
    "backup_path": "$backup_path"
}
EOF
    
    log "Backup completed successfully at: $backup_path"
    
    # Cleanup old snapshots
    for node in cassandra-dc1-rack1-node1 cassandra-dc1-rack2-node2 cassandra-dc1-rack3-node3 \
               cassandra-dc2-rack1-node4 cassandra-dc2-rack2-node5 cassandra-dc2-rack3-node6; do
        docker exec "$node" nodetool clearsnapshot "$KEYSPACE" -t "backup_$backup_timestamp"
    done
}

# Restore from backup
restore_cluster() {
    local backup_path=${1:-}
    if [ -z "$backup_path" ]; then
        error "Please specify backup path: $0 restore /path/to/backup"
    fi
    
    if [ ! -d "$backup_path" ]; then
        error "Backup path not found: $backup_path"
    fi
    
    warn "This will restore data from backup. Current data will be lost!"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log "Restore cancelled"
        return
    fi
    
    log "Restoring cluster from backup: $backup_path"
    
    # Stop cluster
    stop_cluster
    
    # Clear existing data
    log "Clearing existing data volumes..."
    docker volume rm $(docker volume ls -q | grep cassandra.*-data) 2>/dev/null || true
    
    # Start cluster
    start_cluster
    
    # Restore schema
    log "Restoring schema..."
    docker exec -i cassandra-dc1-rack1-node1 cqlsh < "$backup_path/schema.cql"
    
    # Restore data (simplified - in production use sstableloader)
    warn "Data restore requires manual intervention with sstableloader tool"
    log "Backup schema restored. Please use sstableloader for data restoration."
}

# Monitor cluster performance
monitor_cluster() {
    log "Monitoring cluster performance..."
    
    echo "=== CLUSTER STATUS ==="
    docker exec cassandra-dc1-rack1-node1 nodetool status
    
    echo -e "\n=== CLUSTER INFO ==="
    docker exec cassandra-dc1-rack1-node1 nodetool info
    
    echo -e "\n=== HEAP USAGE ==="
    for node in cassandra-dc1-rack1-node1 cassandra-dc1-rack2-node2 cassandra-dc1-rack3-node3; do
        echo "Node: $node"
        docker exec "$node" nodetool gcstats
        echo "---"
    done
    
    echo -e "\n=== TABLE STATS ==="
    docker exec cassandra-dc1-rack1-node1 nodetool tablestats "$KEYSPACE"
    
    echo -e "\n=== COMPACTION STATS ==="
    docker exec cassandra-dc1-rack1-node1 nodetool compactionstats
}

# Repair cluster
repair_cluster() {
    log "Starting cluster repair..."
    
    for node in cassandra-dc1-rack1-node1 cassandra-dc1-rack2-node2 cassandra-dc1-rack3-node3 \
               cassandra-dc2-rack1-node4 cassandra-dc2-rack2-node5 cassandra-dc2-rack3-node6; do
        log "Repairing $node..."
        docker exec "$node" nodetool repair "$KEYSPACE"
    done
    
    log "Cluster repair completed!"
}

# Cleanup cluster
cleanup_cluster() {
    log "Cleaning up cluster..."
    
    for node in cassandra-dc1-rack1-node1 cassandra-dc1-rack2-node2 cassandra-dc1-rack3-node3 \
               cassandra-dc2-rack1-node4 cassandra-dc2-rack2-node5 cassandra-dc2-rack3-node6; do
        log "Cleaning up $node..."
        docker exec "$node" nodetool cleanup "$KEYSPACE"
    done
    
    log "Cluster cleanup completed!"
}

# View logs
view_logs() {
    local node=${1:-cassandra-dc1-rack1-node1}
    log "Viewing logs for $node..."
    docker logs -f "$node"
}

# Run CQL shell
cql_shell() {
    local node=${1:-cassandra-dc1-rack1-node1}
    log "Connecting to CQL shell on $node..."
    docker exec -it "$node" cqlsh
}

# Performance tuning recommendations
performance_tune() {
    log "Performance tuning recommendations:"
    
    echo "=== CURRENT JVM SETTINGS ==="
    docker exec cassandra-dc1-rack1-node1 ps aux | grep java
    
    echo -e "\n=== RECOMMENDATIONS ==="
    echo "1. Monitor GC performance: Use G1GC for large heaps"
    echo "2. Tune concurrent reads/writes based on workload"
    echo "3. Optimize compaction strategy per table"
    echo "4. Monitor disk I/O and consider SSD storage"
    echo "5. Adjust commit log sync settings for write performance"
    echo "6. Use connection pooling in application drivers"
}

# Show help
show_help() {
    cat <<EOF
Cassandra Cluster Manager for Fantasy Game Application

USAGE:
    $0 <command> [options]

COMMANDS:
    start              Start the Cassandra cluster
    stop               Stop the Cassandra cluster  
    restart            Restart the Cassandra cluster
    status             Check cluster health and status
    scale <count>      Scale cluster (add nodes)
    
    backup             Create full cluster backup
    restore <path>     Restore cluster from backup
    
    monitor            Monitor cluster performance
    repair             Run cluster repair
    cleanup            Run cluster cleanup
    
    logs [node]        View logs for specific node
    cql [node]         Connect to CQL shell
    tune               Show performance tuning recommendations
    
    help               Show this help message

EXAMPLES:
    $0 start                           # Start cluster
    $0 status                          # Check health
    $0 backup                          # Create backup
    $0 restore ./backups/backup_123    # Restore from backup
    $0 logs cassandra-dc1-rack1-node1  # View specific node logs
    $0 cql                             # Connect to CQL shell

For more information, visit: https://cassandra.apache.org/doc/latest/
EOF
}

# Main command dispatcher
main() {
    case "${1:-}" in
        start)
            start_cluster
            ;;
        stop)
            stop_cluster
            ;;
        restart)
            restart_cluster
            ;;
        status)
            check_cluster_health
            ;;
        scale)
            scale_cluster "${2:-1}"
            ;;
        backup)
            backup_cluster
            ;;
        restore)
            restore_cluster "${2:-}"
            ;;
        monitor)
            monitor_cluster
            ;;
        repair)
            repair_cluster
            ;;
        cleanup)
            cleanup_cluster
            ;;
        logs)
            view_logs "${2:-}"
            ;;
        cql)
            cql_shell "${2:-}"
            ;;
        tune)
            performance_tune
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: ${1:-}. Use '$0 help' for available commands."
            ;;
    esac
}

# Run main function
main "$@" 