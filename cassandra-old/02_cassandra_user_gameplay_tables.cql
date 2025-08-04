-- ====================================================================
-- CASSANDRA MIGRATION: USER & GAMEPLAY TABLES
-- ====================================================================
-- High-volume tables optimized for user and gameplay operations
-- These tables handle the core game functionality with heavy read/write loads

-- Users Table - Optimized for lookups by source_id and user_guid
CREATE TABLE users (
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
    created_date timestamp,
    updated_date timestamp,
    registered_date timestamp,
    opt_in text, -- JSON as text
    user_properties text, -- JSON as text
    user_preferences text, -- JSON as text
    profanity_status smallint,
    PRIMARY KEY (partition_id, user_id)
) WITH COMMENT = 'Users partitioned by partition_id for horizontal scaling';

-- Secondary table for user lookup by source_id (critical for session APIs)
CREATE TABLE users_by_source_id (
    source_id text,
    partition_id smallint,
    user_id bigint,
    user_guid uuid,
    user_name text,
    device_id smallint,
    login_platform_source smallint,
    profanity_status smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (source_id)
) WITH COMMENT = 'User lookup by source_id - enables fast session creation';

-- User lookup by GUID (for API endpoints using guid)
CREATE TABLE users_by_guid (
    user_guid uuid,
    partition_id smallint,
    user_id bigint,
    source_id text,
    PRIMARY KEY (user_guid)
) WITH COMMENT = 'User lookup by GUID for API endpoints';

-- User Teams - Core fantasy team data
-- Query Pattern: Get all teams for a user in a season, get team by team_no
CREATE TABLE user_teams (
    season_id smallint,
    user_id bigint,
    team_no smallint,
    team_name text,
    upper_team_name text,
    gameset_id smallint,
    gameday_id smallint,
    profanity_status smallint,
    profanity_updated_date timestamp,
    partition_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id), user_id, team_no)
) WITH COMMENT = 'User teams partitioned by season and user partition for efficient queries';

-- User Team Details - Time-series data for team evolution
-- Query Pattern: Get latest team for user/team, get team for specific gameset/gameday
CREATE TABLE user_team_details (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    team_no smallint,
    gameset_id smallint,
    gameday_id smallint,
    from_gameset_id smallint,
    from_gameday_id smallint,
    to_gameset_id smallint,
    to_gameday_id smallint,
    team_valuation decimal,
    remaining_budget decimal,
    team_players set<int>, -- Cassandra set for player IDs
    captain_player_id int,
    vice_captain_player_id int,
    team_json text, -- JSON as text
    substitution_allowed smallint,
    substitution_made smallint,
    substitution_left smallint,
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    booster_id smallint,
    booster_player_id int,
    booster_team_players set<int>,
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id), user_id, team_no, gameset_id, gameday_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, gameset_id DESC, gameday_id DESC)
AND COMMENT = 'Team details with time-series clustering for latest-first retrieval';

-- Latest Team Details View - Denormalized for fast "current team" queries
CREATE TABLE user_team_latest (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    team_no smallint,
    latest_gameset_id smallint,
    latest_gameday_id smallint,
    team_name text,
    team_valuation decimal,
    remaining_budget decimal,
    team_players set<int>,
    captain_player_id int,
    vice_captain_player_id int,
    team_json text,
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    total_points decimal,
    overall_rank int,
    updated_date timestamp,
    PRIMARY KEY ((season_id, partition_id), user_id, team_no)
) WITH COMMENT = 'Latest team state for fast user summary queries - updated on each team change';

-- User Team Transfer History - Audit trail for transfers
CREATE TABLE user_team_transfers (
    season_id smallint,
    partition_id smallint,
    user_id bigint,
    team_no smallint,
    transfer_id uuid,
    gameset_id smallint,
    gameday_id smallint,
    booster_id smallint,
    original_team_players list<int>,
    players_out list<int>,
    players_in list<int>,
    new_team_players list<int>,
    transfers_made smallint,
    transfer_json text,
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((season_id, partition_id), user_id, team_no, transfer_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, transfer_id DESC)
AND COMMENT = 'Transfer history partitioned by season for audit trails';

-- Game Management Tables

-- Teams
CREATE TABLE teams (
    season_id smallint,
    team_id int,
    source_id text,
    series_id text,
    team_name text,
    team_display_name text,
    team_short_code text,
    sport_properties text, -- JSON as text
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (season_id, team_id)
) WITH COMMENT = 'Teams by season - enables efficient team lookups per season';

-- Venues
CREATE TABLE venues (
    season_id smallint,
    venue_id int,
    source_id text,
    location1 text,
    location1_display_name text,
    location2 text,
    location2_display_name text,
    location3 text,
    location3_display_name text,
    sport_properties text,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (season_id, venue_id)
) WITH COMMENT = 'Venues by season for location information';

-- Phases
CREATE TABLE phases (
    season_id smallint,
    phase_id smallint,
    phase_name text,
    PRIMARY KEY (season_id, phase_id)
) WITH COMMENT = 'Phases by season for tournament structure';

-- Gamesets
CREATE TABLE gamesets (
    season_id smallint,
    gameset_id smallint,
    phase_id smallint,
    gameset_name text,
    transfer_lock_offset text, -- Duration as text
    transfer_unlock_offset text,
    PRIMARY KEY (season_id, gameset_id)
) WITH COMMENT = 'Gamesets by season for tournament rounds';

-- Gamedays
CREATE TABLE gamedays (
    season_id smallint,
    gameset_id smallint,
    gameday_id smallint,
    gameday_name text,
    substitution_lock_offset text,
    substitution_unlock_offset text,
    PRIMARY KEY (season_id, gameset_id, gameday_id)
) WITH COMMENT = 'Gamedays by season and gameset for daily events';

-- Players - Core player data
-- Query Pattern: Get players by season, get players by team, get player by id
CREATE TABLE players (
    season_id smallint,
    player_id int,
    source_id text,
    series_id text,
    team_id int,
    player_name text,
    player_display_name text,
    player_short_name text,
    skill_id smallint,
    player_value decimal,
    is_foreign_player boolean,
    is_active boolean,
    sport_properties text,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (season_id, player_id)
) WITH COMMENT = 'Players by season - main player lookup table';

-- Players by team - for team-based queries
CREATE TABLE players_by_team (
    season_id smallint,
    team_id int,
    skill_id smallint,
    player_id int,
    player_name text,
    player_display_name text,
    player_value decimal,
    is_active boolean,
    is_foreign_player boolean,
    PRIMARY KEY ((season_id, team_id), skill_id, player_id)
) WITH COMMENT = 'Players by team and skill for team selection queries';

-- Players by skill - for formation-based queries
CREATE TABLE players_by_skill (
    season_id smallint,
    skill_id smallint,
    player_value decimal,
    player_id int,
    team_id int,
    player_name text,
    is_active boolean,
    is_foreign_player boolean,
    PRIMARY KEY ((season_id, skill_id), player_value, player_id)
) WITH CLUSTERING ORDER BY (player_value DESC, player_id ASC)
AND COMMENT = 'Players by skill ordered by value for position-based selection';

-- ====================================================================
-- TTL Tables for Session Management
-- ====================================================================

-- User Sessions with TTL
CREATE TABLE user_sessions (
    user_guid uuid,
    session_token text,
    device_id smallint,
    login_platform_source smallint,
    created_at timestamp,
    expires_at timestamp,
    session_data text, -- JSON as text
    PRIMARY KEY (user_guid)
) WITH default_time_to_live = 86400 -- 24 hours TTL
AND COMMENT = 'User sessions with automatic expiry after 24 hours'; 