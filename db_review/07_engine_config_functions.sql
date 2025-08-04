CREATE OR REPLACE FUNCTION engine_config.create_new_season(p_application_id INTEGER, p_season_name CHARACTER VARYING, OUT p_season_data jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_season_id     SMALLINT;
    v_language_code VARCHAR := 'en';
    v_language_name VARCHAR := 'English';
    v_ret_type      INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1
                   FROM engine_config.application
                   WHERE application_id = p_application_id) THEN
        v_ret_type := 3;
        p_season_data := NULL;
        RAISE EXCEPTION 'Application ID % does not exist', p_application_id;
    END IF;

    INSERT INTO engine_config.season
    (application_id,
     season_name)
    SELECT p_application_id,
           p_season_name
    RETURNING season_id
        INTO v_season_id;

    INSERT INTO engine_config.season_config
        (season_id)
    SELECT v_season_id;

    INSERT INTO engine_config.language
        (season_id, language_code, language_name)
    SELECT v_season_id,
           v_language_code,
           v_language_name;

    SELECT JSONB_BUILD_OBJECT('season_id', S.season_id,
                              'season_name', S.season_name,
                              'status_id', S.status_id,
                              'status', SS.status,
                              'created_at', S.created_date,
                              'updated_at', S.updated_date)
    INTO p_season_data
    FROM engine_config.season S
             JOIN engine_config.season_status SS USING (status_id)
    WHERE season_id = v_season_id;

    p_ret_type := 1;
