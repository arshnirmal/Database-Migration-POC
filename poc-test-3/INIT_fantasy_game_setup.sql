-- ================================================================
-- CockroachDB Fantasy Game Database Initialization Script
-- Physical Sharding: 3 shards × 10 partitions = 30 total partitions
-- ================================================================

-- Create the main database and schemas
CREATE DATABASE IF NOT EXISTS fantasy_game;

USE fantasy_game;

CREATE SCHEMA IF NOT EXISTS game_user;
CREATE SCHEMA IF NOT EXISTS gameplay;
CREATE SCHEMA IF NOT EXISTS engine_config;

-- ================================================================
-- REFERENCE TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS engine_config.device (
    device_id SMALLINT PRIMARY KEY,
    device_name STRING
);

CREATE TABLE IF NOT EXISTS engine_config.platform (
    platform_id SMALLINT PRIMARY KEY,
    platform_name STRING
);

CREATE TABLE IF NOT EXISTS engine_config.profanity_status (
    status_id SMALLINT PRIMARY KEY,
    status_name STRING
);

-- ================================================================
-- SEQUENCES
-- ================================================================

CREATE SEQUENCE IF NOT EXISTS game_user.user_id_seq START 1000000;

-- ================================================================
-- MAIN TABLES WITH PHYSICAL SHARDING
-- ================================================================

