CREATE OR REPLACE FUNCTION gameplay.create_team(p_team_json jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "device_id": 1,
  "event_group": {
    "phase_id": 1,
    "gameset_id": 9,
    "gameday_id": 3
  },
  "captain_id": 1,
  "vice_captain_id": 0,
  "booster": {
    "booster_id": 1,
    "entity_id": 1
  },
  "inplay_entities": [
    {
      "entity_id": 1,
      "skill_id": 1,
      "order": 1
    },
    {
      "entity_id": 2,
      "skill_id": 1,
      "order": 2
    },
    {
      "entity_id": 3,
      "skill_id": 1,
      "order": 3
    },
    {
      "entity_id": 4,
      "skill_id": 1,
      "order": 4
    },
    {
      "entity_id": 5,
      "skill_id": 1,
      "order": 5
    },
    {
      "entity_id": 6,
      "skill_id": 1,
      "order": 6
    },
    {
      "entity_id": 7,
      "skill_id": 1,
      "order": 7
    },
    {
      "entity_id": 8,
      "skill_id": 1,
      "order": 8
    },
    {
      "entity_id": 9,
      "skill_id": 1,
      "order": 9
    },
    {
      "entity_id": 10,
      "skill_id": 1,
      "order": 10
    },
    {
      "entity_id": 11,
      "skill_id": 1,
      "order": 11
    }
  ],
  "reserved_entities": [
    {
      "entity_id": 12,
      "skill_id": 1,
      "order": 1
    },
    {
      "entity_id": 13,
      "skill_id": 1,
      "order": 2
    },
    {
      "entity_id": 14,
      "skill_id": 1,
      "order": 3
    },
    {
      "entity_id": 15,
      "skill_id": 1,
      "order": 4
    }
  ],
  "team_name": "saitama(encoded)"
}
*/
DECLARE
    v_season_id              SMALLINT;
    v_user_id                NUMERIC;
    v_gameset_id             SMALLINT;
    v_gameday_id             SMALLINT;
    v_captain_id             INTEGER;
    v_vice_captain_id        INTEGER;
    v_team_name              CHARACTER VARYING;
    v_inplay_entities        JSONB;
    v_reserve_entities       JSONB;
    v_partition_id           SMALLINT;
    v_team_count             SMALLINT;
    v_max_user_teams         SMALLINT;
    v_team_no                SMALLINT;
    v_booster_id             SMALLINT;
    v_booster_player_id      INTEGER;
    v_total_transfer_allowed SMALLINT;
    v_team_valuation         NUMERIC(10, 2);
    v_remaining_budget       NUMERIC(10, 2);
    v_team_players           INTEGER[];