EXCEPTION
    WHEN UNIQUE_VIOLATION THEN
        p_ret_type := 4;
        p_season_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.create_new_season',
                p_error_message := 'Season name already exists: "' || p_season_name || '" for application ID ' || p_application_id,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('application_id', p_application_id, 'season_name', p_season_name)
             );
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        p_season_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.create_new_season',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('application_id', p_application_id, 'season_name', p_season_name)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.delete_chip_config(p_season_id INTEGER, p_chip_id INTEGER, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_row_count INTEGER;
BEGIN
    DELETE
    FROM engine_config.application_chip_configuration
    WHERE season_id = p_season_id
      AND chip_id = p_chip_id;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.delete_chip_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id, 'chip_id', p_chip_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.delete_season(p_season_id INTEGER, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_row_count INTEGER;
BEGIN
    DELETE
    FROM engine_config.season
    WHERE season_id = p_season_id
      AND status_id <> 2;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3;
        RETURN;
    END IF;
    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.delete_season',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.delete_skill_constraint(p_season_id INTEGER, p_skill_id INTEGER, p_constraint_type_id INTEGER, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_constraint_id INTEGER[];
    v_ret_type      INTEGER;
BEGIN
    SELECT ARRAY_AGG(constraint_id)
    INTO v_constraint_id
    FROM engine_config.team_constraint
    WHERE constraint_type_id = p_constraint_type_id;

    IF v_constraint_id IS NULL THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No constraint found for the given constraint_type_id: %', p_constraint_type_id;
    END IF;

    DELETE
    FROM engine_config.application_user_team_skill_configuration
    WHERE season_id = p_season_id
      AND skill_id = p_skill_id
      AND constraint_id = ANY (v_constraint_id);

    IF NOT FOUND THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No constraint found for the given season_id: % and skill_id: %', p_season_id, p_skill_id;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.delete_skill_constraint',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id,
                                                   'skill_id', p_skill_id,
                                                   'constraint_type_id', p_constraint_type_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.delete_team_constraint(p_season_id INTEGER, p_constraint_type_id INTEGER, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_constraint_id INTEGER[];
    v_ret_type      INTEGER;
BEGIN
    SELECT ARRAY_AGG(constraint_id)
    INTO v_constraint_id
    FROM engine_config.team_constraint
    WHERE constraint_type_id = p_constraint_type_id;

    IF v_constraint_id IS NULL THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No constraint found for the given constraint_type_id: %', p_constraint_type_id;
    END IF;

    DELETE
    FROM engine_config.application_user_team_constraint_configuration
    WHERE season_id = p_season_id
      AND constraint_id = ANY (v_constraint_id);

    IF NOT FOUND THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No constraint found for the given season_id: %', p_season_id;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.delete_team_constraint',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id,
                                                   'constraint_type_id', p_constraint_type_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.delete_transfer_manager_config(p_season_id INTEGER, p_start_gameset_id INTEGER, p_end_gameset_id INTEGER, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_row_count INTEGER;
BEGIN
    DELETE
    FROM engine_config.application_user_team_transfer_configuration
    WHERE season_id = p_season_id
      AND from_gameset_id = p_start_gameset_id
      AND to_gameset_id = p_end_gameset_id;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.delete_transfer_manager_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id,
                                                   'start_gameset_id', p_start_gameset_id,
                                                   'end_gameset_id', p_end_gameset_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.enable_season_for_operator(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
[
  {
    "season_id": 1,
    "is_enabled": true
  },
  {
    "season_id": 2,
    "is_enabled": true
  }
]
*/
DECLARE
    v_row_count INTEGER;
BEGIN
    UPDATE engine_config.season s
    SET is_enabled_for_operator = (elem_data ->> 'is_enabled')::BOOLEAN
    FROM JSONB_ARRAY_ELEMENTS(p_input) AS elem_data
    WHERE s.season_id = (elem_data ->> 'season_id')::SMALLINT
      AND s.status_id = 1; -- NOT_STARTED

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.enable_season_for_operator',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_application_preset(p_sport_id NUMERIC, p_variant_id NUMERIC, OUT p_ret_type NUMERIC, OUT p_preset_data jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT ('{ "preset" :' || JSON_AGG(b) || '}')::jsonb
    INTO p_preset_data
    FROM (SELECT preset_id, preset_name
          FROM engine_config.preset
          WHERE sport_id = p_sport_id
            AND variant_id = p_variant_id) b;

    IF p_preset_data IS NOT NULL THEN
        p_ret_type := 1 ;
    ELSE
        p_ret_type := 3;
    END IF;
END ;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_chip_config(p_season_id INTEGER, OUT p_chip_config jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    WITH chip_details AS (SELECT chip_id,
                                 chip_name,
                                 JSONB_AGG(
                                         JSONB_BUILD_OBJECT(
                                                 'start_gameset_id', start_gameset_id,
                                                 'end_gameset_id', end_gameset_id,
                                                 'no_of_chip', no_of_chip,
                                                 'expire_if_not_used', expire_if_not_used,
                                                 'is_for_individual_gameset', is_for_individual_gameset
                                         )
                                 ) AS chip_details
                          FROM engine_config.application_chip_configuration
                          WHERE season_id = p_season_id
                          GROUP BY chip_id, chip_name)
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'chip_id', chip_id,
                           'chip_name', chip_name,
                           'chip_details', chip_details
                   )
           )
    INTO p_chip_config
    FROM chip_details;

    IF p_chip_config IS NULL THEN
        p_chip_config := '[]'::jsonb;
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_chip_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_chip_types(OUT p_chip_types jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'chip_id', chip_id,
                           'chip_name', chip_name
                   )
           )
    INTO p_chip_types
    FROM engine_config.chip_type;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_chip_types := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_chip_types',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := NULL
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_constraint_manager(p_season_id INTEGER, OUT p_constraint_manager_data jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_team_constraints   jsonb;
    v_skill_constraints  jsonb;
    v_is_team_constraint BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS(SELECT 1
                  FROM engine_config.application_user_team_constraint_configuration
                  WHERE season_id = p_season_id)
    INTO v_is_team_constraint;

    SELECT COALESCE(
                   JSONB_AGG(
                           JSONB_BUILD_OBJECT(
                                   'constraint_type_id', tc.constraint_type_id,
                                   'constraint_name', config.constraint_name,
                                   'constraint_config', config.constraint_config
                           )
                   ), '[]'::jsonb)
    INTO v_team_constraints
    FROM engine_config.application_user_team_constraint_configuration config
             JOIN engine_config.team_constraint tc
                  ON config.constraint_id = tc.constraint_id
    WHERE config.season_id = p_season_id;

    SELECT COALESCE(
                   JSONB_AGG(
                           JSONB_BUILD_OBJECT(
                                   'skill_id', sk.skill_id,
                                   'constraints', sk.constraints
                           )
                   ), '[]'::jsonb
           )
    INTO v_skill_constraints
    FROM (SELECT config.skill_id,
                 JSONB_AGG(
                         JSONB_BUILD_OBJECT(
                                 'constraint_type_id', tc.constraint_type_id,
                                 'constraint_name', config.constraint_name,
                                 'constraint_config', config.constraint_config
                         )
                 ) AS constraints
          FROM engine_config.application_user_team_skill_configuration config
                   JOIN engine_config.team_constraint tc
                        ON config.constraint_id = tc.constraint_id
          WHERE config.season_id = p_season_id
            AND config.constraint_id <> -1
          GROUP BY config.skill_id) sk;

    p_constraint_manager_data := JSONB_BUILD_OBJECT(
            'is_team_constraint', v_is_team_constraint,
            'team_constraint', v_team_constraints,
            'skill_constraint', v_skill_constraints
                                 );

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_constraint_manager',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_constraint_types(OUT p_constraint_types jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'constraint_type_id', constraint_type_id,
                           'constraint_type', constraint_type,
                           'subtypes', subtypes
                   ) ORDER BY constraint_type_id
           )
    INTO p_constraint_types
    FROM (SELECT constraint_type_id,
                 constraint_type,
                 JSONB_AGG(
                 JSONB_BUILD_OBJECT(
                         'constraint_subtype_id', constraint_subtype_id,
                         'constraint_subtype', constraint_subtype
                 ) ORDER BY constraint_subtype_id
                          ) FILTER (WHERE constraint_subtype_id IS NOT NULL) AS subtypes
          FROM engine_config.team_constraint
          WHERE constraint_id != -1
          GROUP BY constraint_type_id, constraint_type) AS constraint_groups;

    IF p_constraint_types IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_constraint_types',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := NULL
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_draft_json(p_season_id INTEGER, OUT p_draft_json jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$

BEGIN
    SELECT draft_json
    INTO p_draft_json
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_draft_json IS NULL THEN
        p_ret_type := 3;
        p_draft_json := NULL;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_draft_json',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_dropdown_details(p_sport_id NUMERIC, OUT p_constraints_data jsonb) RETURNS jsonb
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_team_constraints  jsonb;
    v_skill_constraints jsonb;
BEGIN
    SELECT JSONB_AGG(b)
    INTO v_team_constraints
    FROM (SELECT constraint_id,
                 constraint_type AS constraint_name
          FROM engine_config.team_constraint) b;

    SELECT JSONB_AGG(b)
    INTO v_skill_constraints
    FROM (SELECT skill_id, skill_name
          FROM engine_config.sport_skill
          WHERE sport_id = p_sport_id) b;

    p_constraints_data := JSONB_BUILD_OBJECT(
            'team_constraints', COALESCE(v_team_constraints, '[]'::jsonb),
            'skill_constraints', COALESCE(v_skill_constraints, '[]'::jsonb)
                          );
EXCEPTION
    WHEN OTHERS THEN
        p_constraints_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_dropdown_details',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('sport_id', p_sport_id)
             );
END ;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_feed_config(p_season_id INTEGER, OUT p_feed_config jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT feed
    INTO p_feed_config
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_feed_config IS NULL THEN
        p_ret_type := 3;
        p_feed_config := '[]'::jsonb;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_feed_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_languages(p_season_id INTEGER, OUT p_ret_type INTEGER, OUT p_languages_data jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'language_code', language_code,
                           'language_name', language_name
                   )
           )
    INTO p_languages_data
    FROM engine_config.language
    WHERE season_id = p_season_id
      AND is_deleted = FALSE;

    IF p_languages_data IS NULL THEN
        p_languages_data := '[]'::jsonb;
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_languages',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_localization_config(p_season_id INTEGER, OUT p_ret_type INTEGER, OUT p_localization_data jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT localization
    INTO p_localization_data
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_localization_data IS NULL THEN
        p_localization_data := '[]'::jsonb;
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_localization_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_maintenance_mode_config(p_season_id INTEGER, OUT p_maintenance_config jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    WITH device_ids AS (SELECT JSONB_AGG(device_id) AS ids
                        FROM engine_config.application_maintenance
                        WHERE season_id = p_season_id)
    SELECT JSONB_BUILD_OBJECT(
                   'maintenance_code', am.maintenance_code,
                   'maintenance_message', am.maintenance_message,
                   'device_ids', COALESCE(p.ids, '[]'::jsonb)
           )
    INTO p_maintenance_config
    FROM engine_config.application_maintenance am
             CROSS JOIN device_ids p
    WHERE am.season_id = p_season_id
    LIMIT 1;

    IF p_maintenance_config IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_maintenance_mode_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_maintenance_modes(p_season_id INTEGER, OUT p_maintenance_messages jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_localization_json jsonb;
BEGIN
    SELECT localization
    INTO v_localization_json
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'message_code', entry ->> 'language_key',
                           'maintenance_message', entry ->> 'value'
                   )
           )
    INTO p_maintenance_messages
    FROM JSONB_PATH_QUERY(
                 v_localization_json,
                 '$[*] ? (@.language_code == "en").translations[*] ? (@.language_key like_regex "^maintenance")'
         ) AS entry;

    IF p_maintenance_messages IS NULL THEN
        p_maintenance_messages := '[]'::jsonb;
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_maintenance_modes',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_devices(OUT p_devices jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'device_id', device_id,
                           'device_name', device_name
                   )
           )
    INTO p_devices
    FROM engine_config.device;

    IF p_devices IS NULL THEN
        p_devices := '[]'::jsonb;
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_devices',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := NULL
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_player_valuation_config(p_season_id INTEGER, OUT p_ret_type INTEGER, OUT p_player_valuation_config jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT player_valuation
    INTO p_player_valuation_config
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_player_valuation_config IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_player_valuation_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_season_list(p_application_id INTEGER, OUT p_ret_type INTEGER, OUT p_season_list jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT JSONB_AGG(row)
    INTO p_season_list
    FROM (SELECT S.season_id,
                 S.season_name,
                 S.status_id,
                 SS.status,
                 s.device_id,
                 S.is_enabled_for_operator,
                 S.created_date,
                 S.updated_date
          FROM engine_config.season S
                   JOIN engine_config.season_status SS USING (status_id)
          WHERE application_id = p_application_id) row;

    IF p_season_list IS NULL THEN
        p_ret_type := 3;
        p_season_list := '[]'::jsonb;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_season_list',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('application_id', p_application_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_transfer_manager(p_season_id INTEGER, OUT p_transfer_manager_data jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_budget_config   JSONB;
    v_transfer_config JSONB;
BEGIN
    SELECT JSONB_BUILD_OBJECT(
                   'is_additional_budget', BOOL_OR(is_additional_budget_allowed) FILTER (WHERE additional_budget_allowed_from_round = -1),
                   'additional_budget_details',
                   COALESCE(JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                                    'additional_budget', additional_budget_value,
                                    'from_gameset_id', additional_budget_allowed_from_round
                            )
                                     ) FILTER (WHERE additional_budget_allowed_from_round <> -1), '[]'::jsonb)
           )
    INTO v_budget_config
    FROM engine_config.application_budget_configuration
    WHERE season_id = p_season_id;

    SELECT JSONB_BUILD_OBJECT(
                   'is_net_transfers_allowed', BOOL_OR(is_net_transfers_allowed) FILTER (WHERE from_gameset_id = -1),
                   'additional_transfer_details',
                   COALESCE(JSONB_AGG(
                            JSONB_BUILD_OBJECT(
                                    'is_for_individual_gameset', is_for_individual_gameset,
                                    'start_gameset_id', from_gameset_id,
                                    'end_gameset_id', to_gameset_id,
                                    'no_of_transfers', total_transfer_allowed,
                                    'transfers_carried_over', all_unused_transfers_carry_over,
                                    'additional_transfers', total_additional_transfer_allowed,
                                    'additional_transfers_points', additional_transfer_negative_points
                            )
                                     ) FILTER (WHERE from_gameset_id <> -1), '[]'::jsonb)
           )
    INTO v_transfer_config
    FROM engine_config.application_user_team_transfer_configuration
    WHERE season_id = p_season_id;

    p_transfer_manager_data := JSONB_BUILD_OBJECT(
            'budget_config', v_budget_config,
            'transfer_config', v_transfer_config
                               );

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_transfer_manager_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_transfer_manager',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;


