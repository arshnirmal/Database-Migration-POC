CREATE TABLE IF NOT EXISTS game_management.phase
(
    phase_id   SMALLINT     NOT NULL,
    season_id  SMALLINT     NOT NULL,
    phase_name VARCHAR(100) NOT NULL,
    CONSTRAINT phase_pk
        PRIMARY KEY (phase_id, season_id),
    CONSTRAINT phase_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_management.team
(
    team_id           INTEGER                             NOT NULL,
    source_id         VARCHAR(100),
    season_id         SMALLINT                            NOT NULL,
    series_id         VARCHAR(64),
    team_name         VARCHAR(255)                        NOT NULL,
    team_display_name VARCHAR(255),
    team_short_code   VARCHAR(64),
    created_date      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_date      TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    sport_properties  jsonb,
    CONSTRAINT team_pk
        PRIMARY KEY (team_id, season_id),
    CONSTRAINT team_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_management.venue
(
    venue_id               INTEGER                             NOT NULL,
    source_id              VARCHAR(100),
    season_id              SMALLINT                            NOT NULL,
    location1              VARCHAR(255),
    location1_display_name VARCHAR(255),
    location2              VARCHAR(255),
    location2_display_name VARCHAR(255),
    location3              VARCHAR(255),
    location3_display_name VARCHAR(255),
    created_date           TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_date           TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    sport_properties       jsonb,
    CONSTRAINT venue_pk
        PRIMARY KEY (venue_id, season_id),
    CONSTRAINT venue_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_management.gameset
(
    gameset_id             SMALLINT     NOT NULL,
    season_id              SMALLINT     NOT NULL,
    phase_id               SMALLINT,
    gameset_name           VARCHAR(100) NOT NULL,
    transfer_lock_offset   INTERVAL,
    transfer_unlock_offset INTERVAL,
    CONSTRAINT gameset_pk
        PRIMARY KEY (gameset_id, season_id),
    CONSTRAINT gameset_fk_phase_id
        FOREIGN KEY (phase_id, season_id) REFERENCES game_management.phase,
    CONSTRAINT gameset_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_management.gameday
(
    gameday_id                 SMALLINT     NOT NULL,
    gameset_id                 SMALLINT     NOT NULL,
    season_id                  SMALLINT     NOT NULL,
    gameday_name               VARCHAR(255) NOT NULL,
    substitution_lock_offset   INTERVAL,
    substitution_unlock_offset INTERVAL,
    CONSTRAINT gameday_pk
        PRIMARY KEY (gameday_id, season_id, gameset_id),
    CONSTRAINT gameday_fk_gameset_id
        FOREIGN KEY (gameset_id, season_id) REFERENCES game_management.gameset
            ON DELETE CASCADE,
    CONSTRAINT gameday_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS game_management.fixture
(
    fixture_id               INTEGER                             NOT NULL,
    source_id                VARCHAR(100),
    season_id                SMALLINT                            NOT NULL,
    gameset_id               SMALLINT,
    gameday_id               SMALLINT,
    phase_id                 SMALLINT,
    series_id                VARCHAR(64),
    fixture_name             VARCHAR(255),
    fixture_display_name     VARCHAR(255),
    fixture_file             VARCHAR(255),
    fixture_number           VARCHAR(255),
    fixture_status           SMALLINT,
    fixture_datetime_iso8601 TIMESTAMP                           NOT NULL,
    fixture_format           VARCHAR(255),
    venue_id                 INTEGER,
    lineup_announced         BOOLEAN   DEFAULT FALSE,
    sport_properties         jsonb,
    created_date             TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_date             TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fixture_pk
        PRIMARY KEY (fixture_id, season_id),
    CONSTRAINT fixture_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE,
    CONSTRAINT fixture_fk_gameday_id
        FOREIGN KEY (gameday_id, season_id, gameset_id) REFERENCES game_management.gameday,
    CONSTRAINT fixture_fk_phase_id
        FOREIGN KEY (phase_id, season_id) REFERENCES game_management.phase
);

CREATE TABLE IF NOT EXISTS game_management.player
(
    player_id           INTEGER                                  NOT NULL,
    source_id           VARCHAR(100),
    season_id           SMALLINT                                 NOT NULL,
    series_id           VARCHAR(64),
    team_id             INTEGER,
    player_name         VARCHAR(255)                             NOT NULL,
    player_display_name VARCHAR(255),
    player_short_name   VARCHAR(255),
    skill_id            SMALLINT                                 NOT NULL,
    player_value        NUMERIC(10, 2) DEFAULT 0,
    is_foreign_player   BOOLEAN        DEFAULT FALSE,
    is_active           BOOLEAN        DEFAULT TRUE,
    created_date        TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_date        TIMESTAMP      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    sport_properties    jsonb,
    CONSTRAINT player_pk
        PRIMARY KEY (player_id, season_id),
    CONSTRAINT player_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE,
    CONSTRAINT player_fk_team_id
        FOREIGN KEY (team_id, season_id) REFERENCES game_management.team,
    CONSTRAINT player_fk_skill_id
        FOREIGN KEY (skill_id) REFERENCES engine_config.sport_skill
); 