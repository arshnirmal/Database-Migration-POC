-- ====================================================================
-- CASSANDRA MIGRATION: LEADERBOARD & LEAGUE TABLES
-- ====================================================================
-- Optimized for ranking queries, social features, and competitive gameplay
-- These tables handle leaderboards, leagues, and user competitions

-- League Configuration Tables

-- League Presets
CREATE TABLE league_presets (
    preset_id smallint,
    preset_name text,
    preset_config text, -- JSON
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (preset_id)
) WITH COMMENT = 'League preset configurations';

-- League Scoring Types
CREATE TABLE league_scoring_types (
    scoring_type_id smallint,
    scoring_type_name text,
    created_at timestamp,
    updated_at timestamp,
    PRIMARY KEY (scoring_type_id)
) WITH COMMENT = 'League scoring type definitions';

-- League Tags
CREATE TABLE league_tags (
    tag_id smallint,
    tag_name text,
    PRIMARY KEY (tag_id)
) WITH COMMENT = 'League tag definitions';

-- League Member Status
CREATE TABLE league_member_statuses (
    status_id smallint,
    status_name text,
    PRIMARY KEY (status_id)
) WITH COMMENT = 'League member status definitions';

-- League Types - Core league configuration
CREATE TABLE league_types (
    season_id smallint,
    league_type_id smallint,
    league_type_name text,
    preset_id smallint,
    scoring_type_id smallint,
    leaderboard_visibility text,
    join_visibility text,
    auto_spawn_league boolean,
    auto_join_league boolean,
    users_can_create_league boolean,
    users_select_game_set boolean,
    users_set_team_cap boolean,
    unlimited_max_entry_cap boolean,
    users_set_max_entry_cap boolean,
    league_properties text, -- JSON
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (season_id, league_type_id)
) WITH COMMENT = 'League type configurations by season';

-- Leagues - Main league data partitioned by type for scalability
CREATE TABLE leagues (
    league_type_id smallint,
    season_id smallint,
    league_id bigint,
    league_name text,
    league_code text,
    social_id text,
    manager_user_id bigint,
    active_gameset_ids set<smallint>,
    join_lock_timestamp timestamp,
    join_lock_gameset_id smallint,
    maximum_team_count bigint,
    teams_per_user smallint,
    platform_id smallint,
    platform_version text,
    tag_ids set<smallint>,
    is_system_league boolean,
    total_team_count bigint,
    total_user_count bigint,
    is_locked boolean,
    is_deleted boolean,
    profane_flag text,
    profane_updated_date timestamp,
    banner_image_url text,
    banner_url text,
    partition_id smallint,
    created_date timestamp,
    updated_date timestamp,
    input_json text, -- Original input as JSON
    PRIMARY KEY ((league_type_id, season_id), league_id)
) WITH COMMENT = 'Leagues partitioned by type and season for efficient access';

-- League lookup by code - for join operations
CREATE TABLE leagues_by_code (
    league_code text,
    season_id smallint,
    league_type_id smallint,
    league_id bigint,
    league_name text,
    manager_user_id bigint,
    is_locked boolean,
    is_deleted boolean,
    maximum_team_count bigint,
    total_team_count bigint,
    join_lock_timestamp timestamp,
    PRIMARY KEY (league_code)
) WITH COMMENT = 'League lookup by code for join operations';

-- League Members - User participation in leagues
CREATE TABLE league_members (
    league_type_id smallint,
    season_id smallint,
    league_id bigint,
    user_id bigint,
    partition_id smallint,
    social_id text,
    user_name text,
    team_no smallint,
    team_name text,
    is_manager boolean,
    join_gameset_id smallint,
    join_timestamp timestamp,
    member_status smallint,
    disjoin_gameset_id smallint,
    disjoin_timestamp timestamp,
    platform_id smallint,
    platform_version text,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((league_type_id, season_id, league_id), user_id, team_no)
) WITH COMMENT = 'League memberships partitioned by league for efficient queries';

-- User League Mapping - User's perspective of league participation
CREATE TABLE user_league_map (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    league_code text,
    league_type_id smallint,
    league_id bigint,
    league_shard_id smallint,
    teams_data text, -- JSON with team information
    join_date timestamp,
    is_active boolean,
    PRIMARY KEY ((season_id, partition_id), user_id, league_code)
) WITH COMMENT = 'User league participation from user perspective';

-- ====================================================================
-- LEADERBOARD TABLES - HIGH PERFORMANCE RANKINGS
-- ====================================================================

-- Global Leaderboard - Overall season rankings
CREATE TABLE global_leaderboard (
    season_id smallint,
    leaderboard_type text, -- 'overall', 'weekly', 'monthly'
    rank bigint,
    user_id bigint,
    partition_id smallint,
    user_name text,
    team_no smallint,
    team_name text,
    total_points decimal,
    avg_points decimal,
    best_gameset_points decimal,
    worst_gameset_points decimal,
    total_transfers smallint,
    rank_change int, -- compared to previous period
    trend text, -- 'up', 'down', 'same'
    updated_date timestamp,
    PRIMARY KEY ((season_id, leaderboard_type), rank)
) WITH CLUSTERING ORDER BY (rank ASC)
AND COMMENT = 'Global leaderboards ordered by rank for efficient top-N queries';