CREATE OR REPLACE FUNCTION engine_config.ins_db_details(p_input jsonb, OUT p_ret_type INTEGER, OUT p_application_id INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
/*
{
  "db_config": {
    "db_details": [
      {
        "name": "fantasy_agent",
        "port": 5432,
        "db_name": "siegedb2",
        "password": "Z3r0Ch!t3n40ppa",
        "end_point": "sigamingint.clmquhxxma0y.us-east-1.rds.amazonaws.com",
        "shard_name": "league"
      },
      {
        "name": "fantasy_agent",
        "port": 5432,
        "db_name": "siegedb3",
        "password": "Z3r0Ch!t3n40ppa",
        "end_point": "sigamingint.clmquhxxma0y.us-east-1.rds.amazonaws.com",
        "shard_name": "pointcalculation"
      },
      {
        "name": "fantasy_agent",
        "port": 5432,
        "db_name": "siegedb1",
        "password": "Z3r0Ch!t3n40ppa",
        "end_point": "sigamingint.clmquhxxma0y.us-east-1.rds.amazonaws.com",
        "shard_name": "user"
      }
    ]
  },
  "user_details": {
    "password": "luffy_009",
    "user_name": "luffy_009",
    "client_name": "luffy_009",
    "role_id": 1
  },
  "sport_and_variant": {
    "sport_id": "2",
    "variant_id": "1"
  }
}
*/
DECLARE
    v_user_id NUMERIC;
BEGIN
    IF NOT EXISTS(SELECT 1
                  FROM engine_config.admin_user
                  WHERE user_name = p_input -> 'user_details' ->> 'user_name')
    THEN
        v_user_id := NEXTVAL('engine_config.user_id_seq');

        INSERT INTO engine_config.admin_user
        (user_id,
         user_name,
         display_user_name,
         user_password,
         is_super_admin,
         created_date)
        SELECT v_user_id,
               p_input -> 'user_details' ->> 'user_name',
               p_input -> 'user_details' ->> 'user_name',
               p_input -> 'user_details' ->> 'password',
               TRUE,
               CURRENT_TIMESTAMP;

        INSERT INTO engine_config.application
        (application_id,
         application_name,
         admin_id,
         sport_id,
         variant_id,
         logo_url,
         config_json)
        SELECT NEXTVAL('engine_config.application_id_seq'),
               p_input -> 'user_details' ->> 'client_name',
               v_user_id,
               (p_input -> 'sport_and_variant' ->> 'sport_id')::SMALLINT,
               (p_input -> 'sport_and_variant' ->> 'variant_id')::SMALLINT,
               NULL,
               p_input
        RETURNING application_id
            INTO p_application_id;

        INSERT INTO engine_config.application_database
        (database_id,
         database_type,
         shard_id,
         connection_details,
         application_id)
        SELECT NEXTVAL('engine_config.database_id_seq'),
               SUBSTRING(shard_name, 1, 1),
               1,
               'host=' || end_point || ' port=' || port || ' user=' || name || ' password=' || password || ' dbname=' || "db_name",
               p_application_id
        FROM JSONB_TO_RECORDSET(p_input -> 'db_config' -> 'db_details')
                 AS x("name" TEXT, "port" TEXT, "end_point" TEXT, "db_name" TEXT, "password" TEXT,
                      "shard_name" TEXT);

        p_ret_type := 1;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_application_id = NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_db_details',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_draft_json(p_season_id INTEGER, p_draft_json jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$

BEGIN
    UPDATE engine_config.season_config
    SET draft_json = p_draft_json
    WHERE season_id = p_season_id;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_draft_json',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id, 'draft_json', p_draft_json)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_chip_config(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "chip_config": [
    {
      "chip_id": 1,
      "chip_name": "DRS",
      "chip_details": [
        {
          "is_for_individual_gameset": true,
          "start_gameset_id": 1,
          "end_gameset_id": 3,
          "no_of_chip": 2,
          "expire_if_not_used": true
        }
      ]
    }
  ]
}
*/
DECLARE
    v_season_id SMALLINT;
    v_ret_type  INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    WITH chip_data AS (SELECT (chip_config ->> 'chip_id')::SMALLINT                  AS chip_id,
                              v_season_id                                            AS season_id,
                              chip_config ->> 'chip_name'                            AS chip_name,
                              (chip_detail ->> 'start_gameset_id')::SMALLINT         AS start_gameset_id,
                              (chip_detail ->> 'end_gameset_id')::SMALLINT           AS end_gameset_id,
                              (chip_detail ->> 'no_of_chip')::SMALLINT               AS no_of_chip,
                              (chip_detail ->> 'expire_if_not_used')::BOOLEAN        AS expire_if_not_used,
                              (chip_detail ->> 'is_for_individual_gameset')::BOOLEAN AS is_for_individual_gameset
                       FROM JSONB_ARRAY_ELEMENTS(p_input -> 'chip_config') AS chip_config,
                            JSONB_ARRAY_ELEMENTS(chip_config -> 'chip_details') AS chip_detail),
         delete_old AS (
             DELETE FROM engine_config.application_chip_configuration acc
                 WHERE acc.season_id = v_season_id
                     AND NOT EXISTS (SELECT 1
                                     FROM chip_data cd
                                     WHERE acc.chip_id = cd.chip_id
                                       AND acc.start_gameset_id = cd.start_gameset_id
                                       AND acc.end_gameset_id = cd.end_gameset_id))
    INSERT
    INTO engine_config.application_chip_configuration
    (chip_id,
     season_id,
     chip_name,
     start_gameset_id,
     end_gameset_id,
     no_of_chip,
     expire_if_not_used,
     is_for_individual_gameset)
    SELECT chip_id,
           season_id,
           chip_name,
           start_gameset_id,
           end_gameset_id,
           no_of_chip,
           expire_if_not_used,
           is_for_individual_gameset
    FROM chip_data
    ON CONFLICT (chip_id, season_id, start_gameset_id, end_gameset_id)
        DO UPDATE SET chip_name                 = EXCLUDED.chip_name,
                      no_of_chip                = EXCLUDED.no_of_chip,
                      expire_if_not_used        = EXCLUDED.expire_if_not_used,
                      is_for_individual_gameset = EXCLUDED.is_for_individual_gameset;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_chip_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_constraint_manager(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "is_team_constraint": true,
  "team_constraint": [
    {
      "constraint_type_id": 1,
      "constraint_name": "constraint 1",
      "constraint_config": [
        {
          "min_value": null,
          "max_value": null,
          "equal_value": null,
          "constraint_subtype_id": 1,
          "is_for_individual_gameset": false,
          "start_gameset": 1,
          "end_gameset": 3
        },
        {
          "min_value": null,
          "max_value": null,
          "equal_value": 0,
          "constraint_subtype_id": 1,
          "is_for_individual_gameset": false,
          "start_gameset": 5,
          "end_gameset": 8
        }
      ]
    },
    {
      "constraint_type_id": 2,
      "constraint_name": "constraint 2",
      "constraint_config": [
        {
          "min_value": null,
          "max_value": 0,
          "equal_value": null,
          "constraint_subtype_id": null,
          "is_for_individual_gameset": false,
          "start_gameset": 1,
          "end_gameset": 4
        }
      ]
    }
  ],
  "skill_constraint": [
    {
      "skill_id": 5,
      "constraints": [
        {
          "constraint_type_id": 1,
          "constraint_name": "constraint 1",
          "constraint_config": [
            {
              "min_value": null,
              "max_value": null,
              "equal_value": 0,
              "constraint_subtype_id": 1,
              "is_for_individual_gameset": false,
              "start_gameset": 1,
              "end_gameset": 3
            }
          ]
        },
        {
          "constraint_type_id": 2,
          "constraint_name": "constraint 2",
          "constraint_config": [
            {
              "min_value": null,
              "max_value": 0,
              "equal_value": null,
              "constraint_subtype_id": null,
              "is_for_individual_gameset": false,
              "start_gameset": 1,
              "end_gameset": 4
            }
          ]
        }
      ]
    }
  ]
}
*/
DECLARE
    v_team_constraints   jsonb;
    v_skill_constraints  jsonb;
    v_is_team_constraint BOOLEAN;
    v_ret_type           INTEGER;
    v_season_id          SMALLINT;
