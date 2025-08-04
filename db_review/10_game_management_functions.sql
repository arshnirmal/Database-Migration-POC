CREATE OR REPLACE FUNCTION game_management.fixture_mapping(p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "offset_type": 1,
  "gamesets": [
    {
      "gameset_id": 1,
      "transfer_lock_offset": "00:00:00",
      "transfer_unlock_offset": "00:00:00",
      "gameset_name": "gs1",
      "gamedays": [
        {
          "gameday_id": 1,
          "gameday_name": "gd1",
          "substitution_lock_offset": "00:00:00",
          "substitution_unlock_offset": "00:00:00",
          "fixtures": [
            1,
            2,
            3
          ]
        },
        {
          "gameday_id": 2,
          "gameday_name": "gd2",
          "substitution_lock_offset": "00:00:00",
          "substitution_unlock_offset": "00:00:00",
          "fixtures": [
            4,
            5,
            6
          ]
        }
      ]
    },
    {
      "gameset_id": 2,
      "transfer_lock_offset": "00:00:00",
      "transfer_unlock_offset": "00:00:00",
      "gameset_name": "gs2",
      "gamedays": [
        {
          "gameday_id": 1,
          "gameday_name": "gd1",
          "substitution_lock_offset": "00:00:00",
          "substitution_unlock_offset": "00:00:00",
          "fixtures": [
            7,
            8,
            9
          ]
        }
      ]
    }
  ]
}
*/
DECLARE
    v_season_id       SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_offset_type     SMALLINT := (p_input_json ->> 'offset_type')::SMALLINT;
    v_game_variant_id SMALLINT;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    -- Update season config
    INSERT INTO engine_config.season_config
    (season_id,
     gameset_offset_type)
    VALUES (v_season_id,
            v_offset_type)
    ON CONFLICT (season_id)
        DO UPDATE
        SET gameset_offset_type = EXCLUDED.gameset_offset_type;

    -- Create temp tables for processing the JSON data
    CREATE TEMP TABLE temp_gamesets
    (
        gameset_id             SMALLINT,
        transfer_lock_offset   INTERVAL,
        transfer_unlock_offset INTERVAL,
        gameset_name           VARCHAR(100),
        gamedays_json          jsonb
    ) ON COMMIT DROP;

    CREATE TEMP TABLE temp_gamedays
    (
        parent_gameset_id          SMALLINT,
        gameday_id                 SMALLINT,
        gameday_name               VARCHAR(255),
        substitution_lock_offset   INTERVAL,
        substitution_unlock_offset INTERVAL,
        fixtures_json              jsonb
    ) ON COMMIT DROP;

    UPDATE game_management.fixture
    SET gameset_id = NULL,
        gameday_id = NULL
    WHERE season_id = v_season_id;

    -- Step 1: Parse and stage gamesets from JSON into a temp table.
    -- Generate new gameset_ids for entries where it is null.
    WITH input_gamesets AS (SELECT (gs.value ->> 'gameset_id')::SMALLINT             AS gameset_id,
                                   (gs.value ->> 'transfer_lock_offset')::INTERVAL   AS transfer_lock_offset,
                                   (gs.value ->> 'transfer_unlock_offset')::INTERVAL AS transfer_unlock_offset,
                                   gs.value ->> 'gameset_name'                       AS gameset_name,
                                   gs.value -> 'gamedays'                            AS gamedays_json,
                                   gs.ordinality
                            FROM JSONB_ARRAY_ELEMENTS(p_input_json -> 'gamesets') WITH ORDINALITY gs),
         max_gameset_id AS (SELECT COALESCE(MAX(id), 0) AS val
                            FROM (SELECT gameset_id AS id
                                  FROM game_management.gameset
                                  WHERE season_id = v_season_id
                                  UNION ALL
                                  SELECT gameset_id
                                  FROM input_gamesets
                                  WHERE gameset_id IS NOT NULL) AS ids),
         gamesets_with_new_ids AS (SELECT ordinality,
                                          (SELECT val FROM max_gameset_id) + ROW_NUMBER() OVER (ORDER BY ordinality) AS new_id
                                   FROM input_gamesets
                                   WHERE gameset_id IS NULL)
    INSERT
    INTO temp_gamesets
    (gameset_id,
     transfer_lock_offset,
     transfer_unlock_offset,
     gameset_name,
     gamedays_json)
    SELECT COALESCE(i.gameset_id, n.new_id),
           i.transfer_lock_offset,
           i.transfer_unlock_offset,
           i.gameset_name,
           i.gamedays_json
    FROM input_gamesets i
             LEFT JOIN gamesets_with_new_ids n ON i.ordinality = n.ordinality;

    -- Step 2: Synchronize the game_management.gameset table.
    -- Upsert based on the staged data.
    INSERT INTO game_management.gameset
    (gameset_id,
     season_id,
     gameset_name,
     transfer_lock_offset,
     transfer_unlock_offset)
    SELECT tgs.gameset_id,
           v_season_id,
           tgs.gameset_name,
           tgs.transfer_lock_offset,
           tgs.transfer_unlock_offset
    FROM temp_gamesets tgs
    ON CONFLICT (gameset_id, season_id) DO UPDATE
        SET gameset_name           = EXCLUDED.gameset_name,
            transfer_lock_offset   = EXCLUDED.transfer_lock_offset,
            transfer_unlock_offset = EXCLUDED.transfer_unlock_offset;

    -- Delete gamesets that are not present in the input JSON.
    DELETE
    FROM game_management.gameset
    WHERE season_id = v_season_id
      AND gameset_id NOT IN (SELECT gameset_id FROM temp_gamesets);


    -- Step 3: Parse and stage gamedays from the gameset temp table.
    -- Generate new gameday_ids for entries where it is null.
    WITH raw_gamedays AS (SELECT tgs.gameset_id,
                                 (gd.value ->> 'gameday_id')::SMALLINT                 AS gameday_id,
                                 gd.value ->> 'gameday_name'                           AS gameday_name,
                                 (gd.value ->> 'substitution_lock_offset')::INTERVAL   AS substitution_lock_offset,
                                 (gd.value ->> 'substitution_unlock_offset')::INTERVAL AS substitution_unlock_offset,
                                 gd.value -> 'fixtures'                                AS fixtures_json,
                                 gd.ordinality
                          FROM temp_gamesets tgs,
                               JSONB_ARRAY_ELEMENTS(tgs.gamedays_json) WITH ORDINALITY gd),
         max_gameday_ids AS (SELECT parent_gameset_id,
                                    COALESCE(MAX(id), 0) AS val
                             FROM (SELECT gameset_id AS parent_gameset_id,
                                          gameday_id AS id
                                   FROM game_management.gameday
                                   WHERE season_id = v_season_id
                                   UNION ALL
                                   SELECT gameset_id,
                                          gameday_id
                                   FROM raw_gamedays
                                   WHERE gameday_id IS NOT NULL) AS ids
                             GROUP BY parent_gameset_id),
         gamedays_with_new_ids AS (SELECT gameset_id,
                                          ordinality,
                                          COALESCE(m.val, 0) + ROW_NUMBER() OVER (PARTITION BY gameset_id ORDER BY ordinality) AS new_id
                                   FROM raw_gamedays r
                                            LEFT JOIN max_gameday_ids m ON r.gameset_id = m.parent_gameset_id
                                   WHERE r.gameday_id IS NULL)
    INSERT
    INTO temp_gamedays
    (parent_gameset_id,
     gameday_id,
     gameday_name,
     substitution_lock_offset,
     substitution_unlock_offset,
     fixtures_json)
    SELECT r.gameset_id,
           COALESCE(r.gameday_id, n.new_id),
           r.gameday_name,
           r.substitution_lock_offset,
           r.substitution_unlock_offset,
           r.fixtures_json
    FROM raw_gamedays r
             LEFT JOIN gamedays_with_new_ids n ON r.gameset_id = n.gameset_id AND r.ordinality = n.ordinality;

    -- Step 4: Synchronize the game_management.gameday table.
    -- Upsert based on the staged gameday data.
    INSERT INTO game_management.gameday
    (gameday_id,
     gameset_id,
     season_id,
     gameday_name,
     substitution_lock_offset,
     substitution_unlock_offset)
    SELECT tgd.gameday_id,
           tgd.parent_gameset_id,
           v_season_id,
           tgd.gameday_name,
           tgd.substitution_lock_offset,
           tgd.substitution_unlock_offset
    FROM temp_gamedays tgd
    ON CONFLICT (gameday_id, season_id, gameset_id)
        DO UPDATE
        SET gameday_name               = EXCLUDED.gameday_name,
            substitution_lock_offset   = EXCLUDED.substitution_lock_offset,
            substitution_unlock_offset = EXCLUDED.substitution_unlock_offset;

    -- Delete gamedays associated with the input gamesets that are not in the input JSON.
    DELETE
    FROM game_management.gameday
    WHERE season_id = v_season_id
      AND gameset_id IN (SELECT gameset_id FROM temp_gamesets)
      AND (gameset_id, gameday_id) NOT IN (SELECT parent_gameset_id, gameday_id FROM temp_gamedays);

    -- Step 5: Update fixture mappings.
    -- First, clear all existing gameset/gameday mappings for the entire season.
    UPDATE game_management.fixture
    SET gameset_id   = NULL,
        gameday_id   = NULL,
        updated_date = CURRENT_TIMESTAMP
    WHERE season_id = v_season_id;

    -- Then, apply the new mappings from the staged gameday data.
    WITH fixture_mappings AS (SELECT tgd.parent_gameset_id                                   AS gameset_id,
                                     tgd.gameday_id,
                                     (JSONB_ARRAY_ELEMENTS_TEXT(tgd.fixtures_json))::INTEGER AS fixture_id
                              FROM temp_gamedays tgd)
    UPDATE game_management.fixture f
    SET gameset_id   = fm.gameset_id,
        gameday_id   = fm.gameday_id,
        updated_date = CURRENT_TIMESTAMP
    FROM fixture_mappings fm
    WHERE f.season_id = v_season_id
      AND f.fixture_id = fm.fixture_id;

    BEGIN
        SELECT a.game_type_id
        INTO v_game_variant_id
        FROM engine_config.season s
                 JOIN engine_config.application a
                      ON s.application_id = a.application_id
        WHERE s.season_id = v_season_id;


        IF v_game_variant_id = 1 THEN

            INSERT INTO game_play.gameset_player
            (player_id,
             gameset_id,
             season_id,
             skill_id,
             player_value,
             team_id,
             is_active,
             availability_status,
             availability_desc,
             points,
             player_stats)
            SELECT p.player_id,
                   G.gameset_id,
                   v_season_id,
                   p.skill_id,
                   COALESCE(p.player_value, 0),
                   p.team_id,
                   TRUE,
                   1,
                   0,
                   0,
                   NULL
            FROM game_management.player P
                     JOIN game_management.gameset G
                          ON G.season_id = P.season_id
            WHERE p.is_active = TRUE
              AND p.season_id = v_season_id
              AND G.season_id = v_season_id
              AND p.team_id IS NOT NULL
            ON CONFLICT (player_id, gameset_id, season_id)
                DO UPDATE
                SET skill_id            = EXCLUDED.skill_id,
                    player_value        = EXCLUDED.player_value,
                    team_id             = EXCLUDED.team_id,
                    is_active           = EXCLUDED.is_active,
                    availability_status = EXCLUDED.availability_status,
                    availability_desc   = EXCLUDED.availability_desc,
                    points              = EXCLUDED.points,
                    player_stats        = EXCLUDED.player_stats;

        ELSEIF v_game_variant_id = 2 THEN

            DELETE
            FROM game_play.gameset_player
            WHERE season_id = v_season_id;

            INSERT INTO game_play.gameset_player
            (player_id,
             gameset_id,
             season_id,
             skill_id,
             player_value,
             team_id,
             is_active,
             availability_status,
             availability_desc,
             points,
             player_stats)
            SELECT p.player_id,
                   f.gameset_id,
                   v_season_id,
                   p.skill_id,
                   p.player_value,
                   team_val.team_id,
                   TRUE,
                   1,
                   0,
                   0,
                   NULL
            FROM game_management.player p
                     JOIN game_management.fixture f
                          ON f.season_id = v_season_id
                              AND p.season_id = v_season_id
                              AND f.gameset_id IS NOT NULL
                     JOIN LATERAL (
                SELECT (prop.elem ->> 'value')::INTEGER AS team_id
                FROM JSONB_ARRAY_ELEMENTS(f.sport_properties) AS prop(elem)
                WHERE (prop.elem ->> 'property_name') ~* 'team.*id$'
                ) AS team_val ON p.team_id = team_val.team_id::INTEGER
            WHERE p.is_active = TRUE
              AND p.season_id = v_season_id
              AND p.player_value IS NOT NULL
              AND team_val.team_id IS NOT NULL;

        END IF;
    END;

    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        -- Clean up temp tables on error to prevent them from persisting.
        DROP TABLE IF EXISTS temp_gamesets, temp_gamedays;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.fixture_mapping',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_gameset_player(p_language_code character varying, p_season_id numeric, p_set_id numeric, OUT p_ret_type numeric, OUT p_player_data jsonb) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_player_data jsonb;
