CREATE UNLOGGED TABLE IF NOT EXISTS log.engine_error_log
(
    error_id      SERIAL,
    error_message TEXT,
    error_code    TEXT,
    error_time    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    error_data    jsonb        DEFAULT '{}'::jsonb,
    function_name VARCHAR(255) DEFAULT NULL::CHARACTER VARYING,
    PRIMARY KEY (error_id)
);

CREATE UNLOGGED TABLE IF NOT EXISTS log.gameplay_error_log
(
    error_id      SERIAL,
    error_message TEXT,
    error_code    TEXT,
    error_time    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    error_data    jsonb        DEFAULT '{}'::jsonb,
    function_name VARCHAR(255) DEFAULT NULL::CHARACTER VARYING,
    PRIMARY KEY (error_id)
); 

CREATE TABLE IF NOT EXISTS engine_config.admin_user
(
    user_id           SMALLINT     NOT NULL,
    user_name         VARCHAR(100) NOT NULL,
    display_user_name VARCHAR(100),
    user_password     VARCHAR(255) NOT NULL,
    status            SMALLINT DEFAULT 1,
    created_date      TIMESTAMP,
    is_super_admin    BOOLEAN  DEFAULT TRUE,
    CONSTRAINT user_pk
        PRIMARY KEY (user_id),
    CONSTRAINT user_uq_user_name
        UNIQUE (user_name)
);

CREATE TABLE IF NOT EXISTS engine_config.chip_type
(
    chip_id    SMALLINT     NOT NULL,
    chip_name  VARCHAR(100) NOT NULL,
    chip_type  VARCHAR(100),
    multiplier NUMERIC(10, 2),
    CONSTRAINT chip_type_pk
        PRIMARY KEY (chip_id)
);

CREATE TABLE IF NOT EXISTS engine_config.game_variant
(
    variant_id   SMALLINT     NOT NULL,
    variant_name VARCHAR(100) NOT NULL,
    CONSTRAINT game_variant_pk
        PRIMARY KEY (variant_id)
);

CREATE TABLE IF NOT EXISTS engine_config.offset_type
(
    offset_type_id SMALLINT     NOT NULL,
    offset_type    VARCHAR(100) NOT NULL,
    CONSTRAINT offset_type_pk
        PRIMARY KEY (offset_type_id)
);

CREATE TABLE IF NOT EXISTS engine_config.platform
(
    platform_id   SMALLINT    NOT NULL,
    platform_name VARCHAR(20) NOT NULL,
    CONSTRAINT platform_pk
        PRIMARY KEY (platform_id)
);

CREATE TABLE IF NOT EXISTS engine_config.device
(
    device_id   SMALLINT    NOT NULL,
    device_name VARCHAR(20) NOT NULL,
    CONSTRAINT device_pk
        PRIMARY KEY (device_id)
);

CREATE TABLE IF NOT EXISTS engine_config.player_valuation_algorithm_type
(
    algorithm_type_id   SMALLINT     NOT NULL,
    algorithm_type_name VARCHAR(100) NOT NULL,
    CONSTRAINT player_valuation_algorithm_pk
        PRIMARY KEY (algorithm_type_id)
);

CREATE TABLE IF NOT EXISTS engine_config.response_type
(
    response_code SMALLINT NOT NULL,
    response_desc VARCHAR(100),
    CONSTRAINT response_type_pk
        PRIMARY KEY (response_code),
    CONSTRAINT response_type_uk_response_desc
        UNIQUE (response_desc)
);

CREATE TABLE IF NOT EXISTS engine_config.role
(
    role_id   SMALLINT     NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    CONSTRAINT role_pk
        PRIMARY KEY (role_id),
    CONSTRAINT role_uq_role_name
        UNIQUE (role_name)
);

CREATE TABLE IF NOT EXISTS engine_config.season_status
(
    status_id SMALLINT     NOT NULL,
    status    VARCHAR(100) NOT NULL,
    CONSTRAINT season_status_pk
        PRIMARY KEY (status_id),
    CONSTRAINT season_status_uk_status
        UNIQUE (status)
);

CREATE TABLE IF NOT EXISTS engine_config.sport
(
    sport_id   SMALLINT     NOT NULL,
    sport_name VARCHAR(100) NOT NULL,
    CONSTRAINT sport_pk
        PRIMARY KEY (sport_id),
    CONSTRAINT sport_uk_sport_name
        UNIQUE (sport_name)
);