BEGIN
    v_team_constraints := p_input -> 'team_constraint';
    v_skill_constraints := p_input -> 'skill_constraint';
    v_is_team_constraint := (p_input ->> 'is_team_constraint')::BOOLEAN;
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    IF v_is_team_constraint IS TRUE
    THEN

        WITH team_constraint_data AS (SELECT (t ->> 'constraint_type_id')::INTEGER          AS constraint_type_id,
                                             t ->> 'constraint_name'                        AS constraint_name,
                                             JSONB_ARRAY_ELEMENTS(t -> 'constraint_config') AS config
                                      FROM JSONB_ARRAY_ELEMENTS(v_team_constraints) t),
             resolved_constraints AS (SELECT tc.constraint_id,
                                             td.constraint_name,
                                             JSONB_AGG(td.config) AS config
                                      FROM team_constraint_data td
                                               JOIN engine_config.team_constraint tc
                                                    ON td.constraint_type_id = tc.constraint_type_id
                                                        AND (td.config ->> 'constraint_subtype_id')::INTEGER IS NOT DISTINCT FROM tc.constraint_subtype_id
                                      GROUP BY tc.constraint_id, td.constraint_name)
        INSERT
        INTO engine_config.application_user_team_constraint_configuration
        (season_id,
         constraint_id,
         constraint_name,
         constraint_config)
        SELECT v_season_id,
               constraint_id,
               constraint_name,
               config
        FROM resolved_constraints
        ON CONFLICT (season_id, constraint_id)
            DO UPDATE SET constraint_name   = EXCLUDED.constraint_name,
                          constraint_config = EXCLUDED.constraint_config;

    ELSE

        DELETE
        FROM engine_config.application_user_team_constraint_configuration
        WHERE season_id = v_season_id;

    END IF;

    WITH skill_data AS (SELECT (skill ->> 'skill_id')::SMALLINT             AS skill_id,
                               JSONB_ARRAY_ELEMENTS(skill -> 'constraints') AS "constraint"
                        FROM JSONB_ARRAY_ELEMENTS(v_skill_constraints) skill),
         flattened_constraints AS (SELECT sd.skill_id,
                                          (sd.constraint ->> 'constraint_type_id')::INTEGER          AS constraint_type_id,
                                          sd.constraint ->> 'constraint_name'                        AS constraint_name,
                                          JSONB_ARRAY_ELEMENTS(sd.constraint -> 'constraint_config') AS config
                                   FROM skill_data sd),
         existing_config AS (SELECT season_id,
                                    skill_id,
                                    min_entities_per_team,
                                    max_entities_per_team
                             FROM engine_config.application_user_team_skill_configuration
                             WHERE season_id = v_season_id
                               AND constraint_id <> -1),
         resolved_skill_constraints AS (SELECT fc.skill_id,
                                               tc.constraint_id,
                                               fc.constraint_name,
                                               JSONB_AGG(fc.config)                  AS config,
                                               COALESCE(ec.min_entities_per_team, 0) AS min_entities_per_team,
                                               COALESCE(ec.max_entities_per_team, 1) AS max_entities_per_team
                                        FROM flattened_constraints fc
                                                 JOIN engine_config.team_constraint tc
                                                      ON fc.constraint_type_id = tc.constraint_type_id
                                                          AND (fc.config ->> 'constraint_subtype_id')::INTEGER IS NOT DISTINCT FROM tc.constraint_subtype_id
                                                 LEFT JOIN existing_config ec
                                                           ON ec.skill_id = fc.skill_id
                                        GROUP BY fc.skill_id, tc.constraint_id, fc.constraint_name, ec.min_entities_per_team, ec.max_entities_per_team)
    INSERT
    INTO engine_config.application_user_team_skill_configuration
    (season_id,
     skill_id,
     min_entities_per_team,
     max_entities_per_team,
     constraint_id,
     constraint_name,
     constraint_config)
    SELECT v_season_id,
           skill_id,
           min_entities_per_team,
           max_entities_per_team,
           constraint_id,
           constraint_name,
           config
    FROM resolved_skill_constraints
    ON CONFLICT (season_id, skill_id, constraint_id)
        DO UPDATE SET constraint_name   = EXCLUDED.constraint_name,
                      constraint_config = EXCLUDED.constraint_config;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_constraint_manager',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_feed_config(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "feed_config": {
    "feedConfigurationProvider": "Feed",
    "baseDomain": "www.example.com",
    "fixtures": [
      {
        "path": "Enter Path",
        "header": {
          "name": "Enter Header",
          "value": "Enter Value"
        }
      }
    ],
    "players": [
      {
        "path": "Enter Path",
        "header": {
          "name": "Enter Header",
          "value": "Enter Value"
        }
      }
    ]
  }
}
*/
DECLARE
    v_season_id INTEGER;
    v_row_count INTEGER;
    v_ret_type  INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::INTEGER;

    INSERT INTO engine_config.season_config
    (season_id,
     feed)
    SELECT v_season_id,
           p_input -> 'feed_config'
    ON CONFLICT (season_id) DO UPDATE
        SET feed = p_input -> 'feed_config';

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count = 0 THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No record found for season_id %', v_season_id;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_feed_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_game_config(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 35,
  "budget_and_team_config": {
    "vice_captain": false,
    "captain": true,
    "transfers_carried_over_if_not_used": true,
    "team_unfreezes_after": null,
    "additional_transfer_allowed": true,
    "transfer_allowed": true,
    "skill_constraints": [
      {
        "max": 5,
        "min": 2,
        "skill_id": 7
      },
      {
        "max": 5,
        "min": 2,
        "skill_id": 6
      }
    ],
    "sub_allowed": true,
    "max_picks_per_team_on_bench": 5,
    "min_picks_per_team_on_bench": 5,
    "auto_sub": false,
    "max_picks_per_team_on_pitch": 5,
    "min_picks_per_team_on_pitch": 5,
    "max_team_per_user": 1,
    "min_team_per_user": 1,
    "numbering_system": 1,
    "is_additional_budget": false,
    "budget": true,
    "currency_multiplayer": 1000000,
    "currency_type": "£",
    "budget_cap": 100,
    "additional_budget": 0,
    "enabledConstraints": null,
    "constraints": null
  }
}
*/
DECLARE
    v_season_id          SMALLINT;
    v_budget_team_config JSONB;
    v_ret_type           INTEGER;