BEGIN
    SELECT (p_team_json ->> 'season_id')::SMALLINT,
           (p_team_json ->> 'user_id')::NUMERIC,
           (p_team_json -> 'event_group' ->> 'gameset_id')::SMALLINT,
           (p_team_json -> 'event_group' ->> 'gameday_id')::SMALLINT,
           (p_team_json ->> 'captain_id')::INTEGER,
           (p_team_json ->> 'vice_captain_id')::INTEGER,
           p_team_json ->> 'team_name',
           p_team_json -> 'inplay_entities',
           p_team_json -> 'reserve_entities',
           (p_team_json -> 'booster' ->> 'booster_id')::SMALLINT,
           (p_team_json -> 'booster' ->> 'player_id')::INTEGER,
           (p_team_json ->> 'team_valuation')::NUMERIC(10, 2),
           (p_team_json ->> 'remaining_budget')::NUMERIC(10, 2)
    INTO
        v_season_id,
        v_user_id,
        v_gameset_id,
        v_gameday_id,
        v_captain_id,
        v_vice_captain_id,
        v_team_name,
        v_inplay_entities,
        v_reserve_entities,
        v_booster_id,
        v_booster_player_id,
        v_team_valuation,
        v_remaining_budget;

    ------------------------------------------------------------------------------

    SELECT partition_id
    INTO v_partition_id
    FROM game_user.user
    WHERE user_id = v_user_id;

    IF v_partition_id IS NULL THEN
        p_ret_type := 10; -- User not found
        RETURN;
    END IF;

    ------------------------------------------------------------------------------

    SELECT COUNT(*)
    INTO v_team_count
    FROM gameplay.user_teams
    WHERE user_id = v_user_id
      AND partition_id = v_partition_id
      AND season_id = v_season_id;

    -- Fetch the maximum number of teams allowed for the user in the current season
    SELECT COALESCE(max_user_teams, 1)
    INTO v_max_user_teams
    FROM engine_config.application_user_team_configuration
    WHERE season_id = v_season_id;

    IF v_team_count < v_max_user_teams THEN

        v_team_no := v_team_count + 1;

        INSERT INTO gameplay.user_teams
        (user_id,
         team_no,
         team_name,
         upper_team_name,
         season_id,
         gameset_id,
         gameday_id,
         profanity_status,
         profanity_updated_date,
         partition_id,
         created_date,
         updated_date)
        SELECT v_user_id,
               v_team_no,
               v_team_name,
               UPPER(v_team_name),
               v_season_id,
               v_gameset_id,
               v_gameday_id,
               NULL,
               NULL,
               v_partition_id,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP;

        SELECT ARRAY_AGG((p.player ->> 'entity_id')::INTEGER)
        INTO v_team_players
        FROM (SELECT JSONB_ARRAY_ELEMENTS(v_inplay_entities) AS player
              UNION ALL
              SELECT JSONB_ARRAY_ELEMENTS(v_reserve_entities) AS player) p;

        INSERT INTO gameplay.user_team_detail
        (season_id,
         user_id,
         team_no,
         gameset_id,
         gameday_id,
         from_gameset_id,
         from_gameday_id,
         to_gameset_id,
         to_gameday_id,
         team_valuation,
         remaining_budget,
         team_players,
         captain_player_id,
         vice_captain_player_id,
         team_json,
         substitution_allowed,
         substitution_made,
         substitution_left,
         transfers_allowed,
         transfers_made,
         transfers_left,
         booster_id,
         booster_player_id,
         booster_team_players,
         partition_id,
         created_date,
         updated_date)
        SELECT v_season_id,
               v_user_id,
               v_team_no,
               v_gameset_id,
               v_gameday_id,
               v_gameset_id,
               v_gameday_id,
               NULL, -- to gameset value will be updated in transfer_team function
               NULL,
               v_team_valuation,
               v_remaining_budget,
               v_team_players,
               v_captain_id,
               v_vice_captain_id,
               JSONB_BUILD_OBJECT('inplay_entities', v_inplay_entities, 'reserve_entities', v_reserve_entities),
               NULL,
               NULL,
               NULL,
               v_total_transfer_allowed,
               0,
               v_total_transfer_allowed,
               v_booster_id,
               v_booster_player_id,
               NULL,
               v_partition_id,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP;

        p_ret_type := 1; -- Success
    ELSE
        p_ret_type := 13; -- Max teams reached
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'gameplay.create_team',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_team_json
             );
END;
$$;

