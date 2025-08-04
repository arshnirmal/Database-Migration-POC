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