BEGIN
    v_budget_team_config := p_input -> 'budget_and_team_config';
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    INSERT INTO engine_config.application_budget_configuration
    (season_id,
     budget_value,
     currency_symbol,
     is_additional_budget_allowed,
     additional_budget_allowed_from_round)
    SELECT v_season_id,
           (v_budget_team_config ->> 'budget_cap')::NUMERIC,
           (v_budget_team_config ->> 'currency_type'),
           (v_budget_team_config ->> 'is_additional_budget')::BOOLEAN,
           -1
    ON CONFLICT (season_id,additional_budget_allowed_from_round) DO UPDATE
        SET budget_value                 = EXCLUDED.budget_value,
            currency_symbol              = EXCLUDED.currency_symbol,
            is_additional_budget_allowed = EXCLUDED.is_additional_budget_allowed;

    INSERT INTO engine_config.application_user_team_transfer_configuration
    (season_id,
     is_transfer_allowed,
     is_unlimited_transfer_allowed,
     total_transfer_allowed,
     is_additional_transfer_allowed,
     from_gameset_id,
     to_gameset_id)
    SELECT v_season_id,
           (v_budget_team_config ->> 'transfer_allowed')::BOOLEAN,
           FALSE,
           100,
           (v_budget_team_config ->> 'additional_transfer_allowed')::BOOLEAN,
           -1,
           -1
    ON CONFLICT (season_id,from_gameset_id,to_gameset_id) DO UPDATE
        SET is_transfer_allowed            = EXCLUDED.is_transfer_allowed,
            is_unlimited_transfer_allowed  = EXCLUDED.is_unlimited_transfer_allowed,
            total_transfer_allowed         = EXCLUDED.total_transfer_allowed,
            is_additional_transfer_allowed = EXCLUDED.is_additional_transfer_allowed;

    INSERT INTO engine_config.application_user_team_skill_configuration
    (season_id,
     skill_id,
     min_entities_per_team,
     max_entities_per_team,
     constraint_id)
    SELECT v_season_id,
           skill_id,
           min,
           max,
           -1
    FROM JSONB_TO_RECORDSET(v_budget_team_config -> 'skill_constraints')
             AS x(skill_id INT, min INT, max INT)
    ON CONFLICT (season_id, skill_id,constraint_id) DO UPDATE
        SET min_entities_per_team = EXCLUDED.min_entities_per_team,
            max_entities_per_team = EXCLUDED.max_entities_per_team;

    INSERT INTO engine_config.application_user_team_configuration
    (season_id,
     min_user_teams,
     max_user_teams,
     min_playing_entities_per_team,
     max_playing_entities_per_team,
     is_substitute_allowed,
     min_substitute_entities_per_team,
     max_substitute_entities_per_team)
    SELECT v_season_id,
           (v_budget_team_config ->> 'min_team_per_user')::INT,
           (v_budget_team_config ->> 'max_team_per_user')::INT,
           (v_budget_team_config ->> 'min_picks_per_team_on_pitch')::INT,
           (v_budget_team_config ->> 'max_picks_per_team_on_pitch')::INT,
           (v_budget_team_config ->> 'sub_allowed')::BOOLEAN,
           (v_budget_team_config ->> 'min_picks_per_team_on_bench')::INT,
           (v_budget_team_config ->> 'max_picks_per_team_on_bench')::INT
    ON CONFLICT (season_id) DO UPDATE
        SET min_user_teams                   = EXCLUDED.min_user_teams,
            max_user_teams                   = EXCLUDED.max_user_teams,
            min_playing_entities_per_team    = EXCLUDED.min_playing_entities_per_team,
            max_playing_entities_per_team    = EXCLUDED.max_playing_entities_per_team,
            is_substitute_allowed            = EXCLUDED.is_substitute_allowed,
            min_substitute_entities_per_team = EXCLUDED.min_substitute_entities_per_team,
            max_substitute_entities_per_team = EXCLUDED.max_substitute_entities_per_team;

    INSERT INTO engine_config.season_config
    (season_id,
     player_points_calculation,
     draft_json,
     config_json)
    SELECT v_season_id,
           p_input -> 'points_system',
           p_input,
           p_input
    ON CONFLICT (season_id) DO UPDATE
        SET player_points_calculation = EXCLUDED.player_points_calculation,
            draft_json                = EXCLUDED.draft_json,
            config_json               = EXCLUDED.config_json;

    v_ret_type := 1;
    p_ret_type := v_ret_type;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_game_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_languages(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "languages": [
    {
      "language_name": "English",
      "language_code": "en"
    },
    {
      "language_name": "French",
      "language_code": "fr"
    }
  ]
}
*/
DECLARE
    v_season_id      INTEGER;
    v_language_codes VARCHAR[];
    v_ret_type       INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::INT;

    UPDATE engine_config.language
    SET is_deleted = TRUE
    WHERE is_deleted = FALSE
      AND language_code NOT IN (SELECT l.language_code
                                FROM JSONB_TO_RECORDSET(p_input -> 'languages') AS l(
                                                                                     language_code VARCHAR(64),
                                                                                     language_name VARCHAR(100)
                                    ))
      AND season_id = v_season_id;

    INSERT INTO engine_config.language
    (season_id,
     language_code,
     language_name)
    SELECT v_season_id,
           l.language_code,
           l.language_name
    FROM JSONB_TO_RECORDSET(p_input -> 'languages') AS l(
                                                         language_code VARCHAR(64),
                                                         language_name VARCHAR(100)
        )
    ON CONFLICT (season_id, language_code)
        DO UPDATE SET language_name = EXCLUDED.language_name,
                      is_deleted    = CASE
                                          WHEN engine_config.language.is_deleted THEN FALSE
                                          ELSE engine_config.language.is_deleted END;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_languages',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_localization_config(p_opt_type INTEGER, p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "localization": [
    {
      "language_code": "en",
      "translations": [
        {
          "language_key": "lang_1",
          "value": "Welcome",
          "show_key": true
        },
        {
          "language_key": "lang_2",
          "value": "Hello",
          "show_key": true
        },
        {
          "language_key": "lang_2",
          "value": "Hello",
          "show_key": true
        }
      ]
    },
    {
      "language_code": "fr",
      "translations": [
        {
          "language_key": "lang_1",
          "value": "bienvenue",
          "show_key": true
        },
        {
          "language_key": "lang_2",
          "value": "Bonjour",
          "show_key": true
        }
      ]
    }
  ]
}
*/
DECLARE
    v_season_id         SMALLINT;
    v_localization_json JSONB;
    v_existing_json     JSONB;
    v_ret_type          INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;
    v_localization_json := p_input -> 'localization';

    IF p_opt_type = 1 THEN
        INSERT INTO engine_config.season_config
        (season_id,
         localization)
        SELECT v_season_id,
               v_localization_json
        ON CONFLICT (season_id)
            DO UPDATE SET localization = EXCLUDED.localization;

    ELSIF p_opt_type = 2 THEN
        SELECT localization
        INTO v_existing_json
        FROM engine_config.season_config
        WHERE season_id = v_season_id;

        IF v_existing_json IS NULL THEN
            v_existing_json := '[]'::jsonb;
        END IF;

        IF EXISTS (SELECT 1
                   FROM JSONB_ARRAY_ELEMENTS(v_localization_json) AS l
                            LEFT JOIN engine_config.language lang ON (l ->> 'language_code') ILIKE lang.language_code
                   WHERE lang.language_code IS NULL)
        THEN
            v_ret_type := 2;
            RAISE EXCEPTION 'Invalid language code present in input';
        END IF;

        CREATE TEMP TABLE tmp_existing_translations
        (
            language_code TEXT,
            language_key  TEXT,
            value         TEXT,
            show_key      BOOLEAN,
            PRIMARY KEY (language_code, language_key)
        ) ON COMMIT DROP;

        CREATE TEMP TABLE tmp_input_translations
        (
            language_code TEXT,
            language_key  TEXT,
            value         TEXT,
            show_key      BOOLEAN
        ) ON COMMIT DROP;

        INSERT INTO tmp_existing_translations
        SELECT e ->> 'language_code',
               t.elem ->> 'language_key',
               t.elem ->> 'value',
               COALESCE((t.elem ->> 'show_key')::BOOLEAN, FALSE)
        FROM JSONB_ARRAY_ELEMENTS(v_existing_json) AS e,
             JSONB_ARRAY_ELEMENTS(e -> 'translations') AS t(elem);

        INSERT INTO tmp_input_translations
        SELECT l ->> 'language_code',
               t.elem ->> 'language_key',
               t.elem ->> 'value',
               COALESCE((t.elem ->> 'show_key')::BOOLEAN, FALSE)
        FROM JSONB_ARRAY_ELEMENTS(v_localization_json) AS l,
             JSONB_ARRAY_ELEMENTS(l -> 'translations') AS t(elem);

        INSERT INTO tmp_existing_translations
        SELECT language_code, language_key, value, show_key
        FROM tmp_input_translations
        ON CONFLICT (language_code, language_key)
            DO UPDATE SET value    = EXCLUDED.value,
                          show_key = EXCLUDED.show_key;

        SELECT JSONB_AGG(
                       JSONB_BUILD_OBJECT(
                               'language_code', language_code,
                               'translations', translations
                       )
               )
        INTO v_existing_json
        FROM (SELECT language_code,
                     JSONB_AGG(
                             JSONB_BUILD_OBJECT(
                                     'language_key', language_key,
                                     'value', value,
                                     'show_key', show_key
                             )
                     ) AS translations
              FROM tmp_existing_translations
              GROUP BY language_code) sub;

        UPDATE engine_config.season_config
        SET localization = v_existing_json
        WHERE season_id = v_season_id;

    ELSE
        v_ret_type := 2;
        RAISE EXCEPTION 'Invalid operation type: %', p_opt_type;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_localization_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_player_valuation_config(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
   "season_id":1,
   "player_valuation_config":{
      "algorithm_type_id":1,
      "percentage_algorithm_config":{
         "entity_minimum_value":40,
         "entity_maximum_value":30,
         "previous_game_sets":3,
         "percentage_grouping":[
            {
               "from":0,
               "to":20,
               "value_change":1,
               "negative_positive":"positive"
            },
            {
               "from":20,
               "to":30,
               "value_change":0.5,
               "negative_positive":"positive"
            },
            {
               "from":30,
               "to":60,
               "value_change":0.5,
               "negative_positive":"positive"
            },
            {
               "from":60,
               "to":90,
               "value_change":1,
               "negative_positive":"negative"
            },
            {
               "from":90,
               "to":100,
               "value_change":1,
               "negative_positive":"negative"
            }
         ]
      },
      "weighted_algorithm_config":null
   }
}
*/
DECLARE
    v_row_count INTEGER;
    v_season_id SMALLINT;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    INSERT INTO engine_config.season_config
    (season_id,
     player_valuation)
    SELECT v_season_id,
           p_input -> 'player_valuation_config'
    ON CONFLICT (season_id) DO UPDATE
        SET player_valuation = p_input -> 'player_valuation_config';

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;

        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_player_valuation_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_transfer_manager(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "budget_config": {
    "is_additional_budget": false,
    "additional_budget_details": [
      {
        "additional_budget": 0,
        "from_gameset_id": 3
      }
    ]
  },
  "transfer_config": {
    "is_net_transfers_allowed": false,
    "additional_transfer_details": [
      {
        "is_for_individual_gameset": false,
        "start_gameset_id": 1,
        "end_gameset_id": 3,
        "no_of_transfers": 2,
        "transfers_carried_over": 2,
        "additional_transfers": 2,
        "additional_transfers_points": 10
      }
    ]
  }
}
*/
DECLARE
    v_season_id                                SMALLINT;
    v_budget_config                            JSONB;
    v_transfer_config                          JSONB;
    v_is_additional_budget                     BOOLEAN;
    v_is_net_transfers_allowed                 BOOLEAN;
    v_budget_value                             NUMERIC;
    v_currency_symbol                          VARCHAR;
    v_is_transfer_allowed                      BOOLEAN;
    v_is_unlimited_transfer_allowed            BOOLEAN;
    v_total_transfer_allowed                   SMALLINT;
    v_is_additional_transfer_allowed           BOOLEAN;
    v_is_unlimited_additional_transfer_allowed BOOLEAN;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;
    v_budget_config := p_input -> 'budget_config';
    v_transfer_config := p_input -> 'transfer_config';
    v_is_additional_budget := (v_budget_config ->> 'is_additional_budget')::BOOLEAN;
    v_is_net_transfers_allowed := (v_transfer_config ->> 'is_net_transfers_allowed')::BOOLEAN;

    IF v_budget_config ? 'is_additional_budget' THEN
        UPDATE engine_config.application_budget_configuration
        SET is_additional_budget_allowed = v_is_additional_budget
        WHERE season_id = v_season_id
          AND additional_budget_allowed_from_round = -1;
    END IF;

    IF v_is_additional_budget = TRUE AND (v_budget_config -> 'additional_budget_details') IS NOT NULL AND JSONB_ARRAY_LENGTH(v_budget_config -> 'additional_budget_details') > 0 THEN
        DELETE
        FROM engine_config.application_budget_configuration
        WHERE season_id = v_season_id
          AND additional_budget_allowed_from_round <> -1
          AND additional_budget_allowed_from_round NOT IN (SELECT (value ->> 'from_gameset_id')::SMALLINT
                                                           FROM JSONB_ARRAY_ELEMENTS(v_budget_config -> 'additional_budget_details') AS value);

        SELECT budget_value,
               currency_symbol
        INTO v_budget_value,
            v_currency_symbol
        FROM engine_config.application_budget_configuration
        WHERE season_id = v_season_id
          AND additional_budget_allowed_from_round = -1;

        IF NOT FOUND THEN
            p_ret_type := 3;
            RETURN;
        END IF;

        INSERT INTO engine_config.application_budget_configuration
        (season_id,
         budget_value,
         currency_symbol,
         is_additional_budget_allowed,
         additional_budget_value,
         additional_budget_allowed_from_round)
        SELECT v_season_id,
               v_budget_value,
               v_currency_symbol,
               v_is_additional_budget,
               (value ->> 'additional_budget')::NUMERIC,
               (value ->> 'from_gameset_id')::SMALLINT
        FROM JSONB_ARRAY_ELEMENTS(v_budget_config -> 'additional_budget_details') AS value
        ON CONFLICT (season_id, additional_budget_allowed_from_round)
            DO UPDATE
            SET is_additional_budget_allowed = EXCLUDED.is_additional_budget_allowed,
                additional_budget_value      = EXCLUDED.additional_budget_value;

    ELSEIF v_is_additional_budget = FALSE THEN
        DELETE
        FROM engine_config.application_budget_configuration
        WHERE season_id = v_season_id
          AND is_additional_budget_allowed = TRUE
          AND additional_budget_allowed_from_round <> -1;

    ELSE
        p_ret_type := 2;
        RETURN;
    END IF;

    SELECT is_transfer_allowed,
           is_unlimited_transfer_allowed,
           total_transfer_allowed,
           is_additional_transfer_allowed,
           is_unlimited_additional_transfer_allowed
    INTO v_is_transfer_allowed,
        v_is_unlimited_transfer_allowed,
        v_total_transfer_allowed,
        v_is_additional_transfer_allowed,
        v_is_unlimited_additional_transfer_allowed
    FROM engine_config.application_user_team_transfer_configuration
    WHERE season_id = v_season_id
      AND from_gameset_id = -1
      AND to_gameset_id = -1;

    IF NOT FOUND THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    DELETE
    FROM engine_config.application_user_team_transfer_configuration
    WHERE season_id = v_season_id
      AND from_gameset_id <> -1
      AND to_gameset_id <> -1
      AND (from_gameset_id, to_gameset_id) NOT IN (SELECT (value ->> 'start_gameset_id')::SMALLINT,
                                                          (value ->> 'end_gameset_id')::SMALLINT
                                                   FROM JSONB_ARRAY_ELEMENTS(v_transfer_config -> 'additional_transfer_details') AS value);

    IF v_transfer_config ? 'is_net_transfers_allowed' THEN
        UPDATE engine_config.application_user_team_transfer_configuration
        SET is_net_transfers_allowed = v_is_net_transfers_allowed
        WHERE season_id = v_season_id
          AND from_gameset_id = -1
          AND to_gameset_id = -1;
    END IF;

    IF v_transfer_config ? 'additional_transfer_details' AND JSONB_ARRAY_LENGTH(v_transfer_config -> 'additional_transfer_details') > 0 THEN
        INSERT INTO engine_config.application_user_team_transfer_configuration
        (season_id,
         is_transfer_allowed,
         is_unlimited_transfer_allowed,
         is_net_transfers_allowed,
         total_transfer_allowed,
         is_additional_transfer_allowed,
         is_unlimited_additional_transfer_allowed,
         total_additional_transfer_allowed,
         additional_transfer_negative_points,
         unused_transfers_carry_over,
         all_unused_transfers_carry_over,
         total_unused_transfers_carry_over,
         is_for_individual_gameset,
         from_gameset_id,
         to_gameset_id)
        SELECT v_season_id,
               v_is_transfer_allowed,
               v_is_unlimited_transfer_allowed,
               v_is_net_transfers_allowed,
               (value ->> 'no_of_transfers')::SMALLINT,
               v_is_additional_transfer_allowed,
               v_is_unlimited_additional_transfer_allowed,
               (value ->> 'additional_transfers')::SMALLINT,
               (value ->> 'additional_transfers_points')::SMALLINT,
               (value ->> 'transfers_carried_over')::SMALLINT,
               (value ->> 'transfers_carried_over')::SMALLINT,
               (value ->> 'transfers_carried_over')::SMALLINT,
               (value ->> 'is_for_individual_gameset')::BOOLEAN,
               (value ->> 'start_gameset_id')::SMALLINT,
               (value ->> 'end_gameset_id')::SMALLINT
        FROM JSONB_ARRAY_ELEMENTS(v_transfer_config -> 'additional_transfer_details') AS value
        ON CONFLICT (season_id, from_gameset_id, to_gameset_id)
            DO UPDATE
            SET is_transfer_allowed                      = EXCLUDED.is_transfer_allowed,
                is_unlimited_transfer_allowed            = EXCLUDED.is_unlimited_transfer_allowed,
                is_net_transfers_allowed                 = EXCLUDED.is_net_transfers_allowed,
                total_transfer_allowed                   = EXCLUDED.total_transfer_allowed,
                is_additional_transfer_allowed           = EXCLUDED.is_additional_transfer_allowed,
                is_unlimited_additional_transfer_allowed = EXCLUDED.is_unlimited_additional_transfer_allowed,
                total_additional_transfer_allowed        = EXCLUDED.total_additional_transfer_allowed,
                additional_transfer_negative_points      = EXCLUDED.additional_transfer_negative_points,
                unused_transfers_carry_over              = EXCLUDED.unused_transfers_carry_over,
                all_unused_transfers_carry_over          = EXCLUDED.all_unused_transfers_carry_over,
                total_unused_transfers_carry_over        = EXCLUDED.total_unused_transfers_carry_over,
                is_for_individual_gameset                = EXCLUDED.is_for_individual_gameset;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_transfer_manager',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.manage_maintenance_mode_config(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
    "season_id": 1,
    "maintenance_mode_config": {
        "maintenance_code": "MAINTENANCE_001",
        "maintenance_message": "Maintenance in progress",
        "device_ids": [1, 2]
    }
}
*/
DECLARE
    v_maintenance_code    VARCHAR;
    v_maintenance_message VARCHAR;
    v_device_ids          SMALLINT[];
    v_season_id           INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::INTEGER;
    v_maintenance_code := p_input -> 'maintenance_mode_config' ->> 'maintenance_code';
    v_maintenance_message := p_input -> 'maintenance_mode_config' ->> 'maintenance_message';

    IF JSONB_TYPEOF(p_input -> 'maintenance_mode_config' -> 'device_ids') = 'array' THEN
        v_device_ids := ARRAY(SELECT JSONB_ARRAY_ELEMENTS_TEXT(p_input -> 'maintenance_mode_config' -> 'device_ids')::SMALLINT);
    ELSE
        v_device_ids := ARRAY []::SMALLINT[];
    END IF;

    DELETE
    FROM engine_config.application_maintenance
    WHERE season_id = v_season_id;

    IF v_device_ids IS NOT NULL AND ARRAY_LENGTH(v_device_ids, 1) > 0 THEN
        INSERT INTO engine_config.application_maintenance
        (season_id,
         device_id,
         maintenance_code,
         maintenance_message,
         updated_at)
        SELECT v_season_id,
               UNNEST(v_device_ids),
               v_maintenance_code,
               v_maintenance_message,
               NOW();
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.manage_maintenance_mode_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.season_activate_deactivate(p_opt_type INTEGER, p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_name": "IPL - 2025",
  "device_ids": [
    1,
    2,
    3
  ] -- not there for opt_type 2
}
*/
DECLARE
    v_row_count INTEGER;
    v_ret_type  INTEGER;