CREATE OR REPLACE FUNCTION gameplay.transfer_team(p_team_json jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "device_id": 1,
  "user_id": 1,
  "season_id": 1,
  "event_group": {
    "phase_id": 1,
    "gameset_id": 9,
    "gameday_id": 3
  },
  "team_no": 1,
  "captain_id": 1,
  "vice_captain_id": 0,
  "booster": {
    "booster_id": 1,
    "entity_id": 13
  },
  "entities_in": [
    {
      "entity_id": 13,
      "skill_id": 1,
      "order": 1
    },
    {
      "entity_id": 14,
      "skill_id": 1,
      "order": 2
    }
  ],
  "entities_out": [
    {
      "entity_id": 12,
      "skill_id": 1,
      "order": 1
    },
    {
      "entity_id": 13,
      "skill_id": 1,
      "order": 2
    }
  ]
}
*/
DECLARE
    v_season_id             SMALLINT;
    v_user_id               NUMERIC;
    v_gameset_id            SMALLINT;
    v_gameday_id            SMALLINT;
    v_captain_id            INTEGER;
    v_vice_captain_id       INTEGER;
    v_partition_id          SMALLINT;
    v_team_no               SMALLINT;
    v_booster_id            SMALLINT;
    v_booster_player_id     INTEGER;
    v_prev_remaining_budget NUMERIC(10, 2);
    v_new_remaining_budget  NUMERIC(10, 2);
    v_prev_team_array       INTEGER[];
    v_prev_team_json        JSONB;
    v_new_team_array        INTEGER[];
    v_new_team_json         JSONB;
    v_entities_in           JSONB;
    v_entities_out          JSONB;
    v_in_player_value       NUMERIC(10, 2);
    v_out_player_value      NUMERIC(10, 2);
    v_total_transfer_left   SMALLINT;
    v_team_gameset_id       SMALLINT;
    v_fixture_id_prev       INTEGER;
    v_gameday_id_prev       SMALLINT;
