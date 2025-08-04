-- INIT_fantasy_game_scylladb_setup.cql
-- ====================================================================
-- FANTASY GAME - SCYLLADB SCHEMA SETUP
-- ====================================================================
-- ScyllaDB-optimized version with performance enhancements
-- 
-- Usage:
-- cqlsh -f INIT_fantasy_game_scylladb_setup.cql
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. KEYSPACE CREATION with ScyllaDB optimizations
-- --------------------------------------------------------------------
CREATE KEYSPACE IF NOT EXISTS fantasy_game
WITH REPLICATION = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 3  -- RF = 3 across primary DC
}
AND DURABLE_WRITES = true;

-- Switch to the keyspace
USE fantasy_game;

-- --------------------------------------------------------------------
-- 2. USERS & AUTHENTICATION TABLES
-- --------------------------------------------------------------------

-- Main user profile table with ScyllaDB optimizations
CREATE TABLE IF NOT EXISTS users (
    partition_id smallint,
    user_id bigint,
    source_id text,
    user_guid uuid,
    first_name text,
    last_name text,
    user_name text,
    device_id smallint,
    device_version text,
    login_platform_source smallint,
    profanity_status smallint,
    preferences_saved boolean,
    user_properties text,
    user_preferences text,
    opt_in text,
    created_date timestamp,
    updated_date timestamp,
    registered_date timestamp,
    PRIMARY KEY (partition_id, user_id)
) WITH COMMENT = 'Users partitioned by source_id hash, clustered by user_id'
  AND compaction = {
    'class': 'IncrementalCompactionStrategy',
    'sstable_size_in_mb': 1024
  }
  AND compression = {'sstable_compression': 'LZ4Compressor'}
  AND caching = {'keys': 'ALL', 'rows_per_partition': '100'};

-- User lookup table with ScyllaDB optimization
CREATE TABLE IF NOT EXISTS users_by_source (
    partition_id smallint,
    source_id text,
    user_id bigint,
    user_guid uuid,
    login_platform_source smallint,
    created_date timestamp,
    PRIMARY KEY (partition_id, source_id)
) WITH COMMENT = 'Lookup table for source_id → user_id mapping'
  AND compaction = {
    'class': 'IncrementalCompactionStrategy',
    'sstable_size_in_mb': 512
  }
  AND compression = {'sstable_compression': 'LZ4Compressor'}
  AND caching = {'keys': 'ALL', 'rows_per_partition': '10'};

-- --------------------------------------------------------------------
-- 3. USER TEAM MANAGEMENT with ScyllaDB optimizations
-- --------------------------------------------------------------------

-- Latest team state table
CREATE TABLE IF NOT EXISTS user_teams_latest (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    team_no smallint,
    current_gameset_id smallint,
    current_gameday_id smallint,
    team_name text,
    upper_team_name text,
    profanity_status smallint,
    profanity_updated_date timestamp,
    team_valuation decimal,
    remaining_budget decimal,
    captain_player_id int,
    vice_captain_player_id int,
    inplay_entities text,
    reserved_entities text,
    booster_id smallint,
    booster_player_id int,
    booster_team_players text,
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    substitution_allowed smallint,
    substitution_made smallint,
    substitution_left smallint,
    total_points decimal,
    current_rank int,
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket), user_id, team_no)
) WITH COMMENT = 'Latest team state for fast current gameset queries'
  AND compaction = {
    'class': 'IncrementalCompactionStrategy',
    'sstable_size_in_mb': 1024
  }
  AND compression = {'sstable_compression': 'LZ4Compressor'}
  AND caching = {'keys': 'ALL', 'rows_per_partition': '20'}
  AND bloom_filter_fp_chance = 0.01;

-- Historical team snapshots
CREATE TABLE IF NOT EXISTS user_team_details (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    season_id smallint,
    team_no smallint,
    gameset_id smallint,
    gameday_id smallint,
    from_gameset_id smallint,
    from_gameday_id smallint,
    to_gameset_id smallint,
    to_gameday_id smallint,
    team_valuation decimal,
    remaining_budget decimal,
    captain_player_id int,
    vice_captain_player_id int,
    inplay_entities text,
    reserved_entities text,
    team_formation text,
    booster_id smallint,
    booster_player_id int,
    booster_team_players text,
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    substitution_allowed smallint,
    substitution_made smallint,
    substitution_left smallint,
    gameset_points decimal,
    gameset_rank int,
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket, gameset_id), user_id, team_no, gameday_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, gameday_id DESC)
  AND COMMENT = 'Historical team states by gameset for time-travel queries'
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'HOURS',
    'compaction_window_size': 24
  }
  AND compression = {'sstable_compression': 'LZ4Compressor'}
  AND caching = {'keys': 'ALL', 'rows_per_partition': '50'};

-- Transfer audit trail
CREATE TABLE IF NOT EXISTS user_team_transfers (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    season_id smallint,
    team_no smallint,
    transfer_id uuid,
    gameset_id smallint,
    gameday_id smallint,
    action_type text,
    booster_id smallint,
    booster_player_id int,
    entities_in text,
    entities_out text,
    original_team_players text,
    new_team_players text,
    transfers_made smallint,
    transfer_cost decimal,
    transfer_metadata text,
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket, gameset_id), user_id, team_no, transfer_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, transfer_id DESC)
  AND COMMENT = 'Complete audit trail for transfers & substitutions'
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'DAYS',
    'compaction_window_size': 7
  }
  AND compression = {'sstable_compression': 'LZ4Compressor'}
  AND caching = {'keys': 'ALL', 'rows_per_partition': '100'};

-- --------------------------------------------------------------------
-- ScyllaDB-specific performance optimizations
-- --------------------------------------------------------------------

-- Create secondary indexes for common queries
CREATE INDEX IF NOT EXISTS idx_users_source_id ON users (source_id);
CREATE INDEX IF NOT EXISTS idx_teams_gameset ON user_teams_latest (current_gameset_id);

DESCRIBE KEYSPACE fantasy_game;

-- Script completed with ScyllaDB optimizations