BEGIN
    IF p_opt_type = 1 THEN

        -- Activate the season
        UPDATE engine_config.season
        SET status_id               = 2,
            is_enabled_for_operator = TRUE,
            device_id               = ARRAY(SELECT JSONB_ARRAY_ELEMENTS_TEXT(p_input -> 'device_ids')::SMALLINT)
        WHERE season_name = p_input ->> 'season_name';

    ELSIF p_opt_type = 2 THEN

        -- Deactivate the season
        UPDATE engine_config.season
        SET status_id               = 3,
            is_enabled_for_operator = FALSE
        WHERE season_name = p_input ->> 'season_name';

    ELSE
        v_ret_type := 2;
        RAISE EXCEPTION 'Invalid option type: %', p_opt_type;
    END IF;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        v_ret_type := 3;
        RAISE EXCEPTION 'No data found for season name: %', p_input ->> 'season_name';
    END IF;

    p_ret_type := 1;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.season_activate_deactivate',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.user_login(p_input jsonb, OUT p_ret_type NUMERIC, OUT p_user_data jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
/*
{
  "user_details": {
    "user_name": "abc",
    "password": "easrdtfygad1233",
  }
}
*/
DECLARE
    v_user_name      VARCHAR;
    v_password       VARCHAR;
    v_user_auth_data RECORD;
