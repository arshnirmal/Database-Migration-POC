CREATE OR REPLACE FUNCTION point_calculation.get_last_submitted_fixture(p_season_id integer, OUT p_fixture_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    -- Validate season exists
    IF NOT EXISTS(SELECT 1 FROM engine_config.season WHERE season_id = p_season_id) THEN
        p_ret_type := 31; -- Season not found
        RETURN;
    END IF;

    SELECT JSONB_BUILD_OBJECT(
                   'gameset_id', ps.gameset_id,
                   'fixture_id', ps.fixture_id,
                   'fixture_name', f.fixture_name,
                   'fixture_datetime', f.fixture_datetime_iso8601,
                   'last_submitted_at', updated_at
           )
    INTO p_fixture_data
    FROM log.point_submission_log ps
             JOIN game_management.fixture f
                  ON ps.fixture_id = f.fixture_id
                      AND ps.season_id = p_season_id
    WHERE ps.season_id = p_season_id
      AND f.season_id = p_season_id
    ORDER BY ps.updated_at DESC
    LIMIT 1;

    IF p_fixture_data IS NULL THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'point_calculation.get_last_submitted_fixture',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := jsonb_build_object('season_id', p_season_id)
                );
END;
$$;

CREATE OR REPLACE FUNCTION point_calculation.get_gameset_players(p_input jsonb, OUT p_ret_type integer, OUT p_player_data jsonb) RETURNS record
    LANGUAGE plpgsql
AS
$$
/*
{
    "season_id": 1,
    "gameset_id": 2,
    "fixture_id": 123
}
*/
DECLARE
    v_gameset_id   SMALLINT;
    v_fixture_id   SMALLINT;
    v_season_id    SMALLINT;
    v_fixture_data JSONB;
    v_player_data  JSONB;
    v_team_ids     INTEGER[];
BEGIN
    v_gameset_id := (p_input ->> 'gameset_id')::SMALLINT;
    v_fixture_id := (p_input ->> 'fixture_id')::SMALLINT;
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    SELECT JSON_BUILD_OBJECT(
                   'fixture_id', F.fixture_id,
                   'fixture_name', F.fixture_name,
                   'fixture_status', F.fixture_status,
                   'fixture_datetime', F.fixture_datetime_iso8601,
                   'fixture_number', F.fixture_number,
                   'gameset_id', F.gameset_id,
                   'phase_id', F.phase_id,
                   'gameset_name', G.gameset_name,
                   'phase_name', P.phase_name
           ),
           (SELECT ARRAY_AGG((team_property ->> 'value')::INTEGER)
            FROM jsonb_path_query(
                         f.sport_properties,
                         '$[*] ? (@.property_name like_regex "team\\d+_id$")'
                         ) AS team_property)
    INTO v_fixture_data, v_team_ids
    FROM game_management.fixture F
             LEFT JOIN game_management.gameset G
                       ON F.gameset_id = G.gameset_id
                           AND F.season_id = G.season_id
             LEFT JOIN game_management.phase P
                       ON F.phase_id = P.phase_id
                           AND F.season_id = P.season_id
    WHERE F.gameset_id = v_gameset_id
      AND F.fixture_id = v_fixture_id
      AND F.season_id = v_season_id;

    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'player_id', GP.player_id,
                           'player_name', P.player_name,
                           'skill_id', P.skill_id,
                           'skill_name', SS.skill_name,
                           'team_id', GP.team_id,
                           'team_name', T.team_name,
                           'points', GP.points,
                           'player_stats', GP.player_stats
                   )
           )
    INTO v_player_data
    FROM game_play.gameset_player GP
             JOIN game_management.player P
                  ON GP.player_id = P.player_id
             JOIN game_management.team T
                  ON GP.team_id = T.team_id
             JOIN engine_config.sport_skill SS
                  ON SS.skill_id = P.skill_id
    WHERE GP.season_id = v_season_id
      AND GP.gameset_id = v_gameset_id
      AND GP.team_id = ANY (v_team_ids);

    IF v_player_data IS NULL THEN
        p_ret_type := 3; -- No players found
        p_player_data := '[]'::JSONB;
        RETURN;
    END IF;

    p_player_data := JSONB_BUILD_OBJECT(
            'fixture_data', v_fixture_data,
            'player_data', v_player_data
                     );
    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'point_calculation.get_gameset_players',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION point_calculation.ins_upd_player_stats(p_input jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "gameset_id": 1,
  "fixture_id": 123,
  "player_data": [
    {
      "player_id": 1,
      "points": 10,
      "player_stats": [
        {
          "stat_name": "goal",
          "stat_value": 1,
          "points": 10
        }
      ]
    }
  ]
}
*/
DECLARE
    v_season_id   SMALLINT;
    v_gameset_id  SMALLINT;
    v_fixture_id  INTEGER;
    v_player_data JSONB;
    v_row_count   INTEGER;
BEGIN
    v_player_data := p_input -> 'player_data';
    v_season_id := (p_input ->> 'season_id')::SMALLINT;
    v_gameset_id := (p_input ->> 'gameset_id')::SMALLINT;
    v_fixture_id := (p_input ->> 'fixture_id')::INTEGER;

    WITH player_data AS (SELECT (player ->> 'player_id')::INTEGER AS player_id,
                                (player ->> 'points')::NUMERIC    AS points,
                                (player -> 'player_stats')        AS stats
                         FROM JSONB_ARRAY_ELEMENTS(v_player_data) AS t(player))
    UPDATE game_play.gameset_player GP
    SET points       = PD.points,
        player_stats = PD.stats
    FROM player_data PD
    WHERE GP.player_id = PD.player_id
      AND GP.season_id = v_season_id
      AND GP.gameset_id = v_gameset_id;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    INSERT INTO log.point_submission_log
    (season_id,
     gameset_id,
     fixture_id,
     created_at,
     updated_at)
    SELECT v_season_id,
           v_gameset_id,
           v_fixture_id,
           NOW(),
           NOW()
    ON CONFLICT (season_id, gameset_id, fixture_id)
        DO UPDATE SET updated_at = NOW();

    IF v_row_count = JSONB_ARRAY_LENGTH(v_player_data) THEN
        p_ret_type := 1;
    ELSE
        p_ret_type := 101;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'point_calculation.ins_upd_player_stats',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION point_calculation.get_entity_stats(p_sport_id integer, OUT p_stats_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
BEGIN
    SELECT JSONB_AGG(
                   JSONB_BUILD_OBJECT(
                           'stat_id', stat_id,
                           'stat_name', stat_name,
                           'calculation_type', calculation_type
                   )
           )
    INTO p_stats_data
    FROM point_calculation.entity_stat
    WHERE sport_id = p_sport_id;

    IF p_stats_data IS NULL THEN
        p_ret_type := 3;
        p_stats_data := '[]'::JSONB;
    ELSE
        p_ret_type := 1;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_stats_data := NULL;
        CALL log.log_error(
                p_error_type := 1,
                p_function_name := 'point_calculation.get_entity_stats',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := jsonb_build_object('sport_id', p_sport_id)
        );
END;
$$; 