BEGIN
    SELECT (p_team_json ->> 'user_id')::NUMERIC,
           (p_team_json ->> 'season_id')::SMALLINT,
           (p_team_json -> 'event_group' ->> 'gameset_id')::SMALLINT,
           (p_team_json -> 'event_group' ->> 'gameday_id')::SMALLINT,
           (p_team_json ->> 'captain_id')::INTEGER,
           (p_team_json ->> 'vice_captain_id')::INTEGER,
           (p_team_json -> 'booster' ->> 'booster_id')::SMALLINT,
           (p_team_json -> 'booster' ->> 'entity_id')::INTEGER,
           (p_team_json ->> 'team_no')::SMALLINT,
           p_team_json -> 'entities_in',
           p_team_json -> 'entities_out'
    INTO
        v_user_id,
        v_season_id,
        v_gameset_id,
        v_gameday_id,
        v_captain_id,
        v_vice_captain_id,
        v_booster_id,
        v_booster_player_id,
        v_team_no,
        v_entities_in,
        v_entities_out;

    ------------------------------------------------------------------------------

    SELECT partition_id
    INTO v_partition_id
    FROM game_user.user
    WHERE user_id = v_user_id;

    IF v_partition_id IS NULL THEN
        p_ret_type := 10; -- User not found
        RETURN;
    END IF;

    ------------------------------------------------------------------------------

    -- Get the previous team state for budget calculation
    SELECT utd.remaining_budget,
           utd.team_players,
           utd.team_json,
           utd.transfers_left,
           utd.gameset_id
    INTO v_prev_remaining_budget,
        v_prev_team_array,
        v_prev_team_json,
        v_total_transfer_left,
        v_team_gameset_id
    FROM gameplay.user_team_detail utd
    WHERE utd.season_id = v_season_id
      AND utd.user_id = v_user_id
      AND utd.partition_id = v_partition_id
      AND utd.team_no = v_team_no
      AND utd.to_gameset_id IS NULL
      AND utd.to_gameday_id IS NULL;

    IF v_prev_team_array IS NULL THEN
        p_ret_type := 17; -- Team not found
        RETURN;
    END IF;

    ------------------------------------------------------------------------------

    -- Calculate the player values for the entities in and out
    WITH transferred_players AS (SELECT (elem ->> 'entity_id')::INTEGER AS player_id, 'in' AS transfer_type
                                 FROM JSONB_ARRAY_ELEMENTS(v_entities_in) AS elem
                                 UNION ALL
                                 SELECT (elem ->> 'entity_id')::INTEGER AS player_id, 'out' AS transfer_type
                                 FROM JSONB_ARRAY_ELEMENTS(v_entities_out) AS elem)
    SELECT COALESCE(SUM(gp.player_value) FILTER (WHERE tp.transfer_type = 'in'), 0),
           COALESCE(SUM(gp.player_value) FILTER (WHERE tp.transfer_type = 'out'), 0)
    INTO v_in_player_value,
        v_out_player_value
    FROM gameplay.gameset_player gp
             JOIN transferred_players tp ON gp.player_id = tp.player_id
    WHERE gp.gameset_id = v_gameset_id;

    IF (v_out_player_value + v_prev_remaining_budget) >= v_in_player_value THEN
        v_new_remaining_budget := (v_out_player_value + v_prev_remaining_budget) - v_in_player_value;
    ELSE
        p_ret_type := 16; -- Budget exceeded
        RETURN;
    END IF;

    ------------------------------------------------------------------------------

    -- Build the new team players array and json by removing entities_out from the previous team array and adding entities_in
    WITH p_out AS (SELECT (elem ->> 'entity_id')::INT AS out_id,
                          (elem ->> 'order')::INT     AS transfer_order
                   FROM JSONB_ARRAY_ELEMENTS(v_entities_out) AS elem),
         p_in AS (SELECT (elem ->> 'entity_id')::INT AS in_id,
                         (elem ->> 'order')::INT     AS transfer_order,
                         elem                        AS in_json
                  FROM JSONB_ARRAY_ELEMENTS(v_entities_in) AS elem),
         transfer_map AS (SELECT p_out.out_id,
                                 p_in.in_id,
                                 p_in.in_json
                          FROM p_out
                                   JOIN p_in ON p_out.transfer_order = p_in.transfer_order),
         all_prev_players AS (SELECT elem, 'inplay' AS list_type
                              FROM JSONB_ARRAY_ELEMENTS(v_prev_team_json -> 'inplay_entities') elem
                              UNION ALL
                              SELECT elem, 'reserve' AS list_type
                              FROM JSONB_ARRAY_ELEMENTS(v_prev_team_json -> 'reserve_entities') elem),
         new_player_list AS (SELECT CASE
                                        WHEN t_map.out_id IS NOT NULL THEN
                                            t_map.in_json || JSONB_BUILD_OBJECT('order', (p.elem ->> 'order')::INT)
                                        ELSE
                                            p.elem
                                        END AS new_player_elem,
                                    p.list_type
                             FROM all_prev_players p
                                      LEFT JOIN transfer_map t_map ON (p.elem ->> 'entity_id')::INT = t_map.out_id)
    SELECT ARRAY(SELECT (new_player_elem ->> 'entity_id')::INT FROM new_player_list),
           JSONB_BUILD_OBJECT(
                   'inplay_entities', COALESCE((SELECT JSONB_AGG(new_player_elem ORDER BY (new_player_elem ->> 'order')::INT) FROM new_player_list WHERE list_type = 'inplay'), '[]'::jsonb),
                   'reserve_entities', COALESCE((SELECT JSONB_AGG(new_player_elem ORDER BY (new_player_elem ->> 'order')::INT) FROM new_player_list WHERE list_type = 'reserve'), '[]'::jsonb)
           )
    INTO v_new_team_array, v_new_team_json;

    ------------------------------------------------------------------------------

    IF (v_team_gameset_id <> v_gameset_id) THEN
        -- If the team is being transferred to a new gameset, we need to close off the previous record
        UPDATE gameplay.user_team_detail
        SET to_gameset_id = v_gameset_id-1,
            to_gameday_id = (SELECT MAX(gameday_id) FROM game_management.gameday WHERE gameset_id = v_gameset_id-1)
        WHERE season_id = v_season_id
          AND user_id = v_user_id
          AND partition_id = v_partition_id
          AND team_no = v_team_no
          AND to_gameset_id IS NULL
          AND to_gameday_id IS NULL;

    ELSE






    END IF;

