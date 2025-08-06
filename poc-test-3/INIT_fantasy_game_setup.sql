-- ================================================================
-- CockroachDB Fantasy Game Database - Tables Only (No Functions)
-- All logic moved to Node.js with direct SQL queries
-- ================================================================

CREATE DATABASE IF NOT EXISTS fantasy_game;
USE fantasy_game;

CREATE SCHEMA IF NOT EXISTS game_user;
CREATE SCHEMA IF NOT EXISTS gameplay;
CREATE SCHEMA IF NOT EXISTS engine_config;

-- ================================================================
-- REFERENCE TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS engine_config.device
(
    device_id   SMALLINT PRIMARY KEY,
    device_name STRING
);

CREATE TABLE IF NOT EXISTS engine_config.platform
(
    platform_id   SMALLINT PRIMARY KEY,
    platform_name STRING
);

CREATE TABLE IF NOT EXISTS engine_config.profanity_status
(
    status_id   SMALLINT PRIMARY KEY,
    status_name STRING
);

-- ================================================================
-- SEQUENCES
-- ================================================================

CREATE SEQUENCE IF NOT EXISTS game_user.user_id_seq START 1000000;

-- ================================================================
-- MAIN TABLES WITH PHYSICAL SHARDING (TABLES ONLY)
-- ================================================================

CREATE TABLE IF NOT EXISTS game_user.users
(
    user_id               NUMERIC     NOT NULL DEFAULT NEXTVAL('game_user.user_id_seq'),
    source_id             STRING(150) NOT NULL,
    first_name            STRING(100),
    last_name             STRING(100),
    user_name             STRING(150),
    device_id             SMALLINT    NOT NULL,
    device_version        STRING(10),
    login_platform_source SMALLINT    NOT NULL,
    created_date          TIMESTAMPTZ NOT NULL,
    updated_date          TIMESTAMPTZ NOT NULL,
    registered_date       TIMESTAMPTZ NOT NULL,
    partition_id          SMALLINT    NOT NULL,
    user_guid             UUID                 DEFAULT GEN_RANDOM_UUID(),
    opt_in                JSONB,
    user_properties       JSONB,
    user_preferences      JSONB,
    profanity_status      SMALLINT             DEFAULT 1,
    PRIMARY KEY (partition_id, user_id),
    UNIQUE (source_id, partition_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0,1,2,3,4,5,6,7,8,9),
    PARTITION shard_1 VALUES IN (10,11,12,13,14,15,16,17,18,19),
    PARTITION shard_2 VALUES IN (20,21,22,23,24,25,26,27,28,29)
    );

CREATE TABLE IF NOT EXISTS gameplay.user_teams
(
    user_id                NUMERIC  NOT NULL,
    team_no                SMALLINT NOT NULL,
    team_name              STRING(250),
    upper_team_name        STRING(250),
    season_id              SMALLINT NOT NULL,
    gameset_id             SMALLINT,
    gameday_id             SMALLINT,
    profanity_status       SMALLINT    DEFAULT 1,
    profanity_updated_date TIMESTAMPTZ,
    partition_id           SMALLINT NOT NULL,
    created_date           TIMESTAMPTZ DEFAULT NOW(),
    updated_date           TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (partition_id, season_id, user_id, team_no),
    UNIQUE (season_id, team_name, partition_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0,1,2,3,4,5,6,7,8,9),
    PARTITION shard_1 VALUES IN (10,11,12,13,14,15,16,17,18,19),
    PARTITION shard_2 VALUES IN (20,21,22,23,24,25,26,27,28,29)
    );

CREATE TABLE IF NOT EXISTS gameplay.user_team_detail
(
    season_id              SMALLINT NOT NULL,
    user_id                NUMERIC  NOT NULL,
    team_no                SMALLINT NOT NULL,
    gameset_id             SMALLINT NOT NULL,
    gameday_id             SMALLINT NOT NULL,
    from_gameset_id        SMALLINT,
    from_gameday_id        SMALLINT,
    to_gameset_id          SMALLINT,
    to_gameday_id          SMALLINT,
    team_valuation         DECIMAL(10, 2),
    remaining_budget       DECIMAL(10, 2),
    team_players           INT[],
    captain_player_id      INT,
    vice_captain_player_id INT,
    team_json              JSONB,
    substitution_allowed   SMALLINT    DEFAULT 5,
    substitution_made      SMALLINT    DEFAULT 0,
    substitution_left      SMALLINT    DEFAULT 5,
    transfers_allowed      SMALLINT    DEFAULT 5,
    transfers_made         SMALLINT    DEFAULT 0,
    transfers_left         SMALLINT    DEFAULT 5,
    booster_id             SMALLINT,
    booster_player_id      INT,
    booster_team_players   INT[],
    partition_id           SMALLINT NOT NULL,
    created_date           TIMESTAMPTZ DEFAULT NOW(),
    updated_date           TIMESTAMPTZ DEFAULT NOW(),
    device_id              SMALLINT,
    PRIMARY KEY (partition_id, season_id, user_id, team_no, gameset_id, gameday_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0,1,2,3,4,5,6,7,8,9),
    PARTITION shard_1 VALUES IN (10,11,12,13,14,15,16,17,18,19),
    PARTITION shard_2 VALUES IN (20,21,22,23,24,25,26,27,28,29)
    );

CREATE TABLE IF NOT EXISTS gameplay.user_team_booster_transfer_detail
(
    season_id             SMALLINT NOT NULL,
    transfer_id           UUID     NOT NULL DEFAULT GEN_RANDOM_UUID(),
    user_id               NUMERIC  NOT NULL,
    team_no               SMALLINT NOT NULL,
    gameset_id            SMALLINT NOT NULL,
    gameday_id            SMALLINT NOT NULL,
    booster_id            SMALLINT NOT NULL,
    original_team_players INT[],
    players_out           INT[],
    players_in            INT[],
    new_team_players      INT[],
    transfers_made        SMALLINT,
    transfer_json         JSONB,
    created_date          TIMESTAMPTZ       DEFAULT NOW(),
    updated_date          TIMESTAMPTZ       DEFAULT NOW(),
    device_id             SMALLINT,
    partition_id          SMALLINT NOT NULL,
    PRIMARY KEY (partition_id, season_id, user_id, team_no, gameset_id, gameday_id, transfer_id, booster_id)
) PARTITION BY LIST (partition_id) (
    PARTITION shard_0 VALUES IN (0,1,2,3,4,5,6,7,8,9),
    PARTITION shard_1 VALUES IN (10,11,12,13,14,15,16,17,18,19),
    PARTITION shard_2 VALUES IN (20,21,22,23,24,25,26,27,28,29)
    );

-- ================================================================
-- REFERENCE DATA POPULATION (NO FUNCTIONS)
-- ================================================================

INSERT INTO engine_config.device (device_id, device_name)
VALUES (1, 'iOS'),
       (2, 'Android'),
       (3, 'Web'),
       (4, 'Desktop')
ON CONFLICT DO NOTHING;

INSERT INTO engine_config.platform (platform_id, platform_name)
VALUES (1, 'Facebook'),
       (2, 'Google'),
       (3, 'Apple'),
       (4, 'Twitter')
ON CONFLICT DO NOTHING;

INSERT INTO engine_config.profanity_status (status_id, status_name)
VALUES (1, 'Clean'),
       (2, 'Flagged'),
       (3, 'Blocked')
ON CONFLICT DO NOTHING;
