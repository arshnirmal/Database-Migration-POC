# 🚀 Cassandra Fantasy Game Cluster - Production Deployment Guide

## 📋 Prerequisites

### System Requirements (Per Node)
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: SSD with 500GB+ available space
- **Network**: Gigabit ethernet with low latency
- **OS**: Linux (Ubuntu 20.04+ or CentOS 8+)

### Software Dependencies
- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 8GB RAM available for containers
- Ports 9042, 7000, 7001, 7199 available

## 🛠️ Quick Start

### 1. Clone and Setup
```bash
# Make the cluster manager executable
chmod +x cassandra-cluster-manager.sh

# Start the cluster
./cassandra-cluster-manager.sh start
```

### 2. Verify Installation
```bash
# Check cluster status
./cassandra-cluster-manager.sh status

# Connect to CQL shell
./cassandra-cluster-manager.sh cql

# Access Web UI
open http://localhost:3000
```

## 🏗️ Architecture Overview

### Cluster Topology
```
Fantasy Game Cassandra Cluster
├── DataCenter 1 (datacenter1)
│   ├── Rack 1: cassandra-dc1-rack1-node1 (172.20.1.10:9042)
│   ├── Rack 2: cassandra-dc1-rack2-node2 (172.20.1.11:9043)  
│   └── Rack 3: cassandra-dc1-rack3-node3 (172.20.1.12:9044)
└── DataCenter 2 (datacenter2)
    ├── Rack 1: cassandra-dc2-rack1-node4 (172.20.2.10:9045)
    ├── Rack 2: cassandra-dc2-rack2-node5 (172.20.2.11:9046)
    └── Rack 3: cassandra-dc2-rack3-node6 (172.20.2.12:9047)
```

### Replication Strategy
- **Keyspace**: `fantasy_game`
- **Strategy**: `NetworkTopologyStrategy`
- **Replication**: 3 replicas per datacenter
- **Consistency**: QUORUM reads/writes for strong consistency

### Performance Optimizations
- **JVM**: G1GC with 8GB heap per node
- **Tokens**: 16 virtual nodes per physical node
- **Compaction**: Workload-specific strategies
- **Caching**: Optimized for gaming workloads

## 🔧 Configuration Details

### JVM Tuning
```bash
# Heap Settings
MAX_HEAP_SIZE=8G
HEAP_NEWSIZE=2G

# G1 Garbage Collector
-XX:+UseG1GC
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=200
-XX:InitiatingHeapOccupancyPercent=25
```

### Network Configuration
```yaml
# Dedicated overlay network
networks:
  cassandra-cluster:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Storage Configuration
```yaml
# Persistent volumes per node
volumes:
  - cassandra1-data:/var/lib/cassandra/data
  - cassandra1-commitlog:/var/lib/cassandra/commitlog
  - cassandra1-config:/etc/cassandra
