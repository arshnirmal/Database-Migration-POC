-- ====================================================================
-- CASSANDRA KEYSPACE CREATION & OPTIMIZATION SETTINGS
-- ====================================================================
-- This file should be executed FIRST before any table creation
-- Contains keyspace creation and global optimization settings

-- Create the main keyspace for Fantasy Game Application
CREATE KEYSPACE IF NOT EXISTS fantasy_game
    WITH REPLICATION = {
        'class': 'NetworkTopologyStrategy',
        'datacenter1': 3
    }
    AND DURABLE_WRITES = true;

-- Use the keyspace
USE fantasy_game;

-- ====================================================================
-- GLOBAL TABLE OPTIMIZATION SETTINGS
-- ====================================================================
-- These settings are applied after table creation for production optimization

-- ====================================================================
-- COMPACTION STRATEGIES
-- ====================================================================

-- Size-Tiered Compaction Strategy (STCS) for write-heavy tables
-- Apply to: user_team_details, user_team_transfers, live_player_points, 
--          all log tables, user_activity_logs

-- Example for user_team_details:
-- ALTER TABLE user_team_details WITH compaction = {
--     'class': 'SizeTieredCompactionStrategy',
--     'max_threshold': 32,
--     'min_threshold': 4,
--     'bucket_high': 1.5,
--     'bucket_low': 0.5
-- };

-- Leveled Compaction Strategy (LCS) for read-heavy tables
-- Apply to: players, teams, users, global_leaderboard, league_leaderboards

-- Example for players:
-- ALTER TABLE players WITH compaction = {
--     'class': 'LeveledCompactionStrategy',
--     'sstable_size_in_mb': 160
-- };

-- ====================================================================
-- COMPRESSION SETTINGS
-- ====================================================================

-- LZ4 Compression for balanced performance (default for most tables)
-- Example:
-- ALTER TABLE table_name WITH compression = {
--     'class': 'LZ4Compressor',
--     'chunk_length_in_kb': 64
-- };

-- Snappy Compression for high-throughput tables
-- Apply to: gameset_player_stats, user_team_details, live_player_points
-- Example:
-- ALTER TABLE gameset_player_stats WITH compression = {
--     'class': 'SnappyCompressor'
-- };

-- ====================================================================
-- CACHING SETTINGS
-- ====================================================================

-- Row caching for frequently accessed small tables
-- Apply to: sports, devices, platforms, chip_types, etc.
-- Example:
-- ALTER TABLE sports WITH caching = {
--     'keys': 'ALL',
--     'rows_per_partition': 'ALL'
-- };

-- Key caching for large tables with hot keys
-- Apply to: users, players, user_teams
-- Example:
-- ALTER TABLE users WITH caching = {
--     'keys': 'ALL',
--     'rows_per_partition': 'NONE'
-- };

-- ====================================================================
-- BLOOM FILTER SETTINGS
-- ====================================================================

-- Optimized bloom filter for tables with many reads
-- Apply to: users_by_source_id, users_by_guid, players
-- Example:
-- ALTER TABLE users_by_source_id WITH bloom_filter_fp_chance = 0.01;

-- Relaxed bloom filter for write-heavy tables
-- Apply to: log tables, activity logs
-- Example:
-- ALTER TABLE engine_error_logs WITH bloom_filter_fp_chance = 0.1;

-- ====================================================================
-- TABLE-SPECIFIC OPTIMIZATION EXAMPLES
-- ====================================================================

-- High-performance user lookup tables
/*
ALTER TABLE users_by_source_id WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND bloom_filter_fp_chance = 0.01;

ALTER TABLE users_by_guid WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND bloom_filter_fp_chance = 0.01;
*/

-- Write-heavy gameplay tables
/*
ALTER TABLE user_team_details WITH 
    compaction = {
        'class': 'SizeTieredCompactionStrategy',
        'max_threshold': 32,
        'min_threshold': 4
    }
    AND compression = {'class': 'SnappyCompressor'}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'NONE'}
    AND bloom_filter_fp_chance = 0.05;

ALTER TABLE user_team_transfers WITH 
    compaction = {
        'class': 'SizeTieredCompactionStrategy',
        'max_threshold': 32,
        'min_threshold': 4
    }
    AND compression = {'class': 'SnappyCompressor'}
    AND bloom_filter_fp_chance = 0.1;
*/

-- Read-heavy leaderboard tables
/*
ALTER TABLE global_leaderboard WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 100}
    AND bloom_filter_fp_chance = 0.01;

ALTER TABLE league_leaderboards WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 50}
    AND bloom_filter_fp_chance = 0.01;
*/