-- League Leaderboards - Rankings within specific leagues
CREATE TABLE league_leaderboards (
    league_type_id smallint,
    season_id smallint,
    league_id bigint,
    scoring_period text, -- 'overall', 'gameset_X', 'weekly'
    rank int,
    user_id bigint,
    team_no smallint,
    user_name text,
    team_name text,
    points decimal,
    rank_change int,
    trend text,
    gameset_breakdown text, -- JSON with gameset-wise points
    updated_date timestamp,
    PRIMARY KEY ((league_type_id, season_id, league_id, scoring_period), rank)
) WITH CLUSTERING ORDER BY (rank ASC)
AND COMMENT = 'League-specific leaderboards for competitive rankings';

-- User Rankings History - Track user rank progression
CREATE TABLE user_rankings_history (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    team_no smallint,
    ranking_date text, -- YYYY-MM-DD
    gameset_id smallint,
    global_rank bigint,
    points decimal,
    rank_change int,
    percentile decimal,
    leagues_data text, -- JSON array of league rankings
    PRIMARY KEY ((season_id, partition_id), user_id, team_no, ranking_date)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, ranking_date DESC)
AND default_time_to_live = 31536000 -- 365 days TTL
AND COMMENT = 'User ranking history for trend analysis with 1-year TTL';

-- Top Teams by Gameset - Fastest leaderboard queries
CREATE TABLE top_teams_by_gameset (
    season_id smallint,
    gameset_id smallint,
    rank int,
    user_id bigint,
    team_no smallint,
    partition_id smallint,
    team_name text,
    user_name text,
    points decimal,
    captain_player_id int,
    vice_captain_player_id int,
    total_transfers smallint,
    team_valuation decimal,
    updated_date timestamp,
    PRIMARY KEY ((season_id, gameset_id), rank)
) WITH CLUSTERING ORDER BY (rank ASC)
AND COMMENT = 'Precomputed top teams by gameset for fast leaderboard APIs';

-- League Activity Feed - Social features
CREATE TABLE league_activity_feed (
    league_type_id smallint,
    season_id smallint,
    league_id bigint,
    activity_date text, -- YYYY-MM-DD for partitioning
    activity_timestamp timestamp,
    activity_id uuid,
    activity_type text, -- 'join', 'transfer', 'rank_change', 'points_update'
    user_id bigint,
    user_name text,
    team_name text,
    activity_description text,
    activity_data text, -- JSON with details
    PRIMARY KEY ((league_type_id, season_id, league_id, activity_date), activity_timestamp, activity_id)
) WITH CLUSTERING ORDER BY (activity_timestamp DESC, activity_id ASC)
AND default_time_to_live = 7776000 -- 90 days TTL
AND COMMENT = 'League activity feeds with TTL for social engagement';

-- ====================================================================
-- DENORMALIZED RANKING TABLES FOR PERFORMANCE
-- ====================================================================

-- User Performance Summary - Aggregated user stats
CREATE TABLE user_performance_summary (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    total_teams smallint,
    best_team_rank bigint,
    best_team_points decimal,
    avg_team_rank decimal,
    avg_team_points decimal,
    total_transfers int,
    successful_transfers int,
    leagues_joined int,
    leagues_won int,
    overall_percentile decimal,
    consistency_score decimal, -- measure of performance consistency
    favorite_formation text, -- JSON
    most_selected_players list<int>,
    updated_date timestamp,
    PRIMARY KEY ((season_id, partition_id), user_id)
) WITH COMMENT = 'User performance aggregations for profile and analytics';

-- Team Performance Comparison - Head-to-head data
CREATE TABLE team_performance_comparison (
    season_id smallint,
    user1_id bigint,
    team1_no smallint,
    user2_id bigint,
    team2_no smallint,
    comparison_period text, -- 'overall', 'last_5_gamesets', etc.
    user1_points decimal,
    user2_points decimal,
    user1_wins int,
    user2_wins int,
    draws int,
    head_to_head_history text, -- JSON array
    last_compared timestamp,
    PRIMARY KEY ((season_id, user1_id, team1_no), user2_id, team2_no, comparison_period)
) WITH COMMENT = 'Head-to-head team comparisons for social features';

-- Popular Players by Period - Trending players
CREATE TABLE popular_players_by_period (
    season_id smallint,
    period_type text, -- 'daily', 'weekly', 'gameset'
    period_value text, -- '2024-01-15', 'week_3', 'gameset_5'
    popularity_rank int,
    player_id int,
    player_name text,
    team_id int,
    team_name text,
    skill_id smallint,
    selection_count bigint,
    selection_percentage decimal,
    captain_count bigint,
    vice_captain_count bigint,
    total_points decimal,
    avg_points decimal,
    trend_direction text,
    PRIMARY KEY ((season_id, period_type, period_value), popularity_rank)
) WITH CLUSTERING ORDER BY (popularity_rank ASC)
AND COMMENT = 'Popular player rankings by time period';

-- League Statistics Summary
CREATE TABLE league_statistics_summary (
    league_type_id smallint,
    season_id smallint,
    league_id bigint,
    stat_type text, -- 'member_count', 'avg_points', 'total_transfers', etc.
    stat_period text, -- 'overall', 'weekly', 'monthly'
    stat_value decimal,
    rank_among_leagues int,
    percentile decimal,
    stat_details text, -- JSON with breakdown
    updated_date timestamp,
    PRIMARY KEY ((league_type_id, season_id, league_id), stat_type, stat_period)
) WITH COMMENT = 'League-level statistics for league management and analytics'; 