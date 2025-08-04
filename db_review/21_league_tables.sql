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