CREATE TABLE IF NOT EXISTS engine_config.profanity_status
(
    status_id SMALLINT     NOT NULL,
    status    VARCHAR(100) NOT NULL,
    CONSTRAINT profanity_status_pk
        PRIMARY KEY (status_id)
);

CREATE TABLE IF NOT EXISTS engine_config.application
(
    application_id   SMALLINT     NOT NULL,
    application_name VARCHAR(256) NOT NULL,
    admin_id         SMALLINT     NOT NULL,
    sport_id         SMALLINT     NOT NULL,
    variant_id       SMALLINT     NOT NULL,
    created_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    logo_url         TEXT,
    config_json      jsonb,
    CONSTRAINT application_pk
        PRIMARY KEY (application_id, admin_id),
    CONSTRAINT application_uq_application_id
        UNIQUE (application_id),
    CONSTRAINT application_uq_application_name
        UNIQUE (application_name),
    CONSTRAINT application_fk_variant_id
        FOREIGN KEY (variant_id) REFERENCES engine_config.game_variant,
    CONSTRAINT application_fk_sport_id
        FOREIGN KEY (sport_id) REFERENCES engine_config.sport,
    CONSTRAINT application_fk_user_id
        FOREIGN KEY (admin_id) REFERENCES engine_config.admin_user
);

CREATE TABLE IF NOT EXISTS engine_config.application_database
(
    application_id     SMALLINT NOT NULL,
    database_id        SMALLINT NOT NULL,
    database_type      VARCHAR(50),
    shard_id           SMALLINT,
    connection_details TEXT,
    CONSTRAINT application_database_pk
        PRIMARY KEY (database_id),
    CONSTRAINT application_database_fk_application_id
        FOREIGN KEY (application_id) REFERENCES engine_config.application (application_id)
);

CREATE TABLE IF NOT EXISTS engine_config.preset
(
    preset_id   SMALLINT NOT NULL,
    preset_name VARCHAR(100),
    sport_id    SMALLINT NOT NULL,
    variant_id  SMALLINT NOT NULL,
    CONSTRAINT preset_pk
        PRIMARY KEY (preset_id),
    CONSTRAINT preset_uq_preset_name
        UNIQUE (preset_name),
    CONSTRAINT preset_fk_variant_id
        FOREIGN KEY (variant_id) REFERENCES engine_config.game_variant,
    CONSTRAINT preset_fk_sport_id
        FOREIGN KEY (sport_id) REFERENCES engine_config.sport
);

CREATE TABLE IF NOT EXISTS engine_config.season
(
    season_id               SMALLINT   DEFAULT NEXTVAL('engine_config.season_id_seq'::regclass) NOT NULL,
    application_id          SMALLINT                                                            NOT NULL,
    season_name             VARCHAR(255)                                                        NOT NULL,
    created_date            TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    updated_date            TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
    device_id               SMALLINT[] DEFAULT ARRAY []::SMALLINT[]                             NOT NULL,
    status_id               SMALLINT   DEFAULT 1,
    is_enabled_for_operator BOOLEAN    DEFAULT FALSE,
    CONSTRAINT season_pk
        PRIMARY KEY (season_id),
    CONSTRAINT season_uq_season_name
        UNIQUE (season_name, application_id),
    CONSTRAINT season_fk_application_id
        FOREIGN KEY (application_id) REFERENCES engine_config.application (application_id),
    CONSTRAINT season_fk_status_id
        FOREIGN KEY (status_id) REFERENCES engine_config.season_status
);

