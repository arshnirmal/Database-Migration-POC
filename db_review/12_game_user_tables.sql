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