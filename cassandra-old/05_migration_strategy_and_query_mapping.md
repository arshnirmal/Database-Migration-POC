# Cassandra Migration Strategy for Fantasy Game Application

## Executive Summary

This document outlines the complete migration strategy from PostgreSQL to Cassandra for the Fantasy Game application, focusing on query-first design, denormalization, and optimal partition strategies for high-performance gaming workloads.

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Key Design Decisions](#key-design-decisions)
3. [Query Pattern Mapping](#query-pattern-mapping)
4. [Data Denormalization Strategy](#data-denormalization-strategy)
5. [Migration Phases](#migration-phases)
6. [Performance Optimizations](#performance-optimizations)
7. [Operational Considerations](#operational-considerations)

## Migration Overview

### Current PostgreSQL Schema Analysis

The existing PostgreSQL schema consists of 7 main modules:
- **engine_config**: Application and season configuration (20 tables)
- **game_management**: Teams, players, fixtures (5 tables)
- **game_user**: User data (1 partitioned table)
- **gameplay**: User teams and gameplay data (3 partitioned tables)
- **point_calculation**: Player statistics (2 tables)
- **league**: League and competition management (6 tables)
- **log**: Error and audit logging (2 tables)

### Target Cassandra Schema Design

The new Cassandra schema consolidates these into 4 optimized table groups:
- **Master Data Tables**: 15 static/configuration tables
- **User & Gameplay Tables**: 20 high-volume operational tables
- **Time-Series & Performance Tables**: 15 analytics and stats tables
- **Leaderboard & League Tables**: 18 social and ranking tables

## Key Design Decisions

### 1. Partition Key Strategy

**Season-Based Partitioning**: Most tables use `season_id` as the primary partition key to:
- Ensure even data distribution across seasons
- Enable season-specific queries without cross-partition reads
- Support natural data lifecycle management

**User Partitioning**: User-related tables maintain `partition_id` for:
- Horizontal scaling across user segments
- Load balancing for user operations
- Consistency with existing PostgreSQL partitioning

### 2. Denormalization Approach

**Query-First Design**: Tables are structured to match API access patterns:
- User session → Direct lookup by `source_id` or `user_guid`
- Game summary → Single partition read for all user teams
- Leaderboards → Pre-computed rankings with efficient pagination

**Master Data Embedding**: Foreign key relationships converted to:
- Direct data duplication for static lookups
- JSON embedding for complex relationships
- Secondary tables for critical lookup patterns

### 3. Time-Series Optimization

**Clustering Key Design**:
- Latest-first ordering with `DESC` clustering on time fields
- Composite clustering for multi-dimensional sorting
- Range queries optimized with proper clustering order

**TTL Strategy**:
- Session data: 24 hours
- Live match data: 7 days
- Error logs: 30 days
- User activity: 90 days
- Analytics data: 365 days

## Query Pattern Mapping

### 1. User Session Management

**PostgreSQL Query**:
```sql
SELECT u.*, s.game_token 
FROM game_user.user u 
LEFT JOIN user_sessions s ON u.user_guid = s.user_guid 
WHERE u.source_id = ?
```

**Cassandra Queries**:
```cql
-- Primary lookup
SELECT * FROM users_by_source_id WHERE source_id = ?;

-- Session check
SELECT * FROM user_sessions WHERE user_guid = ?;
```

**Performance Improvement**: Single partition read vs JOIN operation

### 2. User Game Summary

**PostgreSQL Query**:
```sql
WITH latest_teams AS (
  SELECT utd.*, ut.team_name,
         ROW_NUMBER() OVER (PARTITION BY utd.user_id, utd.team_no 
                           ORDER BY utd.gameset_id DESC) AS rn
  FROM gameplay.user_team_detail utd
  JOIN gameplay.user_teams ut ON ...
  WHERE utd.user_id = ? AND utd.season_id = ?
)
SELECT * FROM latest_teams WHERE rn = 1;
```

**Cassandra Query**:
```cql
-- Direct lookup from denormalized table
SELECT * FROM user_team_latest 
WHERE season_id = ? AND partition_id = ? AND user_id = ?;
```

**Performance Improvement**: Direct read vs complex CTE with window functions

### 3. Leaderboard Queries

**PostgreSQL Query**:
```sql
SELECT user_id, team_name, total_points, 
       RANK() OVER (ORDER BY total_points DESC) as rank
FROM user_team_aggregates 
WHERE season_id = ?
ORDER BY total_points DESC
LIMIT 50;
```

**Cassandra Query**:
```cql
-- Pre-computed rankings
SELECT * FROM global_leaderboard 
WHERE season_id = ? AND leaderboard_type = 'overall'
LIMIT 50;
```

**Performance Improvement**: O(1) read vs O(n log n) ranking computation

### 4. Player Statistics

**PostgreSQL Query**:
```sql
SELECT p.player_name, gp.points, gp.player_stats
FROM gameplay.gameset_player gp
JOIN game_management.player p ON gp.player_id = p.player_id
WHERE gp.season_id = ? AND gp.gameset_id = ?
ORDER BY gp.points DESC;
```

**Cassandra Query**:
```cql
-- Denormalized with embedded player data
SELECT * FROM gameset_player_stats
WHERE season_id = ? AND gameset_id = ?
LIMIT 100;
```

**Performance Improvement**: Single table read vs JOIN operation

## Data Denormalization Strategy

### 1. Master Data Denormalization

**Teams and Players**:
- Team names embedded in player records
- Skill names embedded in player records
- Sport properties stored as JSON

**Before (Normalized)**:
```sql
SELECT p.player_name, t.team_name, s.skill_name
FROM player p 
JOIN team t ON p.team_id = t.team_id
JOIN sport_skill s ON p.skill_id = s.skill_id;
```

**After (Denormalized)**:
```cql
SELECT player_name, team_name, skill_name FROM players_by_team;
```

### 2. User Data Denormalization

**User Team Latest State**:
- Current team composition stored separately
- Points and rankings pre-computed
- Transfer counts maintained in real-time

**Benefits**:
- Single-read user summaries
- Real-time dashboard updates
- Reduced computation overhead

### 3. Leaderboard Denormalization

**Pre-computed Rankings**:
- Global leaderboards updated async
- League rankings maintained per league
- Historical trends stored for analytics

**Update Strategy**:
- Batch updates during off-peak hours
- Real-time updates for active competitions
- Eventual consistency for non-critical rankings

## Migration Phases

### Phase 1: Infrastructure Setup (Week 1-2)

**Cassandra Cluster Setup**:
- 6-node cluster (3 DCs for HA)
- Replication factor: 3
- Consistency level: QUORUM
- Network topology strategy

**Schema Creation**:
- Execute CQL scripts in order
- Create keyspace with proper strategy
- Set up monitoring and alerting

**Testing Environment**:
- Parallel Cassandra cluster for testing
- Data validation tools
- Performance benchmarking setup

### Phase 2: Master Data Migration (Week 3)

**Static Data Migration**:
- Sports, skills, devices, platforms
- Applications and seasons
- Configuration tables
- League types and presets

**Validation**:
- Row count verification
- Data integrity checks
- Reference consistency validation

### Phase 3: Historical Data Migration (Week 4-6)

**User Data Migration**:
- Batch migrate user records
- Maintain partition_id distribution
- Create lookup tables

**Gameplay Data Migration**:
- Time-series data migration
- Team details historical data
- Transfer history migration

**Performance Monitoring**:
- Migration speed tracking
- Resource utilization monitoring
- Error rate monitoring

### Phase 4: Application Integration (Week 7-8)

**Dual-Write Implementation**:
- Write to both PostgreSQL and Cassandra
- Compare results for consistency
- Gradual read migration

**API Updates**:
- Update data access layer
- Implement new query patterns
- Add fallback mechanisms

**Testing**:
- Load testing with production data
- API response time validation
- Data consistency verification

### Phase 5: Full Cutover (Week 9-10)

**Read Migration**:
- Switch read queries to Cassandra
- Monitor performance metrics
- Validate data accuracy

**PostgreSQL Decommission**:
- Stop writes to PostgreSQL
- Archive historical data
- Decommission old infrastructure

**Optimization**:
- Fine-tune compaction strategies
- Optimize query performance
- Implement caching layers

## Performance Optimizations

### 1. Compaction Strategy

**Size-Tiered Compaction (STCS)**:
- For write-heavy tables (user_team_details, logs)
- Good for time-series data
- Lower write amplification

**Leveled Compaction (LCS)**:
- For read-heavy tables (players, teams)
- Better read performance
- Higher write amplification

### 2. Compression

**LZ4 Compression**:
- Default for most tables
- Good balance of speed and ratio
- Low CPU overhead

**Snappy Compression**:
- For high-throughput tables
- Faster than LZ4
- Slightly lower compression ratio

### 3. Caching Strategy

**Application-Level Caching**:
- Redis for session data
- Memcached for leaderboards
- CDN for static master data

**Cassandra-Level Optimization**:
- Row cache for hot data
- Key cache for frequently accessed keys
- OS page cache utilization

### 4. Connection Pooling

**Driver Configuration**:
- Connection pool per DC
- Load balancing across nodes
- Retry policies for failures

## Operational Considerations

### 1. Monitoring and Alerting

**Key Metrics**:
- Read/write latency percentiles
- Error rates and timeouts
- Compaction lag and disk usage
- JVM garbage collection metrics

**Alerting Thresholds**:
- P99 latency > 100ms
- Error rate > 0.1%
- Disk usage > 80%
- Compaction lag > 2 hours

### 2. Backup and Recovery

**Backup Strategy**:
- Daily incremental snapshots
- Weekly full snapshots
- Cross-region backup replication
- Point-in-time recovery capability

**Recovery Procedures**:
- Node replacement procedures
- Data center failover
- Corrupted data recovery
- Rollback mechanisms

### 3. Capacity Planning

**Scaling Triggers**:
- CPU utilization > 70%
- Disk usage > 75%
- Memory pressure indicators
- Query latency degradation

**Scaling Procedures**:
- Horizontal scaling (add nodes)
- Vertical scaling (upgrade hardware)
- Data center expansion
- Load balancing optimization

### 4. Security Considerations

**Authentication**:
- Role-based access control
- SSL/TLS encryption
- Network isolation
- API key management

**Data Protection**:
- Encryption at rest
- Audit logging
- Data masking for PII
- Compliance monitoring

## Success Metrics

### Performance Targets

- **Read Latency**: P95 < 50ms, P99 < 100ms
- **Write Latency**: P95 < 30ms, P99 < 50ms
- **Throughput**: 10,000+ reads/sec, 5,000+ writes/sec
- **Availability**: 99.9% uptime

### Business Metrics

- **User Experience**: Page load times < 2 seconds
- **Scalability**: Support 10x user growth
- **Cost Efficiency**: 30% reduction in database costs
- **Operational Overhead**: 50% reduction in maintenance time

## Conclusion

This migration strategy provides a comprehensive roadmap for transitioning from PostgreSQL to Cassandra while maintaining high performance and data consistency. The query-first design approach ensures optimal performance for gaming workloads, while the phased migration approach minimizes risk and downtime.

The denormalized schema design leverages Cassandra's strengths in distributed computing while avoiding common anti-patterns. With proper implementation of the monitoring, backup, and scaling procedures outlined above, the new Cassandra infrastructure will provide the scalability and performance needed for the Fantasy Game application's future growth. 