BEGIN
    SELECT JSONB_AGG(row)
    INTO v_player_data
    FROM (SELECT GP.player_id,
                 P.player_name,
                 P.player_display_name,
                 P.skill_id,
                 P.skill_name,
                 SS.skill_short_name,
                 P.team_id,
                 T.team_name,
                 GP.points,
                 GP.player_value
          FROM game_play.gameset_player GP
                   JOIN game_management.player P
                        ON GP.player_id = P.player_id
                            AND P.language_code ILIKE p_language_code
                   JOIN game_management.team T
                        ON GP.team_id = T.team_id
                            AND T.language_code ILIKE p_language_code
                   JOIN engine_config.sport_skill SS
                        ON P.skill_id = SS.skill_id
          WHERE GP.season_id = p_season_id
            AND GP.gameset_id = p_set_id) row;

    IF v_player_data IS NULL THEN
        p_ret_type := 3;
        p_player_data := '[]'::jsonb;
    ELSE
        p_player_data := JSONB_BUILD_OBJECT(
                'players', v_player_data
                         );
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_player_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_gameset_player',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('language_code', p_language_code, 'season_id', p_season_id, 'set_id', p_set_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_offload_location(p_season_id integer, OUT p_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT offload_location
    INTO p_json
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_json IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_json := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_offload_location',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_set_wise_fixtures(p_season_id integer, OUT p_fixture_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_gameset_json   jsonb;
    v_offset_type_id INTEGER;
    v_offset_type    VARCHAR;
    v_lock_offset    jsonb;
    v_unlock_offset  jsonb;
