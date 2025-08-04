-- ====================================================================
-- CASSANDRA MIGRATION: TIME-SERIES & PERFORMANCE TABLES
-- ====================================================================
-- Optimized for high-frequency writes and time-based queries
-- These tables handle player stats, fixtures, and performance metrics

-- Fixtures - Time-series data ordered by datetime
-- Query Pattern: Get fixtures by season/gameset/gameday, get fixtures by datetime range
CREATE TABLE fixtures (
    season_id smallint,
    fixture_date text, -- YYYY-MM-DD for partitioning by day
    fixture_datetime_iso8601 timestamp,
    fixture_id int,
    source_id text,
    gameset_id smallint,
    gameday_id smallint,
    phase_id smallint,
    series_id text,
    fixture_name text,
    fixture_display_name text,
    fixture_file text,
    fixture_number text,
    fixture_status smallint,
    fixture_format text,
    venue_id int,
    lineup_announced boolean,
    sport_properties text,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((season_id, fixture_date), fixture_datetime_iso8601, fixture_id)
) WITH CLUSTERING ORDER BY (fixture_datetime_iso8601 ASC, fixture_id ASC)
AND COMMENT = 'Fixtures partitioned by season and date for time-series queries';

-- Fixtures by gameset - for gameset-specific queries
CREATE TABLE fixtures_by_gameset (
    season_id smallint,
    gameset_id smallint,
    gameday_id smallint,
    fixture_datetime_iso8601 timestamp,
    fixture_id int,
    fixture_name text,
    fixture_status smallint,
    venue_id int,
    lineup_announced boolean,
    sport_properties text,
    PRIMARY KEY ((season_id, gameset_id), gameday_id, fixture_datetime_iso8601, fixture_id)
) WITH CLUSTERING ORDER BY (gameday_id ASC, fixture_datetime_iso8601 ASC, fixture_id ASC)
AND COMMENT = 'Fixtures by gameset for efficient gameset queries';

-- Player Performance Data - Core time-series table
-- Query Pattern: Get player stats by gameset, get player progression over time
CREATE TABLE gameset_player_stats (
    season_id smallint,
    gameset_id smallint,
    player_id int,
    skill_id smallint,
    team_id int,
    player_value decimal,
    valuation_change decimal,
    is_active boolean,
    selection_percentage decimal,
    availability_status smallint,
    points decimal,
    player_stats text, -- JSON containing detailed stats
    fixture_performances text, -- JSON array of fixture-level stats
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((season_id, gameset_id), points, player_id)
) WITH CLUSTERING ORDER BY (points DESC, player_id ASC)
AND COMMENT = 'Player stats by gameset ordered by points for leaderboard queries';

-- Player Stats by Player - for individual player progression
CREATE TABLE player_stats_timeline (
    season_id smallint,
    player_id int,
    gameset_id smallint,
    points decimal,
    player_value decimal,
    valuation_change decimal,
    selection_percentage decimal,
    availability_status smallint,
    player_stats text,
    updated_date timestamp,
    PRIMARY KEY ((season_id, player_id), gameset_id)
) WITH CLUSTERING ORDER BY (gameset_id DESC)
AND COMMENT = 'Player performance timeline for individual player analysis';

-- Team Stats by Gameset
CREATE TABLE team_stats_by_gameset (
    season_id smallint,
    gameset_id smallint,
    team_id int,
    team_performance text, -- JSON with team-level stats
    total_team_points decimal,
    average_player_points decimal,
    best_performer_id int,
    worst_performer_id int,
    updated_date timestamp,
    PRIMARY KEY ((season_id, gameset_id), total_team_points, team_id)
) WITH CLUSTERING ORDER BY (total_team_points DESC, team_id ASC)
AND COMMENT = 'Team performance by gameset for team analysis';

-- Point Calculation Tables
CREATE TABLE entity_stats (
    sport_id smallint,
    stat_id smallint,
    stat_name text,
    calculation_type text,
    PRIMARY KEY (sport_id, stat_id)
) WITH COMMENT = 'Entity stats configuration by sport';

-- Live Point Updates - High-frequency writes during matches
CREATE TABLE live_player_points (
    season_id smallint,
    fixture_id int,
    update_timestamp timestamp,
    player_id int,
    current_points decimal,
    point_breakdown text, -- JSON with stat-wise points
    is_final boolean,
    PRIMARY KEY ((season_id, fixture_id), update_timestamp, player_id)
) WITH CLUSTERING ORDER BY (update_timestamp DESC, player_id ASC)
AND default_time_to_live = 604800 -- 7 days TTL for live data
AND COMMENT = 'Live point updates during fixtures with TTL for cleanup';