/*
    IF NOT EXISTS (SELECT 1
                   FROM gameplay.user_team_detail utd
                   WHERE utd.season_id = v_season_id
                     AND utd.user_id = v_user_id
                     AND utd.team_no = v_team_no
                     AND utd.gameset_id = v_gameset_id) THEN

        SELECT f.fixture_id, f.gameday_id
        INTO v_fixture_id_prev, v_gameday_id_prev
        FROM game_management.fixture f
        WHERE f.season_id = v_season_id
          AND f.gameset_id = (v_gameset_id - 1);

        -- Close off the previous team record
        UPDATE gameplay.user_team_detail
        SET to_gameset_id = v_gameset_id - 1,
            to_gameday_id = v_gameday_id_prev,
            to_fixture_id = v_fixture_id_prev
        WHERE season_id = v_season_id
          AND user_id = v_user_id
          AND team_no = v_team_no
          AND (v_gameset_id - 1) BETWEEN from_gameset_id AND to_gameset_id;

        v_team_json := p_team_json;

        -- Correctly build the new team players list including reserve entities
        SELECT ARRAY_AGG(player_id)
        INTO v_team_players
        FROM (SELECT UNNEST(v_team_players_prev) AS player_id
              EXCEPT
              SELECT UNNEST(v_entities_out)) AS current_players
        UNION ALL
        SELECT UNNEST(v_entities_in);

        SELECT ARRAY_LENGTH(v_entities_in, 1) INTO v_total_transfer_made;

        v_total_transfer_left := v_total_transfer_allowed - v_total_transfer_made;


        -- Insert new team detail record for the current gameset
        INSERT INTO gameplay.user_team_detail
        (season_id,
         user_id,
         team_no,
         gameset_id,
         gameday_id,
         from_gameset_id,
         from_gameday_id,
         to_gameset_id,
         to_gameday_id,
         team_valuation,
         remaining_budget,
         team_players,
         captain_player_id,
         vice_captain_player_id,
         team_json,
         substitution_allowed,
         substitution_made,
         substitution_left,
         transfers_allowed,
         transfers_made,
         transfers_left,
         booster_id,
         booster_player_id,
         booster_team_players,
         partition_id,
         created_date,
         updated_date)
        SELECT v_season_id,
               v_user_id,
               v_team_no,
               v_gameset_id,
               v_gameday_id,
               v_gameset_id,
               v_gameday_id,
               v_to_gameset_id,
               v_to_gameday_id,
               v_team_valuation,
               v_remaining_budget,
               v_team_players,
               v_captain_id,
               v_vice_captain_id,
               v_team_json,
               NULL,
               NULL,
               NULL,
               v_total_transfer_allowed,
               v_total_transfer_made,
               v_total_transfer_left,
               v_booster_id,
               v_booster_player_id,
               NULL,
               v_partition_id,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP;

        -- Insert transfer log
        INSERT INTO gameplay.user_team_booster_transfer_detail
        (season_id,
         transfer_id,
         user_id,
         team_no,
         gameset_id,
         gameday_id,
         fixture_id,
         booster_id,
         original_team_players,
         players_out,
         players_in,
         new_team_players,
         transfers_made,
         transfer_json,
         created_date,
         updated_date)
        SELECT v_season_id,
               NEXTVAL('gameplay.transfer_id_seq'),
               v_user_id,
               v_team_no,
               v_gameset_id,
               v_gameday_id,
               v_match_id,
               v_booster_id,
               v_team_players_prev,
               v_entities_out,
               v_entities_in,
               v_team_players,
               1,
               v_team_json,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP;
        p_ret_type := 1;
    END IF;
  */
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'gameplay.transfer_team',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_team_json
             );
END;
$$;

CREATE OR REPLACE FUNCTION gameplay.get_user_teams(p_user_id NUMERIC, p_season_id NUMERIC) RETURNS jsonb
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_ret_json  JSONB;
    v_max_teams INT;