BEGIN
    SELECT JSONB_AGG(gamesets)
    INTO v_gameset_json
    FROM (SELECT f.gameset_id   AS gameset_id,
                 f.gameset_name AS gameset_name,
                 JSONB_AGG(
                         JSONB_BUILD_OBJECT(
                                 'fixture_id', f.fixture_id,
                                 'fixture_name', f.fixture_name,
                                 'season_id', f.season_id,
                                 'fixture_date', f.fixture_date_gmt,
                                 'fixture_time', f.fixture_time_gmt,
                                 'fixture_status', f.fixture_status,
                                 'phase_name', f.phase_name,
                                 'venue', f.venue,
                                 'fixture_type', f.fixture_type,
                                 'sport_properties', f.sport_properties,
                                 'fixture_result', f.fixture_result
                         )
                 )              AS fixtures
          FROM game_management.fixture_en f
          WHERE f.season_id = p_season_id
            AND gameset_id IS NOT NULL
          GROUP BY f.gameset_id, f.gameset_name) gamesets;

    SELECT f.offset_type AS offset_type_id,
           o.offset_type,
           f.lock_offset,
           f.unlock_offset
    INTO v_offset_type_id,
        v_offset_type,
        v_lock_offset,
        v_unlock_offset
    FROM game_management.fixture_en f
             JOIN engine_config.offset_type o
                  ON f.offset_type = o.offset_type_id
    WHERE season_id = p_season_id
      AND gameset_id IS NOT NULL
    LIMIT 1;

    IF v_gameset_json IS NOT NULL THEN
        p_fixture_json := JSONB_BUILD_OBJECT(
                'gameset', v_gameset_json,
                'offset_type_id', v_offset_type_id,
                'offset_type', v_offset_type,
                'lock_offset', v_lock_offset,
                'unlock_offset', v_unlock_offset
                          );
        p_ret_type := 1;
    ELSE
        p_fixture_json := JSONB_BUILD_OBJECT(
                'gameset', '[]'::jsonb
                          );
        p_ret_type := 3;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_fixture_json := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_set_wise_fixtures',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.ins_upd_offload_location(p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "languages": {
    "file_name": "dxfcghjk",
    "offload_location": "s3",
    "bucket_path": "dfghjk"
  },
  "scores": {
    "file_name": "dsrftyuh",
    "offload_location": "redis",
    "bucket_path": "zdxfghjk"
  },
  "venue": {
    "expiry": {
      "unit": 1,
      "value": "xdfcgvh"
    },
    "base_key": "xdfcghj",
    "asset_path": "dxfghjk",
    "offload_location": "memcache",
    "file_name": "dfghjk"
  },
  "teams": {
    "expiry": {
      "unit": 1,
      "value": "szdxfcgvhbn"
    },
    "base_key": "sdfghj",
    "asset_path": "szdxfghjk",
    "offload_location": "filesystem",
    "file_name": "dxfghjk"
  },
  "players": {
    "file_name": "dfghjk",
    "offload_location": "redis",
    "bucket_path": "dfghjk"
  },
  "fixtures": {
    "file_name": "dfghjk",
    "offload_location": "s3",
    "file_path": "dfghj"
  },
  "season_id": 1
}
*/
DECLARE
    v_season_id SMALLINT;
    v_row_count INT;