```

## 📊 Monitoring & Observability

### Health Checks
```bash
# Automated health monitoring
healthcheck:
  test: ["CMD-SHELL", "cqlsh -e 'SELECT now() FROM system.local'"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 2m
```

### Performance Monitoring
```bash
# Real-time cluster monitoring
./cassandra-cluster-manager.sh monitor

# View specific node logs
./cassandra-cluster-manager.sh logs cassandra-dc1-rack1-node1

# Performance tuning recommendations
./cassandra-cluster-manager.sh tune
```

### Key Metrics to Monitor
- **Latency**: Read/write P95, P99 response times
- **Throughput**: Operations per second
- **Error Rate**: Failed requests percentage
- **Resource Usage**: CPU, memory, disk I/O
- **Compaction**: Pending compactions
- **GC Performance**: Pause times and frequency

## 🔐 Security Configuration

### Authentication & Authorization
```yaml
environment:
  - CASSANDRA_AUTHENTICATOR=PasswordAuthenticator
  - CASSANDRA_AUTHORIZER=CassandraAuthorizer
```

### Default Credentials
- **Username**: `cassandra`
- **Password**: `cassandra`
- **⚠️ Change in production!**

### Network Security
- Internal cluster communication on private subnet
- Firewall rules limiting external access
- Consider enabling SSL/TLS for production

## 🔄 Backup & Recovery

### Automated Backups
```bash
# Create full cluster backup
./cassandra-cluster-manager.sh backup

# Restore from backup
./cassandra-cluster-manager.sh restore ./backups/backup_20240101_120000
```

### Backup Strategy
- **Frequency**: Daily incremental, weekly full
- **Retention**: 30 days local, 90 days remote
- **Location**: `./backups/` directory
- **Metadata**: JSON files with backup information

### Disaster Recovery
1. **Node Failure**: Automatic failover with replication
2. **Rack Failure**: Cross-rack replication ensures availability
3. **Datacenter Failure**: Cross-DC replication maintains service
4. **Complete Failure**: Restore from backup snapshots

## ⚙️ Maintenance Operations

### Cluster Repair
```bash
# Weekly repair (recommended)
./cassandra-cluster-manager.sh repair
```

### Cleanup Operations
```bash
# After adding/removing nodes
./cassandra-cluster-manager.sh cleanup
```

### Rolling Updates
```bash
# Stop cluster
./cassandra-cluster-manager.sh stop

# Update docker-compose.yaml
# Update image versions or configuration

# Start cluster
./cassandra-cluster-manager.sh start
```

## 📈 Scaling Operations

### Horizontal Scaling
```bash
# Add nodes to cluster
./cassandra-cluster-manager.sh scale 2

# Manual steps required:
# 1. Add service definitions to docker-compose.yaml
# 2. Update seed node configurations
# 3. Run nodetool cleanup on existing nodes
```

### Vertical Scaling
```yaml
# Update resource limits in docker-compose.yaml
deploy:
  resources:
    limits:
      memory: 16G  # Increase from 12G
      cpus: '6.0'  # Increase from 4.0
```

## 🚨 Troubleshooting

### Common Issues

#### Cluster Won't Start
```bash
# Check Docker resources
docker system df
docker system prune

# Check logs
./cassandra-cluster-manager.sh logs

# Verify network connectivity
docker network ls
```

#### Node Connection Issues
```bash
# Check gossip protocol
docker exec cassandra-dc1-rack1-node1 nodetool gossipinfo

# Verify seed node configuration
docker exec cassandra-dc1-rack1-node1 nodetool describecluster
```

#### Performance Issues
```bash
# Check compaction status
docker exec cassandra-dc1-rack1-node1 nodetool compactionstats

# Monitor GC performance
docker exec cassandra-dc1-rack1-node1 nodetool gcstats

# Check table statistics
docker exec cassandra-dc1-rack1-node1 nodetool tablestats fantasy_game
```

### Log Locations
- **Container Logs**: `docker logs <container_name>`
- **Cassandra Logs**: `/var/log/cassandra/` inside containers
- **GC Logs**: JVM garbage collection metrics
- **System Logs**: Docker daemon and system logs

## 🎮 Fantasy Game Specific Operations

### Schema Management
```bash
# Connect to CQL shell
./cassandra-cluster-manager.sh cql

# Common queries
USE fantasy_game;
DESCRIBE TABLES;
SELECT * FROM sports LIMIT 10;
```

### Data Import/Export
```bash
# Export data
docker exec cassandra-dc1-rack1-node1 cqlsh -e "COPY fantasy_game.users TO '/tmp/users.csv'"

# Import data  
docker exec cassandra-dc1-rack1-node1 cqlsh -e "COPY fantasy_game.users FROM '/tmp/users.csv'"
```

### Performance Optimization
```cql
-- Apply table-specific optimizations
ALTER TABLE user_team_details WITH compaction = {
    'class': 'SizeTieredCompactionStrategy',
    'max_threshold': 32,
    'min_threshold': 4
};

-- Enable compression for high-volume tables
ALTER TABLE live_player_points WITH compression = {
    'class': 'SnappyCompressor'
};
```

## 📚 Best Practices

### Development Workflow
1. **Local Testing**: Use single-node setup for development
2. **Staging**: Multi-node cluster matching production
3. **Production**: Full 6-node cluster with monitoring

### Operational Excellence
1. **Monitor Continuously**: Set up alerting for key metrics
2. **Backup Regularly**: Automated daily backups
3. **Test Recovery**: Monthly disaster recovery drills
4. **Update Gradually**: Rolling updates with validation
5. **Document Changes**: Maintain operational runbooks

### Query Optimization
1. **Partition Keys**: Design for even distribution
2. **Clustering Keys**: Support query patterns
3. **Batch Operations**: Keep batches small and logged
4. **Consistency Levels**: Use QUORUM for critical data
5. **TTL Usage**: Auto-expire temporary data

## 🆘 Support & Resources

### Documentation
- [Official Cassandra Documentation](https://cassandra.apache.org/doc/latest/)
- [DataStax Academy](https://academy.datastax.com/)
- [Cassandra Best Practices](https://docs.datastax.com/en/dse/6.8/cql/cql/cql_using/best_practices_c.html)

### Community Support
- [Apache Cassandra Users Mailing List](https://cassandra.apache.org/community/)
- [Stack Overflow #cassandra](https://stackoverflow.com/questions/tagged/cassandra)
- [Reddit r/cassandra](https://reddit.com/r/cassandra)

### Commercial Support
- DataStax Enterprise Support
- Instaclustr Managed Cassandra
- AWS Keyspaces (managed service)

---

**🎉 Congratulations!** You now have a production-ready Cassandra cluster optimized for fantasy gaming workloads. This setup provides high availability, scalability, and performance to support millions of users with sub-second response times.

For additional support or custom configurations, refer to the troubleshooting section or consult the Cassandra community resources. 