-- Time-series tables with TTL
/*
ALTER TABLE live_player_points WITH 
    compaction = {
        'class': 'TimeWindowCompactionStrategy',
        'compaction_window_unit': 'HOURS',
        'compaction_window_size': 6
    }
    AND compression = {'class': 'SnappyCompressor'}
    AND bloom_filter_fp_chance = 0.1;

ALTER TABLE user_activity_logs WITH 
    compaction = {
        'class': 'TimeWindowCompactionStrategy',
        'compaction_window_unit': 'DAYS',
        'compaction_window_size': 1
    }
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND bloom_filter_fp_chance = 0.1;
*/

-- Static master data tables
/*
ALTER TABLE sports WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND bloom_filter_fp_chance = 0.01;

ALTER TABLE sport_skills WITH 
    compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 160}
    AND compression = {'class': 'LZ4Compressor', 'chunk_length_in_kb': 64}
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND bloom_filter_fp_chance = 0.01;
*/

-- ====================================================================
-- PERFORMANCE MONITORING SETUP
-- ====================================================================

-- Create tables for monitoring table-level metrics
CREATE TABLE IF NOT EXISTS performance_metrics (
    table_name text,
    metric_date text, -- YYYY-MM-DD
    metric_timestamp timestamp,
    read_latency_p95 double,
    read_latency_p99 double,
    write_latency_p95 double,
    write_latency_p99 double,
    read_rate double,
    write_rate double,
    error_rate double,
    compaction_lag bigint,
    disk_usage_gb double,
    PRIMARY KEY (table_name, metric_date, metric_timestamp)
) WITH CLUSTERING ORDER BY (metric_date DESC, metric_timestamp DESC)
AND default_time_to_live = 7776000 -- 90 days
AND COMMENT = 'Table-level performance metrics for monitoring';

-- ====================================================================
-- PRODUCTION DEPLOYMENT CHECKLIST
-- ====================================================================

/*
1. Keyspace Creation:
   - Execute this file first
   - Verify replication strategy matches your DC setup
   - Ensure durable_writes is enabled for production

2. Table Creation:
   - Execute table creation scripts in order:
     01_cassandra_master_data_tables.cql
     02_cassandra_user_gameplay_tables.cql
     03_cassandra_time_series_stats_tables.cql
     04_cassandra_leaderboard_league_tables.cql

3. Optimization Application:
   - Apply compaction strategies based on table usage patterns
   - Set compression based on hardware and performance requirements
   - Configure caching for your workload characteristics
   - Tune bloom filter settings for each table

4. Monitoring Setup:
   - Deploy table metrics collection
   - Set up alerting for key performance indicators
   - Configure log aggregation for error tracking

5. Security Configuration:
   - Enable authentication and authorization
   - Configure SSL/TLS for client-server communication
   - Set up network security groups
   - Enable audit logging

6. Backup Configuration:
   - Set up automated snapshot schedules
   - Configure cross-region backup replication
   - Test restore procedures

7. Validation:
   - Verify all tables are created successfully
   - Check replication across all nodes
   - Run basic CRUD operations on each table
   - Validate data consistency across replicas
*/

-- ====================================================================
-- CONNECTION POOL CONFIGURATION EXAMPLES
-- ====================================================================

/*
Java Driver Configuration:
```java
Cluster cluster = Cluster.builder()
    .addContactPoints("cassandra-node1", "cassandra-node2", "cassandra-node3")
    .withPort(9042)
    .withLoadBalancingPolicy(DCAwareRoundRobinPolicy.builder()
        .withLocalDc("datacenter1")
        .build())
    .withRetryPolicy(DefaultRetryPolicy.INSTANCE)
    .withReconnectionPolicy(new ExponentialReconnectionPolicy(1000, 30000))
    .withPoolingOptions(new PoolingOptions()
        .setConnectionsPerHost(HostDistance.LOCAL, 4, 8)
        .setConnectionsPerHost(HostDistance.REMOTE, 2, 4)
        .setMaxRequestsPerConnection(HostDistance.LOCAL, 1024)
        .setMaxRequestsPerConnection(HostDistance.REMOTE, 256))
    .withQueryOptions(new QueryOptions()
        .setConsistencyLevel(ConsistencyLevel.QUORUM)
        .setSerialConsistencyLevel(ConsistencyLevel.SERIAL))
    .build();
```

Python Driver Configuration:
```python
from cassandra.cluster import Cluster
from cassandra.policies import DCAwareRoundRobinPolicy, RetryPolicy

cluster = Cluster(
    contact_points=['cassandra-node1', 'cassandra-node2', 'cassandra-node3'],
    port=9042,
    load_balancing_policy=DCAwareRoundRobinPolicy(local_dc='datacenter1'),
    default_retry_policy=RetryPolicy(),
    protocol_version=4
)
session = cluster.connect('fantasy_game')
session.default_consistency_level = ConsistencyLevel.QUORUM
```
*/ 