BEGIN
    v_season_id := (p_input_json ->> 'season_id')::SMALLINT;

    INSERT INTO engine_config.season_config
    (season_id,
     offload_location)
    SELECT v_season_id,
           p_input_json
    ON CONFLICT (season_id)
        DO UPDATE SET offload_location = EXCLUDED.offload_location;
    
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 101;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.ins_upd_offload_location',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.ins_upd_fixture(p_opt_type integer, p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
p_opt_type: 1 - UPSERT based on (source_id, season_id) - uses manual upsert due to limitations
p_opt_type: 2 - UPSERT based on primary key (fixture_id, season_id) - uses ON CONFLICT
{
  "fixtures": [
    {
      "source_id": "fix-src-abc",
      "fixture_name": "Team A vs Team B",
      "fixture_display_name": "Team A vs Team B",
      "fixture_number": "M1",
      "fixture_status": 0,
      "fixture_datetime_iso8601": "2025-07-20T18:00:00Z",
      "fixture_format": "T20",
      "venue_source_id": "venue-src-01",
      "venue_id": 101,
      "lineup_announced": false,
      "sport_properties": [
        {
          "value": "533",
          "property_name": "series_id"
        },
        {
          "value": "Indian Super League, 2024-25",
          "property_name": "series_name"
        },
        {
          "value": "1874",
          "property_name": "team1_source_id"
        },
        {
          "value": "Mohun Bagan Super Giant",
          "property_name": "team1_name"
        },
        {
          "value": "Mumbai City FC",
          "property_name": "team2_name"
        },
        {
          "value": "506",
          "property_name": "team2_source_id"
        },
        {
          "value": "Match Drawn",
          "property_name": "fixture_result"
        }
      ]
    }
  ],
  "season_id": 1,
  "series_id": "s-100"
}
*/
DECLARE
    v_season_id SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_series_id VARCHAR  := p_input_json ->> 'series_id';
    v_row_count INT      := 0;
    v_venue_map JSONB;
    v_team_map  JSONB;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT COALESCE(JSONB_OBJECT_AGG(source_id, venue_id)
                    FILTER (WHERE source_id IS NOT NULL), '{}'::jsonb)
    INTO v_venue_map
    FROM game_management.venue
    WHERE season_id = v_season_id;

    SELECT COALESCE(JSONB_OBJECT_AGG(source_id, team_id)
                    FILTER (WHERE source_id IS NOT NULL), '{}'::jsonb)
    INTO v_team_map
    FROM game_management.team
    WHERE season_id = v_season_id;

    IF p_opt_type = 1 THEN
        WITH input_data AS (SELECT x.source_id,
                                   v_season_id                              AS season_id,
                                   v_series_id                              AS series_id,
                                   x.fixture_name,
                                   x.fixture_display_name,
                                   x.fixture_file,
                                   x.fixture_number,
                                   x.fixture_status,
                                   x.fixture_datetime_iso8601,
                                   x.fixture_format,
                                   (v_venue_map ->> x.venue_source_id)::INT AS venue_id,
                                   COALESCE(x.lineup_announced, FALSE)      AS lineup_announced,
                                   x.sport_properties || COALESCE(
                                           (SELECT JSONB_AGG(
                                                           JSONB_BUILD_OBJECT(
                                                                   'property_name', REPLACE(elem ->> 'property_name', '_source_id', '_id'),
                                                                   'value', (v_team_map ->> (elem ->> 'value'))::INT
                                                           )
                                                   )
                                            FROM JSONB_ARRAY_ELEMENTS(x.sport_properties) AS t(elem)
                                            WHERE elem ->> 'property_name' LIKE '%_source_id'), '[]'::jsonb
                                                         )                  AS sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'fixtures') AS x(
                                                                                     source_id VARCHAR(100),
                                                                                     fixture_name VARCHAR(255),
                                                                                     fixture_display_name VARCHAR(255),
                                                                                     fixture_file VARCHAR(255),
                                                                                     fixture_number VARCHAR(255),
                                                                                     fixture_status SMALLINT,
                                                                                     fixture_datetime_iso8601 TIMESTAMPTZ,
                                                                                     fixture_format VARCHAR(255),
                                                                                     venue_source_id VARCHAR(100),
                                                                                     lineup_announced BOOLEAN,
                                                                                     sport_properties JSONB
                                )
                            WHERE x.source_id IS NOT NULL
                              AND x.source_id <> ''),
             updates AS (
                 UPDATE game_management.fixture f
                     SET fixture_name = i.fixture_name,
                         fixture_display_name = i.fixture_display_name,
                         fixture_file = i.fixture_file,
                         series_id = i.series_id,
                         fixture_number = i.fixture_number,
                         fixture_status = i.fixture_status,
                         fixture_datetime_iso8601 = i.fixture_datetime_iso8601,
                         fixture_format = i.fixture_format,
                         venue_id = i.venue_id,
                         lineup_announced = i.lineup_announced,
                         sport_properties = i.sport_properties,
                         updated_date = CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE f.source_id = i.source_id
                         AND f.season_id = i.season_id
                     RETURNING 1),
             inserts AS (
                 INSERT INTO game_management.fixture
                     (fixture_id,
                      source_id,
                      season_id,
                      series_id,
                      fixture_name,
                      fixture_display_name,
                      fixture_file,
                      fixture_number,
                      fixture_status,
                      fixture_datetime_iso8601,
                      fixture_format,
                      venue_id,
                      lineup_announced,
                      sport_properties,
                      created_date,
                      updated_date)
                     SELECT NEXTVAL('game_management.fixture_id_seq'),
                            i.source_id,
                            i.season_id,
                            i.series_id,
                            i.fixture_name,
                            i.fixture_display_name,
                            i.fixture_file,
                            i.fixture_number,
                            i.fixture_status,
                            i.fixture_datetime_iso8601,
                            i.fixture_format,
                            i.venue_id,
                            i.lineup_announced,
                            i.sport_properties,
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE NOT EXISTS (SELECT 1
                                       FROM game_management.fixture f
                                       WHERE f.source_id = i.source_id
                                         AND f.season_id = i.season_id)
                     RETURNING 1)
        SELECT (SELECT COUNT(*) FROM updates) + (SELECT COUNT(*) FROM inserts)
        INTO v_row_count;

    ELSIF p_opt_type = 2 THEN
        WITH input_data AS (SELECT COALESCE(x.fixture_id, NEXTVAL('game_management.fixture_id_seq')) AS fixture_id,
                                   x.source_id,
                                   v_season_id                                                       AS season_id,
                                   v_series_id                                                       AS series_id,
                                   x.fixture_name,
                                   x.fixture_display_name,
                                   x.fixture_file,
                                   x.fixture_number,
                                   x.fixture_status,
                                   x.fixture_datetime_iso8601,
                                   x.fixture_format,
                                   x.venue_id,
                                   COALESCE(x.lineup_announced, FALSE)                               AS lineup_announced,
                                   x.sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'fixtures') AS x(
                                                                                     fixture_id INTEGER,
                                                                                     source_id VARCHAR(100),
                                                                                     fixture_name VARCHAR(255),
                                                                                     fixture_display_name VARCHAR(255),
                                                                                     fixture_file VARCHAR(255),
                                                                                     fixture_number VARCHAR(255),
                                                                                     fixture_status SMALLINT,
                                                                                     fixture_datetime_iso8601 TIMESTAMPTZ,
                                                                                     fixture_format VARCHAR(255),
                                                                                     venue_id INTEGER,
                                                                                     lineup_announced BOOLEAN,
                                                                                     sport_properties JSONB
                                ))
        INSERT
        INTO game_management.fixture
        (fixture_id,
         source_id,
         season_id,
         series_id,
         fixture_name,
         fixture_display_name,
         fixture_file,
         fixture_number,
         fixture_status,
         fixture_datetime_iso8601,
         fixture_format,
         venue_id,
         lineup_announced,
         sport_properties,
         created_date,
         updated_date)
        SELECT i.fixture_id,
               i.source_id,
               i.season_id,
               i.series_id,
               i.fixture_name,
               i.fixture_display_name,
               i.fixture_file,
               i.fixture_number,
               i.fixture_status,
               i.fixture_datetime_iso8601,
               i.fixture_format,
               i.venue_id,
               i.lineup_announced,
               i.sport_properties,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP
        FROM input_data i
        ON CONFLICT (fixture_id, season_id) DO UPDATE
            SET source_id                = EXCLUDED.source_id,
                series_id                = EXCLUDED.series_id,
                fixture_name             = EXCLUDED.fixture_name,
                fixture_display_name     = EXCLUDED.fixture_display_name,
                fixture_file             = EXCLUDED.fixture_file,
                fixture_number           = EXCLUDED.fixture_number,
                fixture_status           = EXCLUDED.fixture_status,
                fixture_datetime_iso8601 = EXCLUDED.fixture_datetime_iso8601,
                fixture_format           = EXCLUDED.fixture_format,
                venue_id                 = EXCLUDED.venue_id,
                lineup_announced         = EXCLUDED.lineup_announced,
                sport_properties         = EXCLUDED.sport_properties,
                updated_date             = CURRENT_TIMESTAMP;

        GET DIAGNOSTICS v_row_count = ROW_COUNT;

    ELSE
        p_ret_type := 2; -- Invalid option type
        RETURN;
    END IF;

    -- Check results
    IF v_row_count = JSONB_ARRAY_LENGTH(p_input_json -> 'fixtures') THEN
        p_ret_type := 1; -- Success
    ELSE
        p_ret_type := 101; -- Partial success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1; -- Error
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.ins_upd_fixture',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.ins_upd_player(p_opt_type integer, p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
p_opt_type: 1 - UPSERT based on (source_id, season_id, series_id)
p_opt_type: 2 - UPSERT based on primary key (player_id, season_id)
{
  "players": [
    {
      "source_id": "12dv2sa9xm0aedpb13ivl11wp",
      "player_name": "Fahad Ayidh Ateeq Al Arari Al Rashidi",
      "player_display_name": "Fahad Ayidh Ateeq Al Arari Al Rashidi",
      "player_short_name": "Fahad",
      "skill_id": 4,
      "team_source_id": "aj1bdyuwq8pdwycaa9kba8uni", -- opt_type = 1
      "team_id": 1, -- opt_type = 2
      "sport_properties": null,
      "player_value": 100.00,
      "is_foreign_player": false,
      "is_active": true
    }
  ],
  "series_id": 533,
  "season_id": 1
}
*/
DECLARE
    v_season_id SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_series_id VARCHAR  := p_input_json ->> 'series_id';
    v_row_count INT      := 0;
    v_team_map  JSONB;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT COALESCE(JSONB_OBJECT_AGG(source_id, team_id)
                    FILTER (WHERE source_id IS NOT NULL), '{}'::jsonb)
    INTO v_team_map
    FROM game_management.team
    WHERE season_id = v_season_id;

    IF p_opt_type = 1 THEN
        WITH input_data AS (SELECT x.source_id,
                                   v_season_id                            AS season_id,
                                   v_series_id                            AS series_id,
                                   x.player_name,
                                   x.player_display_name,
                                   x.player_short_name,
                                   x.skill_id,
                                   (v_team_map ->> x.team_source_id)::INT AS team_id,
                                   x.sport_properties,
                                   COALESCE(x.player_value, 0)            AS player_value,
                                   COALESCE(x.is_foreign_player, FALSE)   AS is_foreign_player,
                                   COALESCE(x.is_active, TRUE)            AS is_active
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'players') AS x(
                                                                                    source_id VARCHAR(100),
                                                                                    player_name VARCHAR(255),
                                                                                    player_display_name VARCHAR(255),
                                                                                    player_short_name VARCHAR(255),
                                                                                    skill_id SMALLINT,
                                                                                    team_source_id VARCHAR(100),
                                                                                    sport_properties JSONB,
                                                                                    player_value NUMERIC(10, 2),
                                                                                    is_foreign_player BOOLEAN,
                                                                                    is_active BOOLEAN
                                )),
             updates AS (
                 UPDATE game_management.player p
                     SET player_name = i.player_name,
                         player_display_name = i.player_display_name,
                         player_short_name = i.player_short_name,
                         skill_id = i.skill_id,
                         team_id = i.team_id,
                         sport_properties = i.sport_properties,
                         player_value = i.player_value,
                         is_foreign_player = i.is_foreign_player,
                         is_active = i.is_active,
                         updated_date = CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE p.source_id = i.source_id
                         AND p.season_id = i.season_id
                     RETURNING 1),
             inserts AS (
                 INSERT INTO game_management.player
                     (player_id,
                      source_id,
                      season_id,
                      series_id,
                      player_name,
                      player_display_name,
                      player_short_name,
                      skill_id,
                      team_id,
                      sport_properties,
                      player_value,
                      is_foreign_player,
                      is_active,
                      created_date,
                      updated_date)
                     SELECT NEXTVAL('game_management.player_id_seq'),
                            i.source_id,
                            i.season_id,
                            i.series_id,
                            i.player_name,
                            i.player_display_name,
                            i.player_short_name,
                            i.skill_id,
                            i.team_id,
                            i.sport_properties,
                            i.player_value,
                            i.is_foreign_player,
                            i.is_active,
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE NOT EXISTS (SELECT 1
                                       FROM game_management.player p
                                       WHERE p.source_id = i.source_id
                                         AND p.season_id = i.season_id)
                     RETURNING 1)
        SELECT (SELECT COUNT(*) FROM updates) + (SELECT COUNT(*) FROM inserts)
        INTO v_row_count;

    ELSIF p_opt_type = 2 THEN
        WITH input_data AS (SELECT COALESCE(x.player_id, NEXTVAL('game_management.player_id_seq')) AS player_id,
                                   x.source_id,
                                   v_season_id                                                     AS season_id,
                                   v_series_id                                                     AS series_id,
                                   x.player_name,
                                   x.player_display_name,
                                   x.player_short_name,
                                   x.skill_id,
                                   x.team_id,
                                   x.sport_properties,
                                   COALESCE(x.player_value, 0)                                     AS player_value,
                                   COALESCE(x.is_foreign_player, FALSE)                            AS is_foreign_player,
                                   COALESCE(x.is_active, TRUE)                                     AS is_active
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'players') AS x(
                                                                                    player_id INTEGER,
                                                                                    source_id VARCHAR(100),
                                                                                    player_name VARCHAR(255),
                                                                                    player_display_name VARCHAR(255),
                                                                                    player_short_name VARCHAR(255),
                                                                                    skill_id SMALLINT,
                                                                                    team_id INTEGER,
                                                                                    sport_properties JSONB,
                                                                                    player_value NUMERIC(10, 2),
                                                                                    is_foreign_player BOOLEAN,
                                                                                    is_active BOOLEAN
                                ))
        INSERT
        INTO game_management.player
        (player_id,
         source_id,
         season_id,
         series_id,
         player_name,
         player_display_name,
         player_short_name,
         skill_id,
         team_id,
         sport_properties,
         player_value,
         is_foreign_player,
         is_active,
         created_date,
         updated_date)
        SELECT i.player_id,
               i.source_id,
               i.season_id,
               i.series_id,
               i.player_name,
               i.player_display_name,
               i.player_short_name,
               i.skill_id,
               i.team_id,
               i.sport_properties,
               i.player_value,
               i.is_foreign_player,
               i.is_active,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP
        FROM input_data i
        ON CONFLICT (player_id, season_id) DO UPDATE
            SET source_id         = EXCLUDED.source_id,
                series_id         = EXCLUDED.series_id,
                player_name       = EXCLUDED.player_name,
                player_display_name = EXCLUDED.player_display_name,
                player_short_name = EXCLUDED.player_short_name,
                skill_id          = EXCLUDED.skill_id,
                team_id           = EXCLUDED.team_id,
                sport_properties  = EXCLUDED.sport_properties,
                player_value      = EXCLUDED.player_value,
                is_foreign_player = EXCLUDED.is_foreign_player,
                is_active         = EXCLUDED.is_active,
                updated_date      = CURRENT_TIMESTAMP;

        GET DIAGNOSTICS v_row_count = ROW_COUNT;

    ELSE
        p_ret_type := 2; -- Invalid option type
        RETURN;
    END IF;

    -- Check results
    IF v_row_count = JSONB_ARRAY_LENGTH(p_input_json -> 'players') THEN
        p_ret_type := 1; -- Success
    ELSE
        p_ret_type := 101; -- Partial or no success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.ins_upd_player',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.ins_upd_team(p_opt_type integer, p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