CREATE TABLE IF NOT EXISTS engine_config.application_budget_configuration
(
    season_id                            SMALLINT NOT NULL,
    budget_value                         NUMERIC(18, 2),
    currency_symbol                      VARCHAR(3),
    is_additional_budget_allowed         BOOLEAN,
    additional_budget_value              NUMERIC(18, 2),
    additional_budget_allowed_from_round SMALLINT NOT NULL,
    CONSTRAINT application_budget_configuration_pk
        PRIMARY KEY (season_id, additional_budget_allowed_from_round),
    CONSTRAINT application_budget_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_chip_configuration
(
    season_id                 SMALLINT     NOT NULL,
    chip_id                   SMALLINT     NOT NULL,
    chip_name                 VARCHAR(100) NOT NULL,
    start_gameset_id          SMALLINT     NOT NULL,
    end_gameset_id            SMALLINT     NOT NULL,
    no_of_chip                SMALLINT,
    expire_if_not_used        BOOLEAN,
    is_for_individual_gameset BOOLEAN,
    CONSTRAINT application_chip_configuration_pk
        PRIMARY KEY (chip_id, season_id, start_gameset_id, end_gameset_id),
    CONSTRAINT application_chip_configuration_fk_chip_id
        FOREIGN KEY (chip_id) REFERENCES engine_config.chip_type,
    CONSTRAINT application_chip_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_maintenance
(
    season_id           SMALLINT NOT NULL,
    device_id           SMALLINT NOT NULL,
    maintenance_code    VARCHAR  NOT NULL,
    maintenance_message VARCHAR  NOT NULL,
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW(),
    CONSTRAINT application_maintenance_pk
        PRIMARY KEY (season_id, device_id),
    CONSTRAINT application_maintenance_fk_device_id
        FOREIGN KEY (device_id) REFERENCES engine_config.device,
    CONSTRAINT application_maintenance_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_user_team_configuration
(
    season_id                        SMALLINT NOT NULL,
    min_user_teams                   SMALLINT,
    max_user_teams                   SMALLINT,
    min_playing_entities_per_team    SMALLINT,
    max_playing_entities_per_team    SMALLINT,
    is_substitute_allowed            BOOLEAN,
    min_substitute_entities_per_team SMALLINT,
    max_substitute_entities_per_team SMALLINT,
    CONSTRAINT application_user_team_configuration_pk
        PRIMARY KEY (season_id),
    CONSTRAINT application_user_team_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_user_team_misc_configuration
(
    season_id                                 SMALLINT NOT NULL,
    is_captain_allowed                        BOOLEAN,
    is_captain_changes_allowed                BOOLEAN,
    is_unlimited_captain_changes_allowed      BOOLEAN,
    total_captain_changes_allowed             SMALLINT,
    captain_point_multiplier                  SMALLINT,
    is_vice_captain_allowed                   BOOLEAN,
    is_vice_captain_changes_allowed           BOOLEAN,
    is_unlimited_vice_captain_changes_allowed BOOLEAN,
    total_vice_captain_changes_allowed        SMALLINT,
    vice_captain_point_multiplier             SMALLINT,
    is_substitution_allowed                   BOOLEAN,
    is_substitution_changes_allowed           BOOLEAN,
    is_unlimited_substitution_changes_allowed BOOLEAN,
    total_substitution_changes_allowed        SMALLINT,
    substitution_point_multiplier             SMALLINT,
    is_auto_substitution_allowed              BOOLEAN,
    CONSTRAINT application_user_team_misc_configuration_pk
        PRIMARY KEY (season_id),
    CONSTRAINT application_user_team_misc_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_user_team_transfer_configuration
(
    season_id                                SMALLINT NOT NULL,
    is_transfer_allowed                      BOOLEAN,
    is_unlimited_transfer_allowed            BOOLEAN,
    total_transfer_allowed                   SMALLINT,
    is_additional_transfer_allowed           BOOLEAN,
    is_unlimited_additional_transfer_allowed BOOLEAN,
    total_additional_transfer_allowed        SMALLINT,
    additional_transfer_negative_points      SMALLINT,
    unused_transfers_carry_over              SMALLINT,
    all_unused_transfers_carry_over          SMALLINT,
    total_unused_transfers_carry_over        SMALLINT,
    is_for_individual_gameset                BOOLEAN,
    from_gameset_id                          SMALLINT NOT NULL,
    to_gameset_id                            SMALLINT NOT NULL,
    CONSTRAINT application_user_team_transfer_configuration_pk
        PRIMARY KEY (season_id, from_gameset_id, to_gameset_id),
    CONSTRAINT application_user_team_transfer_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.language
(
    season_id     SMALLINT    NOT NULL,
    language_code VARCHAR(64) NOT NULL,
    language_name VARCHAR(64) NOT NULL,
    is_deleted    BOOLEAN DEFAULT FALSE,
    CONSTRAINT language_pk
        PRIMARY KEY (season_id, language_code),
    CONSTRAINT language_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.sport_skill
(
    sport_id         SMALLINT     NOT NULL,
    skill_id         SMALLINT     NOT NULL,
    skill_name       VARCHAR(100) NOT NULL,
    feed_skill_id    SMALLINT,
    skill_short_name VARCHAR(25),
    CONSTRAINT sport_skill_pk
        PRIMARY KEY (skill_id),
    CONSTRAINT sport_skill_fk_sport_id
        FOREIGN KEY (sport_id) REFERENCES engine_config.sport
);

CREATE TABLE IF NOT EXISTS engine_config.team_constraint
(
    constraint_id         SMALLINT NOT NULL,
    constraint_type_id    SMALLINT,
    constraint_type       VARCHAR(100),
    constraint_subtype_id SMALLINT,
    constraint_subtype    VARCHAR(100),
    CONSTRAINT team_constraint_pk
        PRIMARY KEY (constraint_id),
    CONSTRAINT team_constraint_uk_constraint_type_id
        UNIQUE (constraint_type_id, constraint_subtype_id)
);

CREATE TABLE IF NOT EXISTS engine_config.application_user_team_constraint_configuration
(
    season_id         SMALLINT NOT NULL,
    constraint_id     SMALLINT NOT NULL,
    constraint_name   VARCHAR(255),
    constraint_config jsonb,
    CONSTRAINT application_user_team_constraint_configuration_pk
        PRIMARY KEY (season_id, constraint_id),
    CONSTRAINT application_user_team_constraint_configuration_fk_constraint_id
        FOREIGN KEY (constraint_id) REFERENCES engine_config.team_constraint,
    CONSTRAINT application_user_team_constraint_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS engine_config.application_user_team_skill_configuration
(
    season_id             SMALLINT NOT NULL,
    skill_id              SMALLINT NOT NULL,
    min_entities_per_team SMALLINT,
    max_entities_per_team SMALLINT,
    constraint_id         SMALLINT NOT NULL,
    constraint_name       VARCHAR(255) DEFAULT NULL::CHARACTER VARYING,
    constraint_config     jsonb,
    CONSTRAINT application_user_team_skill_configuration_pk
        PRIMARY KEY (season_id, skill_id, constraint_id),
    CONSTRAINT application_user_team_skill_configuration_fk_constraint_id
        FOREIGN KEY (constraint_id) REFERENCES engine_config.team_constraint,
    CONSTRAINT application_user_team_skill_configuration_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE,
    CONSTRAINT application_user_team_skill_configuration_fk_skill_id
        FOREIGN KEY (skill_id) REFERENCES engine_config.sport_skill
);

CREATE TABLE IF NOT EXISTS engine_config.season_config
(
    season_id                 SMALLINT NOT NULL,
    feed                      jsonb,
    player_points_calculation jsonb,
    draft_json                jsonb,
    config_json               jsonb,
    localization              jsonb,
    offload_location          jsonb,
    player_valuation          jsonb,
    team_management           jsonb,
    game_rules                jsonb,
    gameset_offset_type       SMALLINT DEFAULT 1,
    CONSTRAINT season_config_pk
        PRIMARY KEY (season_id),
    CONSTRAINT season_config_fk_season_id
        FOREIGN KEY (season_id) REFERENCES engine_config.season
            ON DELETE CASCADE,
    CONSTRAINT season_config_fk_offset_type
        FOREIGN KEY (gameset_offset_type) REFERENCES engine_config.offset_type
);

CREATE TABLE IF NOT EXISTS engine_config.country
(
    country_id   SMALLINT     NOT NULL,
    country_name VARCHAR(255) NOT NULL,
    country_code VARCHAR(10)  NOT NULL,
    CONSTRAINT country_pk
        PRIMARY KEY (country_id)
); 

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

CREATE TABLE IF NOT EXISTS game_user."user"
(
    user_id               NUMERIC      NOT NULL,
    source_id             VARCHAR(150) NOT NULL,
    first_name            VARCHAR(100),
    last_name             VARCHAR(100),
    user_name             VARCHAR(150),
    device_id             SMALLINT     NOT NULL,
    device_version        VARCHAR(10),
    login_platform_source SMALLINT     NOT NULL,
    created_date          TIMESTAMP    NOT NULL,
    updated_date          TIMESTAMP    NOT NULL,
    registered_date       TIMESTAMP    NOT NULL,
    partition_id          SMALLINT     NOT NULL,
    user_guid             uuid,
    opt_in                jsonb,
    user_properties       jsonb,
    user_preference       jsonb,
    profanity_status      SMALLINT,
    PRIMARY KEY (user_id, partition_id),
    CONSTRAINT user_uk_external_id
        UNIQUE (source_id, partition_id),
    CONSTRAINT user_fk_device_id
        FOREIGN KEY (device_id) REFERENCES engine_config.device (device_id),
    CONSTRAINT user_fk_login_platform_source
        FOREIGN KEY (login_platform_source) REFERENCES engine_config.platform (platform_id),
    CONSTRAINT user_fk_profanity_status
        FOREIGN KEY (profanity_status) REFERENCES engine_config.profanity_status (status_id)
)
    PARTITION BY LIST (partition_id);

CREATE INDEX IF NOT EXISTS idx_user_external_id
    ON game_user."user" (source_id, partition_id);

DO
$$
    DECLARE
        i         SMALLINT;
        str_query TEXT;
    BEGIN
        FOR i IN 1..10
            LOOP
                str_query := 'CREATE TABLE IF NOT EXISTS game_user.user_p' || i || ' PARTITION OF game_user."user" FOR VALUES IN (' || i || ');';
                EXECUTE str_query;
            END LOOP;
    END;
$$;

CREATE TABLE IF NOT EXISTS gameplay.user_teams
(
    user_id                NUMERIC   NOT NULL,
    team_no                SMALLINT NOT NULL,
    team_name              VARCHAR(250),
    upper_team_name        VARCHAR(250),
    season_id              SMALLINT NOT NULL,
    gameset_id             SMALLINT,
    gameday_id             SMALLINT,
    profanity_status      SMALLINT,
    profanity_updated_date TIMESTAMP,
    partition_id           SMALLINT NOT NULL,
    created_date           TIMESTAMP,
    updated_date           TIMESTAMP,
    CONSTRAINT user_teams_pk
        PRIMARY KEY (season_id, user_id, team_no, partition_id),
    CONSTRAINT user_teams_uk_team_name
        UNIQUE (season_id, team_name, partition_id),
    CONSTRAINT user_teams_fk_user_id
        FOREIGN KEY (user_id, partition_id) REFERENCES game_user."user" (user_id, partition_id),
    CONSTRAINT user_teams_fk_profanity_status
        FOREIGN KEY (profanity_status) REFERENCES engine_config.profanity_status (status_id)
)
    PARTITION BY LIST (partition_id);
DO
$$
    DECLARE
        i         SMALLINT;
        str_query TEXT;
    BEGIN
        FOR i IN 1..10
            LOOP
                str_query := 'CREATE TABLE IF NOT EXISTS gameplay.user_teams_p' || i || ' PARTITION OF gameplay.user_teams FOR VALUES IN (' || i || ');';
                EXECUTE str_query;
            END LOOP;
    END;
$$;

CREATE TABLE IF NOT EXISTS gameplay.user_team_detail
(
    season_id                SMALLINT NOT NULL,
    user_id                  NUMERIC  NOT NULL,
    team_no                  SMALLINT NOT NULL,
    gameset_id               SMALLINT NOT NULL,
    gameday_id               SMALLINT NOT NULL,
    from_gameset_id          SMALLINT,
    from_gameday_id          SMALLINT,
    to_gameset_id            SMALLINT,
    to_gameday_id            SMALLINT,
    team_valuation           NUMERIC(10, 2),
    remaining_budget         NUMERIC(10, 2),
    team_players             INTEGER[],
    captain_player_id        INTEGER,
    vice_captain_player_id   INTEGER,
    team_json                jsonb,
    substitution_allowed     SMALLINT,
    substitution_made        SMALLINT,
    substitution_left        SMALLINT,
    transfers_allowed        SMALLINT,
    transfers_made           SMALLINT,
    transfers_left           SMALLINT,
    booster_id               SMALLINT,
    booster_player_id        INTEGER,
    booster_team_players     INTEGER[],
    partition_id             SMALLINT NOT NULL,
    created_date             TIMESTAMP,
    updated_date             TIMESTAMP,
    device_id                SMALLINT,
    CONSTRAINT user_team_detail_pk
        PRIMARY KEY (season_id, user_id, team_no, gameset_id, gameday_id, partition_id),
    CONSTRAINT user_team_detail_uk_team
        UNIQUE (season_id, user_id, team_no, gameset_id, gameday_id, partition_id),
    CONSTRAINT user_team_detail_fk_user_id
        FOREIGN KEY (user_id, partition_id) REFERENCES game_user."user" (user_id, partition_id),
    CONSTRAINT user_team_detail_fk_device_id
        FOREIGN KEY (device_id) REFERENCES engine_config.device (device_id)
)
    PARTITION BY LIST (partition_id);

DO
$$
    DECLARE
        i         SMALLINT;
        str_query TEXT;
    BEGIN
        FOR i IN 1..10
            LOOP
                str_query := 'CREATE TABLE IF NOT EXISTS gameplay.user_team_detail_p' || i || ' PARTITION OF gameplay.user_team_detail FOR VALUES IN (' || i || ');';
                EXECUTE str_query;
            END LOOP;
    END;
$$;

CREATE TABLE IF NOT EXISTS gameplay.user_team_booster_transfer_detail
(
    season_id             SMALLINT     NOT NULL,
    transfer_id           INTEGER      NOT NULL,
    user_id               NUMERIC      NOT NULL,
    team_no               SMALLINT     NOT NULL,
    gameset_id            SMALLINT     NOT NULL,
    gameday_id            SMALLINT     NOT NULL,
    booster_id            SMALLINT     NOT NULL,
    original_team_players INTEGER[],
    players_out           INTEGER[],
    players_in            INTEGER[],
    new_team_players      INTEGER[],
    transfers_made        SMALLINT,
    transfer_json         jsonb,
    created_date          TIMESTAMP,
    updated_date          TIMESTAMP,
    device_id             SMALLINT,
    CONSTRAINT user_team_booster_transfer_detail_pk
        PRIMARY KEY (season_id, user_id, team_no, gameset_id, gameday_id, transfer_id, booster_id),
    CONSTRAINT user_team_booster_transfer_detail_fk_device_id
        FOREIGN KEY (device_id) REFERENCES engine_config.device (device_id)
);

CREATE TABLE IF NOT EXISTS gameplay.gameset_player
(
    player_id            INTEGER        NOT NULL,
    gameset_id           SMALLINT       NOT NULL,
    season_id            SMALLINT       NOT NULL,
    skill_id             SMALLINT       NOT NULL,
    player_value         NUMERIC(10, 2) NOT NULL,
    valuation_change     NUMERIC(10, 2) DEFAULT 0,
    team_id              INTEGER        NOT NULL,
    is_active            BOOLEAN,
    selection_percentage NUMERIC(5, 2)  DEFAULT 0,
    availability_status  SMALLINT       NOT NULL,
    points               NUMERIC(10, 2),
    player_stats         jsonb,
    CONSTRAINT gameset_player_pk
        PRIMARY KEY (player_id, gameset_id, season_id)
); 

CREATE TABLE IF NOT EXISTS point_calculation.entity_stat
(
    sport_id         SMALLINT    NOT NULL,
    stat_id          SMALLINT    NOT NULL,
    stat_name        VARCHAR(50) NOT NULL,
    calculation_type VARCHAR(50) NOT NULL,
    CONSTRAINT entity_stat_pk
        PRIMARY KEY (sport_id, stat_id)
); 

CREATE TABLE IF NOT EXISTS league.league_preset
(
    preset_id    SMALLINT NOT NULL,
    preset_name  VARCHAR(255),
    preset       jsonb,
    created_date TIMESTAMP WITH TIME ZONE,
    updated_date TIMESTAMP WITH TIME ZONE,
    CONSTRAINT league_preset_pk
        PRIMARY KEY (preset_id)
);

CREATE TABLE IF NOT EXISTS league.league_scoring_type
(
    scoring_type_id   SMALLINT NOT NULL,
    scoring_type_name VARCHAR(100),
    created_at        TIMESTAMP WITH TIME ZONE,
    updated_at        TIMESTAMP WITH TIME ZONE,
    CONSTRAINT league_scoring_type_pk
        PRIMARY KEY (scoring_type_id)
);

CREATE TABLE IF NOT EXISTS league.league_tag
(
    tag_id   SMALLINT NOT NULL,
    tag_name VARCHAR(25),
    CONSTRAINT league_tag_pk
        PRIMARY KEY (tag_id)
);

CREATE TABLE IF NOT EXISTS league.league_member_status
(
    status_id   SMALLINT NOT NULL,
    status_name VARCHAR(25),
    CONSTRAINT league_member_status_pk
        PRIMARY KEY (status_id)
);

CREATE TABLE IF NOT EXISTS league.league_type
(
    league_type_id          SERIAL,
    league_type_name        VARCHAR(100),
    preset_id               SMALLINT,
    season_id               SMALLINT NOT NULL,
    scoring_type_id         SMALLINT,
    leaderboard_visibility  VARCHAR(100),
    join_visibility         VARCHAR(100),
    auto_spawn_league       BOOLEAN,
    auto_join_league        BOOLEAN,
    users_can_create_league BOOLEAN,
    users_select_game_set   BOOLEAN,
    users_set_team_cap      BOOLEAN,
    unlimited_max_entry_cap BOOLEAN,
    users_set_max_entry_cap BOOLEAN,
    league_property         jsonb,
    created_date            TIMESTAMP WITH TIME ZONE,
    updated_date            TIMESTAMP WITH TIME ZONE,
    CONSTRAINT league_type_pk
        PRIMARY KEY (season_id, league_type_id),
    CONSTRAINT league_type_fk_preset_id
        FOREIGN KEY (preset_id) REFERENCES league.league_preset,
    CONSTRAINT league_type_fk_scoring_type_id
        FOREIGN KEY (scoring_type_id) REFERENCES league.league_scoring_type
);

CREATE TABLE IF NOT EXISTS league.league
(
    season_id            SMALLINT                                                           NOT NULL,
    league_id            INTEGER   DEFAULT NEXTVAL('league.league_league_id_seq'::regclass) NOT NULL,
    league_type_id       SMALLINT                                                           NOT NULL,
    league_name          VARCHAR(255),
    league_code          VARCHAR(25),
    social_id            VARCHAR(25),
    user_id              NUMERIC,
    active_gameset_ids   SMALLINT[],
    join_lock_timestamp  TIMESTAMP,
    join_lock_gameset_id SMALLINT,
    maximum_team_count   NUMERIC,
    teams_per_user       SMALLINT,
    platform_id          SMALLINT,
    platform_version     VARCHAR(10),
    tag_ids              SMALLINT[],
    is_system_league     BOOLEAN,
    total_team_count     NUMERIC,
    total_user_count     NUMERIC,
    is_locked            BOOLEAN,
    is_deleted           BOOLEAN,
    profane_flag         VARCHAR(25),
    profane_updated_date TIMESTAMP,
    banner_image_url     TEXT,
    banner_url           TEXT,
    partition_id         SMALLINT,
    created_date         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    input_json           jsonb,
    CONSTRAINT league_pk
        PRIMARY KEY (league_id, season_id, league_type_id),
    CONSTRAINT league_fk_league_type_id
        FOREIGN KEY (season_id, league_type_id) REFERENCES league.league_type
)
    PARTITION BY LIST (league_type_id);

CREATE TABLE IF NOT EXISTS league.league_member
(
    season_id          SMALLINT NOT NULL,
    league_id          INTEGER  NOT NULL,
    league_type_id     SMALLINT NOT NULL,
    social_id          VARCHAR(25),
    user_id            NUMERIC  NOT NULL,
    user_name          VARCHAR(250),
    team_no            SMALLINT,
    team_name          VARCHAR(250),
    is_manager         BOOLEAN,
    join_gameset_id    SMALLINT,
    join_timestamp     TIMESTAMP,
    member_status      SMALLINT,
    disjoin_gameset_id SMALLINT,
    disjoin_timestamp  TIMESTAMP,
    platform_id        SMALLINT,
    platform_version   VARCHAR(10),
    partition_id       SMALLINT,
    created_date       TIMESTAMP,
    updated_date       TIMESTAMP,
    CONSTRAINT league_member_pk
        PRIMARY KEY (league_id, season_id, user_id, league_type_id),
    CONSTRAINT league_member_fk_league_type_id
        FOREIGN KEY (league_type_id, season_id) REFERENCES league.league_type (league_type_id, season_id),
    CONSTRAINT league_member_fk_member_status
        FOREIGN KEY (member_status) REFERENCES league.league_member_status
)
    PARTITION BY LIST (league_type_id);

CREATE TABLE IF NOT EXISTS league.user_league_map
(
    season_id       SMALLINT    NOT NULL,
    user_id         NUMERIC     NOT NULL,
    league_code     VARCHAR(25) NOT NULL,
    league_type_id  SMALLINT,
    league_shard_id SMALLINT,
    teams_data      jsonb,
    CONSTRAINT user_league_pk
        PRIMARY KEY (season_id, user_id, league_code),
    CONSTRAINT user_league_fk_league_type_id
        FOREIGN KEY (league_type_id, season_id) REFERENCES league.league_type (league_type_id, season_id)
); 