-- Users table - 3 physical shards with 10 partitions each
CREATE TABLE IF NOT EXISTS game_user.users (
    user_id NUMERIC NOT NULL DEFAULT nextval('game_user.user_id_seq'),
    source_id STRING(150) NOT NULL,
    first_name STRING(100),
    last_name STRING(100),
    user_name STRING(150),
    device_id SMALLINT NOT NULL,
    device_version STRING(10),
    login_platform_source SMALLINT NOT NULL,
    created_date TIMESTAMPTZ NOT NULL,
    updated_date TIMESTAMPTZ NOT NULL,
    registered_date TIMESTAMPTZ NOT NULL,
    partition_id SMALLINT NOT NULL,
    user_guid UUID DEFAULT gen_random_uuid (),
    opt_in JSONB,
    user_properties JSONB,
    user_preferences JSONB,
    profanity_status SMALLINT DEFAULT 1,
    PRIMARY KEY (partition_id, user_id),
    UNIQUE (source_id, partition_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    PARTITION shard_1 VALUES IN (10, 11, 12, 13, 14, 15, 16, 17, 18, 19),
    PARTITION shard_2 VALUES IN (20, 21, 22, 23, 24, 25, 26, 27, 28, 29)
);

-- User teams table
CREATE TABLE IF NOT EXISTS gameplay.user_teams (
    user_id NUMERIC NOT NULL,
    team_no SMALLINT NOT NULL,
    team_name STRING(250),
    upper_team_name STRING(250),
    season_id SMALLINT NOT NULL,
    gameset_id SMALLINT,
    gameday_id SMALLINT,
    profanity_status SMALLINT DEFAULT 1,
    profanity_updated_date TIMESTAMPTZ,
    partition_id SMALLINT NOT NULL,
    created_date TIMESTAMPTZ DEFAULT now(),
    updated_date TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (partition_id, season_id, user_id, team_no),
    UNIQUE (season_id, team_name, partition_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    PARTITION shard_1 VALUES IN (10, 11, 12, 13, 14, 15, 16, 17, 18, 19),
    PARTITION shard_2 VALUES IN (20, 21, 22, 23, 24, 25, 26, 27, 28, 29)
);

-- User team detail table
CREATE TABLE IF NOT EXISTS gameplay.user_team_detail (
    season_id SMALLINT NOT NULL,
    user_id NUMERIC NOT NULL,
    team_no SMALLINT NOT NULL,
    gameset_id SMALLINT NOT NULL,
    gameday_id SMALLINT NOT NULL,
    from_gameset_id SMALLINT,
    from_gameday_id SMALLINT,
    to_gameset_id SMALLINT,
    to_gameday_id SMALLINT,
    team_valuation DECIMAL(10, 2),
    remaining_budget DECIMAL(10, 2),
    team_players INT[],
    captain_player_id INT,
    vice_captain_player_id INT,
    team_json JSONB,
    substitution_allowed SMALLINT DEFAULT 5,
    substitution_made SMALLINT DEFAULT 0,
    substitution_left SMALLINT DEFAULT 5,
    transfers_allowed SMALLINT DEFAULT 5,
    transfers_made SMALLINT DEFAULT 0,
    transfers_left SMALLINT DEFAULT 5,
    booster_id SMALLINT,
    booster_player_id INT,
    booster_team_players INT[],
    partition_id SMALLINT NOT NULL,
    created_date TIMESTAMPTZ DEFAULT now(),
    updated_date TIMESTAMPTZ DEFAULT now(),
    device_id SMALLINT,
    PRIMARY KEY (partition_id, season_id, user_id, team_no, gameset_id, gameday_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    PARTITION shard_1 VALUES IN (10, 11, 12, 13, 14, 15, 16, 17, 18, 19),
    PARTITION shard_2 VALUES IN (20, 21, 22, 23, 24, 25, 26, 27, 28, 29)
);

-- Transfer details table
CREATE TABLE IF NOT EXISTS gameplay.user_team_booster_transfer_detail (
    season_id SMALLINT NOT NULL,
    transfer_id UUID NOT NULL DEFAULT gen_random_uuid (),
    user_id NUMERIC NOT NULL,
    team_no SMALLINT NOT NULL,
    gameset_id SMALLINT NOT NULL,
    gameday_id SMALLINT NOT NULL,
    booster_id SMALLINT NOT NULL,
    original_team_players INT[],
    players_out INT[],
    players_in INT[],
    new_team_players INT[],
    transfers_made SMALLINT,
    transfer_json JSONB,
    created_date TIMESTAMPTZ DEFAULT now(),
    updated_date TIMESTAMPTZ DEFAULT now(),
    device_id SMALLINT,
    partition_id SMALLINT NOT NULL,
    PRIMARY KEY (partition_id, season_id, user_id, team_no, gameset_id, gameday_id, transfer_id, booster_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
    PARTITION shard_1 VALUES IN (10, 11, 12, 13, 14, 15, 16, 17, 18, 19),
    PARTITION shard_2 VALUES IN (20, 21, 22, 23, 24, 25, 26, 27, 28, 29)
);

-- ================================================================
-- REFERENCE DATA POPULATION
-- ================================================================

-- Insert device data
INSERT INTO
    engine_config.device (device_id, device_name)
VALUES (1, 'iOS'),
    (2, 'Android'),
    (3, 'Web'),
    (4, 'Desktop')
ON CONFLICT DO NOTHING;

-- Insert platform data
INSERT INTO
    engine_config.platform (platform_id, platform_name)
VALUES (1, 'Facebook'),
    (2, 'Google'),
    (3, 'Apple'),
    (4, 'Twitter')
ON CONFLICT DO NOTHING;

-- Insert profanity status data
INSERT INTO
    engine_config.profanity_status (status_id, status_name)
VALUES (1, 'Clean'),
    (2, 'Flagged'),
    (3, 'Blocked')
ON CONFLICT DO NOTHING;

-- ================================================================
-- API FUNCTIONS
-- ================================================================

-- Function to calculate partition_id from source_id
CREATE OR REPLACE FUNCTION calculate_partition_id(source_id STRING)
RETURNS SMALLINT AS $$
BEGIN
    RETURN abs(fnv32(source_id::BYTES)) % 30;
END;
$$ LANGUAGE plpgsql;

-- User login function
CREATE OR REPLACE FUNCTION game_user.user_login(request_data JSONB)
RETURNS JSONB AS $$
DECLARE
    v_source_id STRING;
    v_device_id SMALLINT;
    v_login_platform_source SMALLINT;
    v_partition_id SMALLINT;
    v_response JSONB;
    v_current_time TIMESTAMPTZ := now();
    v_user_id NUMERIC;
    v_user_guid UUID;
    v_first_name STRING;
    v_last_name STRING;
    v_user_name STRING;
    v_profanity_status SMALLINT;
    v_user_properties JSONB;
    v_user_preferences JSONB;
BEGIN
    -- Extract request parameters
    v_source_id := request_data->>'source_id';
    v_device_id := (request_data->>'device_id')::SMALLINT;
    v_login_platform_source := (request_data->>'login_platform_source')::SMALLINT;
    
    -- Calculate partition_id based on source_id hash
    v_partition_id := calculate_partition_id(v_source_id);
    
    -- Check if user exists
    SELECT u.user_id, u.user_guid, u.first_name, u.last_name, u.user_name,
           u.profanity_status, u.user_properties, u.user_preferences
    INTO v_user_id, v_user_guid, v_first_name, v_last_name, v_user_name,
         v_profanity_status, v_user_properties, v_user_preferences
    FROM game_user.users u
    WHERE u.source_id = v_source_id AND u.partition_id = v_partition_id;
    
    IF v_user_id IS NOT NULL THEN
        -- User exists, return user details
        v_response := jsonb_build_object(
            'data', jsonb_build_object(
                'device_id', v_device_id,
                'guid', v_user_guid,
                'source_id', v_source_id,
                'user_name', v_user_name,
                'first_name', v_first_name,
                'last_name', v_last_name,
                'profanity_status', v_profanity_status,
                'preferences_saved', true,
                'login_platform_source', v_login_platform_source,
                'user_session', jsonb_build_object(
                    'game_token', '<jwt_token>',
                    'created_at', v_current_time,
                    'expires_at', v_current_time + interval '24 hours'
                ),
                'user_properties', COALESCE(v_user_properties, '[]'::jsonb),
                'user_preferences', COALESCE(v_user_preferences, '[]'::jsonb)
            ),
            'meta', jsonb_build_object(
                'retval', 1,
                'message', 'OK',
                'timestamp', v_current_time
            )
        );
    ELSE
        -- User doesn't exist, create new user
        INSERT INTO game_user.users (
            source_id, first_name, last_name, user_name,
            device_id, device_version, login_platform_source,
            created_date, updated_date, registered_date,
            partition_id, opt_in, user_properties, user_preferences,
            profanity_status
        ) VALUES (
            v_source_id, 
            COALESCE(request_data->>'first_name', 'User'),
            COALESCE(request_data->>'last_name', 'Player'),
            COALESCE(request_data->>'user_name', 'player_' || v_source_id),
            v_device_id, '1.0', v_login_platform_source,
            v_current_time, v_current_time, v_current_time,
            v_partition_id,
            COALESCE(request_data->'opt_in', '{"email": true, "sms": false}'::jsonb),
            COALESCE(request_data->'user_properties', '[]'::jsonb),
            COALESCE(request_data->'user_preferences', '[]'::jsonb),
            1
        ) RETURNING user_id, user_guid, first_name, last_name, user_name
        INTO v_user_id, v_user_guid, v_first_name, v_last_name, v_user_name;
        
        v_response := jsonb_build_object(
            'data', jsonb_build_object(
                'device_id', v_device_id,
                'guid', v_user_guid,
                'source_id', v_source_id,
                'user_name', v_user_name,
                'first_name', v_first_name,
                'last_name', v_last_name,
                'profanity_status', 1,
                'preferences_saved', true,
                'login_platform_source', v_login_platform_source,
                'user_session', jsonb_build_object(
                    'game_token', '<jwt_token>',
                    'created_at', v_current_time,
                    'expires_at', v_current_time + interval '24 hours'
                ),
                'user_properties', COALESCE(request_data->'user_properties', '[]'::jsonb),
                'user_preferences', COALESCE(request_data->'user_preferences', '[]'::jsonb)
            ),
            'meta', jsonb_build_object(
                'retval', 1,
                'message', 'OK',
                'timestamp', v_current_time
            )
        );
    END IF;
    
    RETURN v_response;
END;
$$ LANGUAGE plpgsql;

-- Save team function
CREATE OR REPLACE FUNCTION gameplay.save_team(request_data JSONB, p_user_id NUMERIC, p_partition_id SMALLINT)
RETURNS JSONB AS $$
DECLARE
    v_team_name STRING;
    v_gameset_id SMALLINT;
    v_gameday_id SMALLINT;
    v_device_id SMALLINT;
    v_team_no SMALLINT;
    v_current_time TIMESTAMPTZ := now();
    v_season_id SMALLINT := 2024;
    v_transfer_id UUID := gen_random_uuid();
    v_inplay_entities JSONB;
    v_reserved_entities JSONB;
    v_team_players INT[];
    v_captain_id INT;
    v_vice_captain_id INT;
    v_booster_id SMALLINT;
    v_booster_player_id INT;
    v_team_valuation DECIMAL(10,2) := 85.0;
    v_remaining_budget DECIMAL(10,2) := 15.0;
BEGIN
    -- Extract request parameters
    v_team_name := request_data->>'team_name';
    v_gameset_id := (request_data->'event_group'->>'gameset_id')::SMALLINT;
    v_gameday_id := (request_data->'event_group'->>'gameday_id')::SMALLINT;
    v_device_id := (request_data->>'device_id')::SMALLINT;
    v_captain_id := (request_data->>'captain_id')::INT;
    v_vice_captain_id := (request_data->>'vice_captain_id')::INT;
    v_booster_id := (request_data->'booster'->>'booster_id')::SMALLINT;
    v_booster_player_id := (request_data->'booster'->>'entity_id')::INT;
    v_inplay_entities := request_data->'inplay_entities';
    v_reserved_entities := request_data->'reserved_entities';
    
    -- Extract team players array
    SELECT array_agg((entity->>'entity_id')::INT)
    INTO v_team_players
    FROM jsonb_array_elements(v_inplay_entities) AS entity;
    
    -- Get next team number for user
    SELECT COALESCE(MAX(team_no), 0) + 1
    INTO v_team_no
    FROM gameplay.user_teams
    WHERE user_id = p_user_id AND partition_id = p_partition_id AND season_id = v_season_id;
    
    -- Insert into user_teams
    INSERT INTO gameplay.user_teams (
        user_id, team_no, team_name, upper_team_name, season_id,
        gameset_id, gameday_id, profanity_status, partition_id,
        created_date, updated_date
    ) VALUES (
        p_user_id, v_team_no, v_team_name, upper(v_team_name), v_season_id,
        v_gameset_id, v_gameday_id, 1, p_partition_id,
        v_current_time, v_current_time
    );
    
    -- Insert into user_team_detail
    INSERT INTO gameplay.user_team_detail (
        season_id, user_id, team_no, gameset_id, gameday_id,
        from_gameset_id, from_gameday_id, to_gameset_id, to_gameday_id,
        team_valuation, remaining_budget, team_players,
        captain_player_id, vice_captain_player_id, team_json,
        transfers_allowed, transfers_made, transfers_left,
        booster_id, booster_player_id, partition_id,
        created_date, updated_date, device_id
    ) VALUES (
        v_season_id, p_user_id, v_team_no, v_gameset_id, v_gameday_id,
        v_gameset_id, v_gameday_id, -1, NULL,
        v_team_valuation, v_remaining_budget, v_team_players,
        v_captain_id, v_vice_captain_id,
        jsonb_build_object('inplay_entities', v_inplay_entities, 'reserved_entities', v_reserved_entities),
        5, 0, 5, v_booster_id, v_booster_player_id, p_partition_id,
        v_current_time, v_current_time, v_device_id
    );
    
    -- Log team creation
    INSERT INTO gameplay.user_team_booster_transfer_detail (
        season_id, transfer_id, user_id, team_no, gameset_id, gameday_id,
        booster_id, original_team_players, players_out, players_in,
        new_team_players, transfers_made, transfer_json,
        created_date, updated_date, device_id, partition_id
    ) VALUES (
        v_season_id, v_transfer_id, p_user_id, v_team_no, v_gameset_id, v_gameday_id,
        v_booster_id, ARRAY[]::INT[], ARRAY[]::INT[], ARRAY[]::INT[],
        v_team_players, 0,
        jsonb_build_object('action', 'team_created', 'team_name', v_team_name),
        v_current_time, v_current_time, v_device_id, p_partition_id
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'team_no', v_team_no,
        'transfer_id', v_transfer_id,
        'message', 'Team created successfully'
    );
END;
$$ LANGUAGE plpgsql;