p_opt_type: 1 - UPSERT based on (source_id, season_id)
p_opt_type: 2 - UPSERT based on primary key (team_id, season_id)
{
  "teams": [
    {
      "source_id": "12dv2sa9xm0aedpb13ivl11wp",
      "team_name": "india",
      "team_display_name": "india",
      "team_short_code": "ind",
      "sport_properties": null
    }
  ],
  "season_id": 1,
  "series_id": 123
}
*/
DECLARE
    v_season_id SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_series_id VARCHAR  := p_input_json ->> 'series_id';
    v_row_count INT      := 0;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    IF p_opt_type = 1 THEN
        WITH input_data AS (SELECT x.source_id,
                                   v_season_id AS season_id,
                                   v_series_id AS series_id,
                                   x.team_name,
                                   x.team_display_name,
                                   x.team_short_code,
                                   x.sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'teams') AS x(
                                                                                  source_id VARCHAR(100),
                                                                                  team_name VARCHAR(255),
                                                                                  team_display_name VARCHAR(255),
                                                                                  team_short_code VARCHAR(64),
                                                                                  sport_properties JSONB
                                )),
             updates AS (
                 UPDATE game_management.team t
                     SET series_id = i.series_id,
                         team_name = i.team_name,
                         team_short_code = i.team_short_code,
                         sport_properties = i.sport_properties,
                         updated_date = CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE t.source_id = i.source_id
                         AND t.season_id = i.season_id
                     RETURNING 1),
             inserts AS (
                 INSERT INTO game_management.team
                     (team_id,
                      source_id,
                      season_id,
                      series_id,
                      team_name,
                      team_display_name,
                      team_short_code,
                      sport_properties,
                      created_date,
                      updated_date)
                     SELECT NEXTVAL('game_management.team_id_seq'),
                            i.source_id,
                            i.season_id,
                            i.series_id,
                            i.team_name,
                            i.team_display_name,
                            i.team_short_code,
                            i.sport_properties,
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE NOT EXISTS (SELECT 1
                                       FROM game_management.team t
                                       WHERE t.source_id = i.source_id
                                         AND t.season_id = i.season_id)
                     RETURNING 1)
        SELECT (SELECT COUNT(*) FROM updates) + (SELECT COUNT(*) FROM inserts)
        INTO v_row_count;

    ELSIF p_opt_type = 2 THEN
        WITH input_data AS (SELECT COALESCE(x.team_id, NEXTVAL('game_management.team_id_seq')) AS team_id,
                                   x.source_id,
                                   v_season_id                                                 AS season_id,
                                   v_series_id                                                 AS series_id,
                                   x.team_name,
                                   x.team_display_name,
                                   x.team_short_code,
                                   x.sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'teams') AS x(
                                                                                  team_id INTEGER,
                                                                                  source_id VARCHAR(100),
                                                                                  team_name VARCHAR(255),
                                                                                  team_display_name VARCHAR(255),
                                                                                  team_short_code VARCHAR(64),
                                                                                  sport_properties JSONB
                                ))
        INSERT
        INTO game_management.team
        (team_id,
         source_id,
         season_id,
         series_id,
         team_name,
         team_display_name,
         team_short_code,
         sport_properties,
         created_date,
         updated_date)
        SELECT i.team_id,
               i.source_id,
               i.season_id,
               i.series_id,
               i.team_name,
               i.team_display_name,
               i.team_short_code,
               i.sport_properties,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP
        FROM input_data i
        ON CONFLICT (team_id, season_id) DO UPDATE
            SET source_id        = EXCLUDED.source_id,
                series_id        = EXCLUDED.series_id,
                team_name        = EXCLUDED.team_name,
                team_display_name = EXCLUDED.team_display_name,
                team_short_code  = EXCLUDED.team_short_code,
                sport_properties = EXCLUDED.sport_properties,
                updated_date     = CURRENT_TIMESTAMP;

        GET DIAGNOSTICS v_row_count = ROW_COUNT;

    ELSE
        p_ret_type := 2; -- Invalid option type
        RETURN;
    END IF;

    -- Check results
    IF v_row_count = JSONB_ARRAY_LENGTH(p_input_json -> 'teams') THEN
        p_ret_type := 1; -- Success
    ELSE
        p_ret_type := 101; -- Partial or no success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.ins_upd_team',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.ins_upd_venue(p_opt_type integer, p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
