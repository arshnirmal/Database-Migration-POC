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

CREATE TABLE IF NOT EXISTS log.point_submission_log (
    season_id smallint NOT NULL,
    gameset_id smallint NOT NULL,
    fixture_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);