BEGIN
    v_user_name := p_input -> 'user_details' ->> 'user_name';
    v_password := p_input -> 'user_details' ->> 'password';

    SELECT au.user_id,
           au.is_super_admin,
           app.application_id,
           app.config_json
    INTO v_user_auth_data
    FROM engine_config.admin_user au
             LEFT JOIN engine_config.application app
                       ON au.user_id = app.admin_id
    WHERE au.user_name = v_user_name
      AND au.user_password = v_password;

    IF v_user_auth_data IS NOT NULL THEN
        p_user_data := JSONB_SET(
                JSONB_SET(
                        COALESCE(v_user_auth_data.config_json, '{}'::jsonb),
                        '{user_details}',
                        (COALESCE(v_user_auth_data.config_json -> 'user_details', '{}'::jsonb)) || JSONB_BUILD_OBJECT(
                                'user_id', v_user_auth_data.user_id,
                                'is_super_admin', v_user_auth_data.is_super_admin
                                                                                                   )
                ),
                '{application_id}',
                TO_JSONB(v_user_auth_data.application_id)
                       );
        p_ret_type := 1;
    ELSE
        p_user_data := NULL;
        p_ret_type := 10;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_user_data := NULL;
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.user_login',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_game_config(p_season_id INTEGER, OUT p_ret_type INTEGER, OUT p_game_config jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    SELECT config_json
    INTO p_game_config
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_game_config IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1; -- Success
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_game_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_team_management(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "team_management": {
    "captain_change": {
      "can_captain_be_changed": false,
      "can_vice_captain_be_changed": false
    },
    "auto_substitution": {
      "disabled_if_manual": false,
      "player_on_bench_suspended": false,
      "player_on_pitch_suspended": false,
      "if_pitch_player_not_playing": false,
      "on_bench_player_played_can_return": false,
      "on_pitch_player_substituted_can_return": false,
      "transfer_multiplier_to_substitute": true
    },
    "manual_substitution": {
      "player_on_bench_gets_suspended": false,
      "player_on_pitch_gets_suspended": false,
      "on_bench_player_played_can_return": false,
      "on_pitch_player_substituted_can_return": false
    }
  }
}
*/
DECLARE
    v_season_id SMALLINT;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    -- Check if the season exists
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    INSERT INTO engine_config.season_config
    (season_id,
     team_management)
    SELECT v_season_id,
           p_input -> 'team_management'
    ON CONFLICT (season_id) DO UPDATE
        SET team_management = EXCLUDED.team_management;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;

        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_team_management',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_team_management(p_season_id SMALLINT, OUT p_team_management jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    -- Check if the season exists
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 3; -- Season not found
        RETURN;
    END IF;

    SELECT team_management
    INTO p_team_management
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_team_management IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_team_management',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.ins_upd_game_rules(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "game_rules": {
    "unique_team_name": true,
    "allow_team_name_change": true,
    "is_live_points": true,
    "allow_late_onboarding": true,
    "is_profanity_check": true
  }
}
*/
DECLARE
    v_season_id SMALLINT := (p_input ->> 'season_id')::SMALLINT;