p_opt_type: 1 - UPSERT based on (source_id, season_id)
p_opt_type: 2 - UPSERT based on primary key (venue_id, season_id)
{
  "venues": [
    {
      "source_id": "12dv2sa9xm0aedpb13ivl11wp",
      "location1": "location1",
      "location1_display_name": "location1",
      "location2": "location2",
      "location2_display_name": "location2",
      "location3": "location3",
      "location3_display_name": "location3",
      "sport_properties": null
    }
  ],
  "season_id": 1
}
*/
DECLARE
    v_season_id SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_row_count INT      := 0;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    IF p_opt_type = 1 THEN
        WITH input_data AS (SELECT x.source_id,
                                   v_season_id AS season_id,
                                   x.location1,
                                   x.location1_display_name,
                                   x.location2,
                                   x.location2_display_name,
                                   x.location3,
                                   x.location3_display_name,
                                   x.sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'venues') AS x(
                                                                                   source_id VARCHAR(100),
                                                                                   location1 VARCHAR(255),
                                                                                   location1_display_name VARCHAR(255),
                                                                                   location2 VARCHAR(255),
                                                                                   location2_display_name VARCHAR(255),
                                                                                   location3 VARCHAR(255),
                                                                                   location3_display_name VARCHAR(255),
                                                                                   sport_properties JSONB
                                )),
             updates AS (
                 UPDATE game_management.venue v
                     SET location1 = i.location1,
                         location1_display_name = i.location1_display_name,
                         location2 = i.location2,
                         location2_display_name = i.location2_display_name,
                         location3 = i.location3,
                         location3_display_name = i.location3_display_name,
                         sport_properties = i.sport_properties,
                         updated_date = CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE v.source_id = i.source_id
                         AND v.season_id = i.season_id
                     RETURNING 1),
             inserts AS (
                 INSERT INTO game_management.venue
                     (venue_id,
                      source_id,
                      season_id,
                      location1,
                      location1_display_name,
                      location2,
                      location2_display_name,
                      location3,
                      location3_display_name,
                      sport_properties,
                      created_date,
                      updated_date)
                     SELECT NEXTVAL('game_management.venue_id_seq'),
                            i.source_id,
                            i.season_id,
                            i.location1,
                            i.location1_display_name,
                            i.location2,
                            i.location2_display_name,
                            i.location3,
                            i.location3_display_name,
                            i.sport_properties,
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                     FROM input_data i
                     WHERE NOT EXISTS (SELECT 1
                                       FROM game_management.venue v
                                       WHERE v.source_id = i.source_id
                                         AND v.season_id = i.season_id)
                     RETURNING 1)
        SELECT (SELECT COUNT(*) FROM updates) + (SELECT COUNT(*) FROM inserts)
        INTO v_row_count;

    ELSIF p_opt_type = 2 THEN
        WITH input_data AS (SELECT COALESCE(x.venue_id, NEXTVAL('game_management.venue_id_seq')) AS venue_id,
                                   x.source_id,
                                   v_season_id                                                   AS season_id,
                                   x.location1,
                                   x.location1_display_name,
                                   x.location2,
                                   x.location2_display_name,
                                   x.location3,
                                   x.location3_display_name,
                                   x.sport_properties
                            FROM JSONB_TO_RECORDSET(p_input_json -> 'venues') AS x(
                                                                                   venue_id INTEGER,
                                                                                   source_id VARCHAR(100),
                                                                                   location1 VARCHAR(255),
                                                                                   location1_display_name VARCHAR(255),
                                                                                   location2 VARCHAR(255),
                                                                                   location2_display_name VARCHAR(255),
                                                                                   location3 VARCHAR(255),
                                                                                   location3_display_name VARCHAR(255),
                                                                                   sport_properties JSONB
                                ))
        INSERT
        INTO game_management.venue
        (venue_id,
         source_id,
         season_id,
         location1,
         location1_display_name,
         location2,
         location2_display_name,
         location3,
         location3_display_name,
         sport_properties,
         created_date,
         updated_date)
        SELECT i.venue_id,
               i.source_id,
               i.season_id,
               i.location1,
               i.location1_display_name,
               i.location2,
               i.location2_display_name,
               i.location3,
               i.location3_display_name,
               i.sport_properties,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP
        FROM input_data i
        ON CONFLICT (venue_id, season_id) DO UPDATE
            SET source_id        = EXCLUDED.source_id,
                location1        = EXCLUDED.location1,
                location1_display_name = EXCLUDED.location1_display_name,
                location2        = EXCLUDED.location2,
                location2_display_name = EXCLUDED.location2_display_name,
                location3        = EXCLUDED.location3,
                location3_display_name = EXCLUDED.location3_display_name,
                sport_properties = EXCLUDED.sport_properties,
                updated_date     = CURRENT_TIMESTAMP;

        GET DIAGNOSTICS v_row_count = ROW_COUNT;

    ELSE
        p_ret_type := 2; -- Invalid option type
        RETURN;
    END IF;

    -- Check results
    IF v_row_count = JSONB_ARRAY_LENGTH(p_input_json -> 'venues') THEN
        p_ret_type := 1; -- Success
    ELSE
        p_ret_type := 101; -- Partial or no success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.ins_upd_venue',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_fixture(p_season_id integer, OUT p_fixture_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_agg_fixtures JSONB;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'fixture_id', f.fixture_id,
                           'source_id', f.source_id,
                           'season_id', f.season_id,
                           'gameset_id', f.gameset_id,
                           'gameset_name', gs.gameset_name,
                           'gameday_id', f.gameday_id,
                           'gameday_name', gd.gameday_name,
                           'phase_id', f.phase_id,
                           'phase_name', ph.phase_name,
                           'series_id', f.series_id,
                           'fixture_name', f.fixture_name,
                           'fixture_display_name', f.fixture_display_name,
                           'fixture_file', f.fixture_file,
                           'fixture_number', f.fixture_number,
                           'fixture_status', f.fixture_status,
                           'fixture_datetime_iso8601', f.fixture_datetime_iso8601,
                           'fixture_format', f.fixture_format,
                           'venue_id', f.venue_id,
                           'venue_source_id', v.source_id,
                           'location1', v.location1,
                           'location1_display_name', v.location1_display_name,
                           'location2', v.location2,
                           'location2_display_name', v.location2_display_name,
                           'location3', v.location3,
                           'location3_display_name', v.location3_display_name,
                           'lineup_announced', f.lineup_announced,
                           'transfer_lock_offset', gs.transfer_lock_offset,
                           'transfer_unlock_offset', gs.transfer_unlock_offset,
                           'substitution_lock_offset', gd.substitution_lock_offset,
                           'substitution_unlock_offset', gd.substitution_unlock_offset,
                           'sport_properties', f.sport_properties,
                           'created_date', f.created_date,
                           'updated_date', f.updated_date
                   )
           ORDER BY f.fixture_id
           )
    INTO v_agg_fixtures
    FROM game_management.fixture f
             LEFT JOIN game_management.venue v
                       ON f.venue_id = v.venue_id
                           AND f.season_id = v.season_id
             LEFT JOIN game_management.gameset gs
                       ON f.gameset_id = gs.gameset_id
                           AND f.season_id = gs.season_id
             LEFT JOIN game_management.gameday gd
                       ON f.gameday_id = gd.gameday_id
                           AND f.season_id = gd.season_id
                           AND f.gameset_id = gd.gameset_id
             LEFT JOIN game_management.phase ph
                       ON f.phase_id = ph.phase_id
                           AND f.season_id = ph.season_id
    WHERE f.season_id = p_season_id;

    IF v_agg_fixtures IS NULL THEN
        p_fixture_json := '{
          "fixtures": []
        }'::jsonb;
        p_ret_type := 3; -- Not Found
    ELSE
        p_fixture_json := JSONB_BUILD_OBJECT('fixtures', v_agg_fixtures);
        p_ret_type := 1; -- Success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_fixture_json := NULL;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_fixture',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_player(p_season_id integer, OUT p_player_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_agg_players JSONB;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'player_id', p.player_id,
                           'source_id', p.source_id,
                           'season_id', p.season_id,
                           'series_id', p.series_id,
                           'team_id', p.team_id,
                           'team_name', t.team_name,
                           'team_display_name', t.team_display_name,
                           'player_name', p.player_name,
                           'player_display_name', p.player_display_name,
                           'player_short_name', p.player_short_name,
                           'skill_id', p.skill_id,
                           'skill_name', ss.skill_name,
                           'is_foreign_player', p.is_foreign_player,
                           'player_value', p.player_value,
                           'sport_properties', p.sport_properties,
                           'created_date', p.created_date,
                           'updated_date', p.updated_date
                   )
           )
    INTO v_agg_players
    FROM game_management.player p
             LEFT JOIN game_management.team t
                       ON p.team_id = t.team_id AND p.season_id = t.season_id
             JOIN engine_config.sport_skill ss
                  ON ss.skill_id = p.skill_id
    WHERE p.season_id = p_season_id;

    IF v_agg_players IS NULL THEN
        p_player_json := '{
          "players": []
        }'::jsonb;
        p_ret_type := 3; -- Not Found
    ELSE
        p_player_json := JSONB_BUILD_OBJECT('players', v_agg_players);
        p_ret_type := 1; -- Success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_player_json := NULL;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_player',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_team(p_season_id integer, OUT p_team_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_agg_teams JSONB;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'team_id', t.team_id,
                           'source_id', t.source_id,
                           'season_id', t.season_id,
                           'series_id', t.series_id,
                           'team_name', t.team_name,
                           'team_display_name', t.team_display_name,
                           'team_short_code', t.team_short_code,
                           'sport_properties', t.sport_properties,
                           'created_date', t.created_date,
                           'updated_date', t.updated_date
                   )
           )
    INTO v_agg_teams
    FROM game_management.team t
    WHERE t.season_id = p_season_id;

    IF v_agg_teams IS NULL THEN
        p_team_json := '{
          "teams": []
        }'::jsonb;
        p_ret_type := 3; -- Not Found
    ELSE
        p_team_json := JSONB_BUILD_OBJECT('teams', v_agg_teams);
        p_ret_type := 1; -- Success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_team_json := NULL;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_team',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_venue(p_season_id integer, OUT p_venue_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_agg_venues JSONB;
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'venue_id', v.venue_id,
                           'source_id', v.source_id,
                           'season_id', v.season_id,
                           'location1', v.location1,
                           'location1_display_name', v.location1_display_name,
                           'location2', v.location2,
                           'location2_display_name', v.location2_display_name,
                           'location3', v.location3,
                           'location3_display_name', v.location3_display_name,
                           'sport_properties', v.sport_properties,
                           'created_date', v.created_date,
                           'updated_date', v.updated_date
                   )
           )
    INTO v_agg_venues
    FROM game_management.venue v
    WHERE v.season_id = p_season_id;

    IF v_agg_venues IS NULL THEN
        p_venue_json := '{
          "venues": []
        }'::jsonb;
        p_ret_type := 3; -- Not Found
    ELSE
        p_venue_json := JSONB_BUILD_OBJECT('venues', v_agg_venues);
        p_ret_type := 1; -- Success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_venue_json := NULL;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_venue',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_fixture_v1(p_season_id integer, OUT p_fixture refcursor, OUT p_venue refcursor, OUT p_gameset refcursor, OUT p_gameday refcursor, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    OPEN p_fixture FOR
        SELECT * FROM game_management.fixture WHERE season_id = p_season_id;
    OPEN p_venue FOR
        SELECT * FROM game_management.venue WHERE season_id = p_season_id;
    OPEN p_gameset FOR
        SELECT * FROM game_management.gameset WHERE season_id = p_season_id;
    OPEN p_gameday FOR
        SELECT * FROM game_management.gameday WHERE season_id = p_season_id;

    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_fixture_v1',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_player_v1(p_season_id integer, OUT p_player refcursor, OUT p_team refcursor, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN

    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    OPEN p_player FOR
        SELECT * FROM game_management.player WHERE season_id = p_season_id;
    OPEN p_team FOR
        SELECT * FROM game_management.team WHERE season_id = p_season_id;
    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_player_v1',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_venue_v1(p_season_id integer, OUT p_venue refcursor, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN

    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    OPEN p_venue FOR
        SELECT * FROM game_management.venue WHERE season_id = p_season_id;

    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_venue_v1',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_team_v1(p_season_id integer, OUT p_team refcursor, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN

    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    OPEN p_team FOR
        SELECT * FROM game_management.team WHERE season_id = p_season_id;

    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_team_v1',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.phase_mapping(p_input_json jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 150,
  "phases": [
    {
      "phase_id": 1,           // optional - update if provided
      "phase_name": "Group Stage",
      "start_gameset_id": 1,
      "end_gameset_id": 4
    },
    {
      // no phase_id - will auto-generate next available
      "phase_name": "Knockout",
      "start_gameset_id": 5,
      "end_gameset_id": 6
    }
  ]
}
*/
DECLARE
    v_season_id    SMALLINT := (p_input_json ->> 'season_id')::SMALLINT;
    v_max_phase_id SMALLINT := 0;
