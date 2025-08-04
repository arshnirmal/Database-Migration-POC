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