BEGIN
    -- 1. Fetch configuration for max teams allowed per user for the season
    -- A fallback value is used if no configuration is found.
    SELECT COALESCE(
                   (SELECT max_user_teams
                    FROM engine_config.application_user_team_configuration
                    WHERE season_id = p_season_id
                    LIMIT 1),
                   1 -- Default fallback value
           )
    INTO v_max_teams;

    -- 2. Use Common Table Expressions (CTEs) to build the JSON structure
    WITH latest_teams AS (
        -- This CTE finds the most recent 'user_team_detail' record for each of the user's teams
        -- based on the latest gameset_id. It also fetches the team_name.
        SELECT utd.*,
               ut.team_name,
               ROW_NUMBER() OVER (PARTITION BY utd.user_id, utd.team_no ORDER BY utd.gameset_id DESC, utd.updated_date DESC) AS rn
        FROM gameplay.user_team_detail utd
                 JOIN
             gameplay.user_teams ut ON utd.user_id = ut.user_id AND utd.team_no = ut.team_no AND utd.season_id = ut.season_id
        WHERE utd.user_id = p_user_id
          AND utd.season_id = p_season_id),
         teams_with_points AS (
             -- This CTE joins the latest team data with points and rank from a leaderboard.
             -- NOTE: This assumes the existence of a 'gameplay.leaderboard' table with 'points' and 'rank' columns.
             -- A LEFT JOIN is used so teams will appear even if they have no leaderboard entry.
             SELECT lt.*,
                    0 AS points,
                    0 AS rank
             FROM latest_teams lt
             /*LEFT JOIN
                 gameplay.leaderboard lb ON lt.user_id = lb.user_id AND lt.team_no = lb.team_no AND lt.season_id = lb.season_id*/
             WHERE lt.rn = 1),
         teams_json AS (
             -- This CTE constructs the final JSON object for each individual team.
             SELECT JSONB_BUILD_OBJECT(
                            'team_id', twp.team_no,
                            'team_name', twp.team_name, -- Note: URL encoding should be handled by the application layer
                            'profanity_status', 1, -- Placeholder value, assuming 1 is a default/valid status
                            'captain_id', twp.captain_player_id,
                            'vice_captain_id', twp.vice_captain_player_id,
                            'transfers', JSONB_BUILD_OBJECT(
                                    'available', twp.transfers_allowed,
                                    'left', twp.transfers_left
                                         ),
                            'boosters', CASE
                                            WHEN twp.booster_id IS NOT NULL THEN
                                                JSONB_BUILD_ARRAY(
                                                        JSONB_BUILD_OBJECT(
                                                                'booster_id', twp.booster_id,
                                                                'player_id', twp.booster_player_id
                                                        )
                                                )
                                            ELSE '[]'::jsonb
                                END,
                            'inplay_entities', (SELECT JSONB_AGG(JSONB_BUILD_OBJECT('entity_id', value ->> 'entity_id')) FROM JSONB_ARRAY_ELEMENTS(twp.team_json -> 'inplay_entities')),
                            'reserved_entities', (SELECT JSONB_AGG(JSONB_BUILD_OBJECT('entity_id', value ->> 'entity_id')) FROM JSONB_ARRAY_ELEMENTS(twp.team_json -> 'reserve_entities')),
                            'points', twp.points,
                            'rank', twp.rank,
                            'team_budget_available', twp.remaining_budget
                    ) AS team_object,
                    twp.points
             FROM teams_with_points twp)
    -- 3. Assemble the final, top-level JSON object
    SELECT JSONB_BUILD_OBJECT(
                   'data', JSONB_BUILD_OBJECT(
                    'user_id', p_user_id,
                    'total_team_count', (SELECT COUNT(*) FROM teams_json),
                    'remaining_teams', v_max_teams - (SELECT COUNT(*) FROM teams_json),
                --   'overall_points', (SELECT COALESCE(SUM(points), 0) FROM teams_json),
                    'teams', COALESCE((SELECT JSONB_AGG(team_object) FROM teams_json), '[]'::jsonb)
                           )
           )
    INTO v_ret_json;

    RETURN v_ret_json;

EXCEPTION
    WHEN OTHERS THEN
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'gameplay.get_user_teams',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := JSONB_BUILD_OBJECT('user_id', p_user_id, 'season_id', p_season_id)
             );
        RETURN NULL;
END;
$$;