BEGIN
    -- Validate season exists
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    -- Get max phase_id for auto-generation
    SELECT COALESCE(MAX(phase_id), 0)
    INTO v_max_phase_id
    FROM game_management.phase
    WHERE season_id = v_season_id;

    -- Process all operations in a single optimized CTE chain
    WITH
        -- Step 1: Parse input and assign phase IDs
        phase_data AS (SELECT COALESCE((p.value ->> 'phase_id')::SMALLINT, v_max_phase_id + p.ordinality) AS phase_id,
                              p.value ->> 'phase_name'                                                    AS phase_name,
                              (p.value ->> 'start_gameset_id')::SMALLINT                                  AS start_gameset_id,
                              (p.value ->> 'end_gameset_id')::SMALLINT                                    AS end_gameset_id
                       FROM JSONB_ARRAY_ELEMENTS(p_input_json -> 'phases') WITH ORDINALITY p),
        -- Step 2: Upsert phases
        upsert_phases AS (
            INSERT INTO game_management.phase (phase_id, season_id, phase_name)
                SELECT phase_id, v_season_id, phase_name
                FROM phase_data
                ON CONFLICT (phase_id, season_id) DO UPDATE SET
                    phase_name = EXCLUDED.phase_name
                RETURNING 1),
        -- Step 3: Delete phases not in input
        cleanup_phases AS (
            DELETE FROM game_management.phase
                WHERE season_id = v_season_id
                    AND phase_id NOT IN (SELECT phase_id FROM phase_data)
                RETURNING 1),
        -- Step 4: Update gamesets - set phase_id if in range, otherwise NULL
        update_gamesets AS (
            UPDATE game_management.gameset gs
                SET phase_id = pd.phase_id
                FROM (SELECT DISTINCT gameset_id FROM game_management.gameset WHERE season_id = v_season_id) all_gs
                    LEFT JOIN phase_data pd ON all_gs.gameset_id BETWEEN pd.start_gameset_id AND pd.end_gameset_id
                WHERE gs.season_id = v_season_id
                    AND gs.gameset_id = all_gs.gameset_id
                    AND gs.phase_id IS DISTINCT FROM pd.phase_id
                RETURNING 1)
    -- Step 5: Update fixtures - set phase_id based on gameset, or NULL if gameset has no phase
    UPDATE game_management.fixture f
    SET phase_id     = gs.phase_id,
        updated_date = CURRENT_TIMESTAMP
    FROM game_management.gameset gs
    WHERE f.season_id = v_season_id
      AND f.gameset_id = gs.gameset_id
      AND gs.season_id = v_season_id
      AND f.phase_id IS DISTINCT FROM gs.phase_id;

    p_ret_type := 1; -- Success

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.phase_mapping',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input_json
                );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_gameset_fixture(p_season_id integer, OUT p_gameset_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31;
        RETURN;
    END IF;

    WITH season_fixtures AS (SELECT gameset_id,
                                    gameday_id,
                                    JSONB_AGG(fixture_id ORDER BY fixture_datetime_iso8601) AS fixtures
                             FROM game_management.fixture
                             WHERE season_id = p_season_id
                               AND gameset_id IS NOT NULL
                               AND gameday_id IS NOT NULL
                             GROUP BY gameset_id, gameday_id),
         season_gamedays AS (SELECT gd.gameset_id,
                                    JSONB_AGG(
                                            JSONB_BUILD_OBJECT(
                                                    'gameday_id', gd.gameday_id,
                                                    'gameday_name', gd.gameday_name,
                                                    'substitution_lock_offset', gd.substitution_lock_offset,
                                                    'substitution_unlock_offset', gd.substitution_unlock_offset,
                                                    'fixtures', COALESCE(sf.fixtures, '[]'::jsonb)
                                            ) ORDER BY gd.gameday_id
                                    ) AS gamedays
                             FROM game_management.gameday gd
                                      LEFT JOIN season_fixtures sf
                                                ON gd.season_id = p_season_id
                                                    AND gd.gameset_id = sf.gameset_id
                                                    AND gd.gameday_id = sf.gameday_id
                             WHERE gd.season_id = p_season_id
                             GROUP BY gd.gameset_id),
         season_gamesets AS (SELECT JSONB_AGG(
                                            JSONB_BUILD_OBJECT(
                                                    'gameset_id', gs.gameset_id,
                                                    'transfer_lock_offset', gs.transfer_lock_offset,
                                                    'transfer_unlock_offset', gs.transfer_unlock_offset,
                                                    'gameset_name', gs.gameset_name,
                                                    'gamedays', COALESCE(sgd.gamedays, '[]'::jsonb)
                                            ) ORDER BY gs.gameset_id
                                    ) AS gamesets
                             FROM game_management.gameset gs
                                      LEFT JOIN season_gamedays sgd
                                                ON gs.season_id = p_season_id
                                                    AND gs.gameset_id = sgd.gameset_id
                             WHERE gs.season_id = p_season_id
                             GROUP BY gs.season_id)
    SELECT JSONB_BUILD_OBJECT(
                   'offset_type_id', sc.gameset_offset_type,
                   'offset_type', ot.offset_type,
                   'gamesets', COALESCE(sgs.gamesets, '[]'::jsonb)
           )
    INTO p_gameset_json
    FROM engine_config.season_config sc
             LEFT JOIN season_gamesets sgs
                       ON sc.season_id = p_season_id
             JOIN engine_config.offset_type ot
                  ON sc.gameset_offset_type = ot.offset_type_id
    WHERE sc.season_id = p_season_id;

    IF p_gameset_json IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_gameset_fixture',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION game_management.get_phase(p_season_id integer, OUT p_phase_json jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_phases jsonb;
BEGIN

    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'phase_id', phase_id,
                           'phase_name', phase_name,
                           'start_gameset_id', start_gameset_id,
                           'end_gameset_id', end_gameset_id
                   ) ORDER BY phase_id
           ) AS phases
    INTO v_phases
    FROM (SELECT p.phase_id,
                 p.phase_name,
                 MIN(gs.gameset_id) AS start_gameset_id,
                 MAX(gs.gameset_id) AS end_gameset_id
          FROM game_management.phase p
                   LEFT JOIN game_management.gameset gs
                             ON p.phase_id = gs.phase_id
                                 AND p.season_id = gs.season_id
          WHERE p.season_id = p_season_id
          GROUP BY p.phase_id, p.phase_name) AS phase;

    IF v_phases IS NULL THEN
        p_ret_type := 3;
        p_phase_json := '{
          "phases": []
        }'::jsonb;
    ELSE
        p_ret_type := 1;
        p_phase_json := JSONB_BUILD_OBJECT(
                'phases', v_phases
                        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'game_management.get_phase',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
                );
END;
$$; 