-- Player Value History - for tracking player value changes
CREATE TABLE player_value_history (
    season_id smallint,
    player_id int,
    gameset_id smallint,
    value_date timestamp,
    old_value decimal,
    new_value decimal,
    value_change decimal,
    reason text, -- 'performance', 'selection', 'manual' etc.
    PRIMARY KEY ((season_id, player_id), gameset_id, value_date)
) WITH CLUSTERING ORDER BY (gameset_id DESC, value_date DESC)
AND COMMENT = 'Player value change history for valuation tracking';

-- ====================================================================
-- LOG TABLES with TTL
-- ====================================================================

-- Engine Error Logs
CREATE TABLE engine_error_logs (
    log_date text, -- YYYY-MM-DD for partitioning
    error_time timestamp,
    error_id uuid,
    error_message text,
    error_code text,
    error_data text, -- JSON
    function_name text,
    PRIMARY KEY (log_date, error_time, error_id)
) WITH CLUSTERING ORDER BY (error_time DESC, error_id ASC)
AND default_time_to_live = 2592000 -- 30 days TTL
AND COMMENT = 'Engine error logs with 30-day TTL';

-- Gameplay Error Logs
CREATE TABLE gameplay_error_logs (
    log_date text,
    error_time timestamp,
    error_id uuid,
    error_message text,
    error_code text,
    error_data text,
    function_name text,
    user_id bigint,
    season_id smallint,
    PRIMARY KEY (log_date, error_time, error_id)
) WITH CLUSTERING ORDER BY (error_time DESC, error_id ASC)
AND default_time_to_live = 2592000 -- 30 days TTL
AND COMMENT = 'Gameplay error logs with 30-day TTL';

-- Point Submission Logs
CREATE TABLE point_submission_logs (
    season_id smallint,
    submission_date text, -- YYYY-MM-DD
    gameset_id smallint,
    fixture_id int,
    submission_time timestamp,
    submission_id uuid,
    points_data text, -- JSON
    status text, -- 'success', 'failed', 'partial'
    error_details text,
    PRIMARY KEY ((season_id, submission_date), gameset_id, fixture_id, submission_time)
) WITH CLUSTERING ORDER BY (gameset_id ASC, fixture_id ASC, submission_time DESC)
AND default_time_to_live = 7776000 -- 90 days TTL
AND COMMENT = 'Point submission audit trail with 90-day TTL';

-- User Activity Logs - for analytics and debugging
CREATE TABLE user_activity_logs (
    activity_date text, -- YYYY-MM-DD for partitioning
    user_id bigint,
    activity_time timestamp,
    activity_id uuid,
    activity_type text, -- 'login', 'team_save', 'transfer', etc.
    season_id smallint,
    details text, -- JSON with activity details
    device_id smallint,
    ip_address inet,
    PRIMARY KEY ((activity_date, user_id), activity_time, activity_id)
) WITH CLUSTERING ORDER BY (activity_time DESC, activity_id ASC)
AND default_time_to_live = 7776000 -- 90 days TTL
AND COMMENT = 'User activity tracking with 90-day TTL';

-- ====================================================================
-- DENORMALIZED PERFORMANCE TABLES
-- ====================================================================

-- Top Performers by Gameset - Precomputed for leaderboards
CREATE TABLE top_performers_by_gameset (
    season_id smallint,
    gameset_id smallint,
    skill_id smallint,
    rank int,
    player_id int,
    player_name text,
    team_id int,
    team_name text,
    points decimal,
    player_value decimal,
    selection_percentage decimal,
    updated_date timestamp,
    PRIMARY KEY ((season_id, gameset_id, skill_id), rank)
) WITH CLUSTERING ORDER BY (rank ASC)
AND COMMENT = 'Precomputed top performers for fast leaderboard queries';

-- Player Selection Trends
CREATE TABLE player_selection_trends (
    season_id smallint,
    player_id int,
    trend_date text, -- YYYY-MM-DD
    gameset_id smallint,
    total_selections bigint,
    total_users bigint,
    selection_percentage decimal,
    rank_in_skill int,
    trend_direction text, -- 'increasing', 'decreasing', 'stable'
    PRIMARY KEY ((season_id, player_id), trend_date)
) WITH CLUSTERING ORDER BY (trend_date DESC)
AND default_time_to_live = 31536000 -- 365 days TTL
AND COMMENT = 'Player selection trends for popularity analysis';

-- Season Summary Stats - Precomputed season totals
CREATE TABLE season_summary_stats (
    season_id smallint,
    stat_type text, -- 'total_users', 'total_teams', 'total_points', etc.
    stat_value bigint,
    stat_details text, -- JSON with breakdown
    last_updated timestamp,
    PRIMARY KEY (season_id, stat_type)
) WITH COMMENT = 'Precomputed season-level statistics for dashboards'; 