BEGIN
    -- Check if the season exists
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = v_season_id) THEN
        p_ret_type := 31;
        RETURN;
    END IF;

    INSERT INTO engine_config.season_config
    (season_id,
     game_rules)
    SELECT v_season_id,
           p_input -> 'game_rules'
    ON CONFLICT (season_id) DO UPDATE
        SET game_rules = EXCLUDED.game_rules;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;

        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.ins_upd_game_rules',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_game_rules(p_season_id INTEGER, OUT p_game_rules jsonb, OUT p_ret_type INTEGER) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31;
        RETURN;
    END IF;

    SELECT game_rules
    INTO p_game_rules
    FROM engine_config.season_config
    WHERE season_id = p_season_id;

    IF p_game_rules IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_game_rules',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('season_id', p_season_id)
             );
END;
$$;

CREATE OR REPLACE FUNCTION engine_config.get_country_list(OUT p_ret_type INTEGER, OUT p_country_list jsonb) RETURNS RECORD
    LANGUAGE plpgsql
AS
$$
BEGIN
    SELECT JSONB_AGG(row)
    INTO p_country_list
    FROM (SELECT country_id,
                 country_name,
                 country_code
          FROM engine_config.country
          ORDER BY country_name, country_id) AS row;

    IF p_country_list IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'engine_config.get_country_list',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := NULL
             );
END;
$$; 