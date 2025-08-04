CREATE OR REPLACE FUNCTION league.upd_league_config(p_input jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "league_type_id": 1,
  "filters": {
    "enabled": true,
    "filter_types": [
      {
        "key": "overall",
        "label": "Overall",
        "value": true
      },
      {
        "key": "gameset_selection",
        "label": "A Gameset Selection",
        "value": true
      },
      {
        "key": "gameset",
        "label": "A Gameset",
        "value": true
      }
    ]
  },
  "preset_id": 2,
  "pagination": {
    "enabled": true,
    "side_setup": "Client",
    "max_records": 10000,
    "records_first_page": 50,
    "subsequent_page_size": 50
  },
  "leaderboard": {
    "columns": [
      {
        "key": "rank",
        "label": "Rank",
        "value": true
      },
      {
        "key": "username",
        "label": "Username",
        "value": false
      },
      {
        "key": "team_name",
        "label": "Team Name",
        "value": true
      },
      {
        "key": "points",
        "label": "Points",
        "value": true
      },
      {
        "key": "trend",
        "label": "Trend",
        "value": false
      },
      {
        "key": "view_opponent_team",
        "label": "View Opponent Team",
        "value": true
      }
    ],
    "is_live_leaderboard": true
  },
  "preset_name": "Admin Created Public League",
  "league_setup": {
    "auto_join_league": {
      "value": false,
      "is_disabled": false
    },
    "auto_spawn_leagues": {
      "value": false,
      "is_disabled": false
    },
    "league_scoring_type": 1
  },
  "league_assets": [
    {
      "key": "icon",
      "label": "Icon",
      "value": true
    },
    {
      "key": "banner",
      "label": "Banner",
      "value": true
    }
  ],
  "league_config": {
    "team_cap_per_user": {
      "value": false,
      "is_disabled": true
    },
    "game_sets_selectable": {
      "value": false,
      "is_disabled": true
    },
    "max_league_entry_cap": {
      "value": true,
      "is_disabled": true
    },
    "users_able_to_create": {
      "value": false,
      "is_disabled": true
    },
    "users_set_max_entry_cap": {
      "value": false,
      "is_disabled": true
    }
  },
  "league_visibility": {
    "join_visibility": "Public",
    "leaderboard_visibility": "Public"
  },
  "league_admin_actions": [
    {
      "key": "allow_league_admin_change",
      "label": "Allow League Admin Change",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "change_league_name",
      "label": "Change League Name",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "delete_league",
      "label": "Delete League",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "remove_member",
      "label": "Remove Member",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "remove_member_&_block",
      "label": "Remove Member & Block",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "lock_league",
      "label": "Lock League",
      "value": false,
      "is_disabled": true
    },
    {
      "key": "can_increase_member_count",
      "label": "Can Increase Member Count",
      "value": false,
      "is_disabled": true
    }
  ],
  "league_member_actions": [
    {
      "key": "report_league",
      "label": "Report League",
      "value": false
    },
    {
      "key": "leave_league",
      "label": "Leave League",
      "value": false
    },
    {
      "key": "share_league",
      "label": "Share League",
      "value": true
    }
  ]
}
*/
DECLARE
    v_league_type_id          SMALLINT;
    v_preset_id               SMALLINT;
    v_scoring_type_id         SMALLINT;
    v_auto_spawn_league       BOOLEAN;
    v_auto_join_league        BOOLEAN;
    v_leaderboard_visibility  CHARACTER VARYING;
    v_join_visibility         CHARACTER VARYING;
    v_users_able_to_create    BOOLEAN;
    v_game_sets_selectable    BOOLEAN;
    v_team_cap_per_user       BOOLEAN;
    v_max_league_entry_cap    BOOLEAN;
    v_users_set_max_entry_cap BOOLEAN;
    v_row_count               INTEGER;
BEGIN
    SELECT (p_input ->> 'league_type_id')::SMALLINT,
           (p_input ->> 'preset_id')::SMALLINT,
           (p_input -> 'league_setup' ->> 'league_scoring_type')::SMALLINT,
           (p_input -> 'league_setup' -> 'auto_spawn_leagues' ->> 'value')::BOOLEAN,
           (p_input -> 'league_setup' -> 'auto_join_league' ->> 'value')::BOOLEAN,
           (p_input -> 'league_visibility' ->> 'leaderboard_visibility')::CHARACTER VARYING,
           (p_input -> 'league_visibility' ->> 'join_visibility')::CHARACTER VARYING,
           (p_input -> 'league_config' -> 'users_able_to_create' ->> 'value')::BOOLEAN,
           (p_input -> 'league_config' -> 'game_sets_selectable' ->> 'value')::BOOLEAN,
           (p_input -> 'league_config' -> 'team_cap_per_user' ->> 'value')::BOOLEAN,
           (p_input -> 'league_config' -> 'max_league_entry_cap' ->> 'value')::BOOLEAN,
           (p_input -> 'league_config' -> 'users_set_max_entry_cap' ->> 'value')::BOOLEAN
    INTO v_league_type_id,
        v_preset_id,
        v_scoring_type_id,
        v_auto_spawn_league,
        v_auto_join_league,
        v_leaderboard_visibility,
        v_join_visibility,
        v_users_able_to_create,
        v_game_sets_selectable,
        v_team_cap_per_user,
        v_max_league_entry_cap,
        v_users_set_max_entry_cap;

    UPDATE league.league_type
    SET preset_id               = v_preset_id,
        scoring_type_id         = v_scoring_type_id,
        leaderboard_visibility  = v_leaderboard_visibility,
        join_visibility         = v_join_visibility,
        auto_spawn_league       = v_auto_spawn_league,
        auto_join_league        = v_auto_join_league,
        users_can_create_league = v_users_able_to_create,
        users_select_game_set   = v_game_sets_selectable,
        users_set_team_cap      = v_team_cap_per_user,
        unlimited_max_entry_cap = v_max_league_entry_cap,
        users_set_max_entry_cap = v_users_set_max_entry_cap,
        league_property         = p_input,
        updated_date            = CURRENT_TIMESTAMP
    WHERE league_type_id = v_league_type_id;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count = 0 THEN
        p_ret_type := 3; -- No rows updated
    ELSE
        p_ret_type := 1; -- Success
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'league.upd_league_config',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION league.get_league_type_list(p_season_id integer, OUT p_league_type_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE

BEGIN
    SELECT JSONB_AGG(b)
    INTO p_league_type_data
    FROM (SELECT league_type_id,
                 league_type_name,
                 league_property
          FROM league.league_type
          WHERE season_id = p_season_id
          ORDER BY created_date) b;

    IF p_league_type_data IS NULL THEN
        p_ret_type := 3;
    ELSE
        p_league_type_data := JSONB_BUILD_OBJECT(
                'league_type', p_league_type_data
                              );
        p_ret_type := 1;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_league_type_data := NULL;
        CALL log.log_error(
            p_error_type := 2,
            p_function_name := 'league.get_league_type_list',
            p_error_message := SQLERRM,
            p_error_code := SQLSTATE,
            p_error_data := jsonb_build_object('season_id', p_season_id)
        );
END ;
$$;

CREATE OR REPLACE FUNCTION league.get_league_preset(OUT p_preset_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE

BEGIN
    SELECT JSONB_BUILD_OBJECT(
                   'preset_data', JSONB_AGG(b)
           )
    INTO p_preset_data
    FROM (SELECT preset_id,
                 preset_name,
                 preset
          FROM league.league_preset
          ORDER BY preset_id) b;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_preset_data := NULL;
        CALL log.log_error(
            p_error_type := 2,
            p_function_name := 'league.get_league_preset',
            p_error_message := SQLERRM,
            p_error_code := SQLSTATE,
            p_error_data := NULL
        );
END ;
$$;

CREATE OR REPLACE FUNCTION league.get_scoring_type(OUT p_scoring_type_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE

BEGIN
    SELECT JSONB_AGG(b)
    INTO p_scoring_type_data
    FROM (SELECT scoring_type_id,
                 scoring_type_name
          FROM league.league_scoring_type) b;

    p_scoring_type_data := JSONB_BUILD_OBJECT(
            'scoring_type', p_scoring_type_data
                           );
    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_scoring_type_data := NULL;
        CALL log.log_error(
            p_error_type := 2,
            p_function_name := 'league.get_scoring_type',
            p_error_message := SQLERRM,
            p_error_code := SQLSTATE,
            p_error_data := NULL
        );
END ;
$$;

CREATE OR REPLACE FUNCTION league.ins_upd_league_type(p_input jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "league_type": [
    {
      "league_type_name": "starter League",
      "preset_id": 1,
      "league_type_id": 1
    },
    {
      "league_type_name": "VIP League",
      "preset_id": 1,
      "league_type_id": 1
    }
  ],
  "season_id": 1
}
*/
DECLARE
    v_season_id     SMALLINT;
    v_affected_rows INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;

    IF NOT EXISTS(SELECT 1
                  FROM engine_config.season
                  WHERE season_id = v_season_id) THEN
        p_ret_type := 31;
        RETURN;
    END IF;

    -- Check if any preset_id explicitly provided in the input list does not exist in league.league_preset
    IF EXISTS (SELECT 1
               FROM JSONB_ARRAY_ELEMENTS(p_input -> 'league_type') AS arr(item)
               WHERE (item ->> 'preset_id') IS NOT NULL
                 AND NOT EXISTS (SELECT 1
                                 FROM league.league_preset lp
                                 WHERE lp.preset_id = (item ->> 'preset_id')::INT)) THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    -- Check if any league_type_id explicitly provided (for updates) does not exist for the given season
    IF EXISTS (SELECT 1
               FROM JSONB_ARRAY_ELEMENTS(p_input -> 'league_type') AS arr(item)
               WHERE (item ->> 'league_type_id') IS NOT NULL
                 AND NOT EXISTS (SELECT 1
                                 FROM league.league_type lt
                                 WHERE lt.league_type_id = (item ->> 'league_type_id')::INT
                                   AND lt.season_id = v_season_id)) THEN
        p_ret_type := 3;
        RETURN;
    END IF;

    WITH input_data AS (SELECT COALESCE(x.league_type_id, NEXTVAL('league.league_type_league_type_id_seq')) AS league_type_id,
                               x.league_type_name,
                               x.preset_id,
                               v_season_id                                                                  AS season_id
                        FROM JSONB_TO_RECORDSET(p_input -> 'league_type')
                                 AS x("league_type_name" TEXT, "preset_id" SMALLINT, "league_type_id" SMALLINT)),
         upsert_result AS (
             INSERT INTO league.league_type (
                                             league_type_id,
                                             league_type_name,
                                             preset_id,
                                             season_id,
                                             league_property,
                                             created_date,
                                             updated_date
                 )
                 SELECT i.league_type_id,
                        i.league_type_name,
                        i.preset_id,
                        i.season_id,
                        lp.preset,
                        CURRENT_TIMESTAMP,
                        CURRENT_TIMESTAMP
                 FROM input_data i
                          JOIN league.league_preset lp
                               ON lp.preset_id = i.preset_id
                 ON CONFLICT (season_id, league_type_id)
                     DO UPDATE SET
                         league_type_name = EXCLUDED.league_type_name,
                         preset_id = EXCLUDED.preset_id,
                         league_property = EXCLUDED.league_property,
                         updated_date = CURRENT_TIMESTAMP
                 RETURNING 1),
         delete_result AS (
             DELETE FROM league.league_type
                 WHERE season_id = v_season_id
                     AND league_type_id NOT IN (SELECT id.league_type_id FROM input_data id)
                 RETURNING 1)
    SELECT COUNT(*)
    INTO v_affected_rows
    FROM (SELECT 1
          FROM upsert_result
          UNION ALL
          SELECT 1
          FROM delete_result) t;

    p_ret_type := CASE
                      WHEN v_affected_rows > 0 THEN 1
                      ELSE 101
        END;
EXCEPTION
    WHEN OTHERS
        THEN p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'league.ins_upd_league_type',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION league.create_manage_league(p_input jsonb, OUT p_ret_type integer) RETURNS integer
    LANGUAGE plpgsql
AS
$$
/*
{
  "season_id": 1,
  "is_system_league": true,
  "league_code": "xfcgvb1428",
  "platform_id": 1,
  "platform_version": "12",
  "league_type_id": 1,
  "league_name": "Budweiser League",
  "league_scoring_type_id": 2,
  "auto_spawn_league": false,
  "auto_join_league": false,
  "set_restriction": true,
  "age_restriction": true,
  "start_age": 18,
  "end_age": 100,
  "geo_ip_restriction": true,
  "entity_restriction": true,
  "league_visibility": {
    "league_leaderboard_can_be_seen_by": "Public",
    "league_can_be_joined_by": "Public"
  },
  "league_config": {
    "can_users_create_this_league": false,
    "team_cap_per_member": 1,
    "total_max_entry_cap": 0
  },
  "game_set_restriction": [0],
  "League_Admin_Manager_Actions": [""],
  "league_member_actions": ["Share League"],
  "league_assets": {
    "icon": {
      "enabled": true,
      "image_link": "https://www.icc.sports.lq/assets/asics.png",
      "redirect_url": "https://www.icc.sports.lq/assets/asics.png"
    },
    "banner": {
      "enabled": true,
      "image_link": "https://www.icc.sports.lq/assets/asics.png",
      "redirect_url": "https://www.icc.sports.lq/assets/asics.png"
    }
  },
  "opt_in_cta": true,
  "opt_in_message": "Step up your Budweiser experience with notifications when we have an event for you. Press to be won!"
}
*/
DECLARE
    v_season_id   SMALLINT;
    v_league_code CHARACTER VARYING(25);
    v_ret_type    INTEGER;
BEGIN
    v_season_id := (p_input ->> 'season_id')::SMALLINT;
    v_league_code := p_input ->> 'league_code';

    IF NOT EXISTS(SELECT 1
                  FROM league.league
                  WHERE league_code = v_league_code) THEN

        INSERT INTO league.league
        (season_id,
         league_id,
         league_type_id,
         league_name,
         league_code,
         social_id,
         user_id,
         active_gameset_ids,
         join_lock_timestamp,
         join_lock_gameset_id,
         maximum_team_count,
         teams_per_user,
         platform_id,
         platform_version,
         tag_ids,
         is_system_league,
         total_team_count,
         total_user_count,
         is_locked,
         is_deleted,
         profane_flag,
         profane_updated_date,
         banner_image_url,
         banner_url,
         partition_id,
         created_date,
         updated_date,
         input_json)
        SELECT v_season_id,
               NEXTVAL('league.league_league_id_seq'),
               (p_input ->> 'league_type_id')::SMALLINT,
               p_input ->> 'league_name',
               v_league_code,
               NULL,
               NULL,
               --  (p_input ->> 'game_set_restriction')::smallint[],
               (SELECT ARRAY_AGG(value::SMALLINT)
                FROM JSONB_ARRAY_ELEMENTS_TEXT(p_input -> 'game_set_restriction')),
               NULL,
               NULL,
               (p_input ->> 'total_max_entry_cap')::NUMERIC,
               (p_input ->> 'team_cap_per_member')::SMALLINT,
               (p_input ->> 'platform_id')::SMALLINT,
               p_input ->> 'platform_version',
               NULL,
               (p_input ->> 'is_system_league')::BOOLEAN,
               0,
               0,
               'false',
               'false',
               'error',
               NULL,
               p_input -> 'banner' ->> 'image_link',
               p_input -> 'banner' ->> 'redirect_url',
               1,
               CURRENT_TIMESTAMP,
               CURRENT_TIMESTAMP,
               p_input;

    ELSE

        UPDATE league.league
        SET league_name        = p_input ->> 'league_name',
            maximum_team_count = (p_input ->> 'total_max_entry_cap')::NUMERIC,
            input_json         = p_input
        WHERE league_code = v_league_code;

    END IF;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS
        THEN p_ret_type := COALESCE(v_ret_type, -1);
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'league.create_manage_league',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
                );
END;
$$;

CREATE OR REPLACE FUNCTION league.get_league_details(p_league_code text, OUT p_league_data jsonb, OUT p_ret_type integer) RETURNS record
    LANGUAGE plpgsql
AS
$$
DECLARE

BEGIN


	select input_json into p_league_data from league.league
	where league_code = p_league_code;


    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        p_league_data := NULL;
        CALL log.log_error(
            p_error_type := 2,
            p_function_name := 'league.get_league_details',
            p_error_message := SQLERRM,
            p_error_code := SQLSTATE,
            p_error_data := jsonb_build_object('league_code', p_league_code)
        );
END ;
$$;

CREATE OR REPLACE FUNCTION league.manage_league_partitions() RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Create a new partition for the new league_type
        EXECUTE FORMAT('CREATE TABLE IF NOT EXISTS league.league_%s PARTITION OF league.league FOR VALUES IN (%L)',
                       NEW.league_type_id,
                       NEW.league_type_id
                );
    ELSIF TG_OP = 'DELETE' THEN
        -- Drop the partition for the deleted league_type
        EXECUTE FORMAT('DROP TABLE IF EXISTS league.league_%s CASCADE', OLD.league_type_id);
    END IF;
    RETURN NULL; -- The result is ignored for AFTER triggers.
END;
$$;

CREATE OR REPLACE FUNCTION league.drop_league_partition() RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE FORMAT('DROP TABLE IF EXISTS league.league_%s CASCADE', OLD.league_type_id);
    RETURN OLD; -- Proceed with the DELETE operation
END;
$$;

CREATE TRIGGER trg_drop_league_partition
    BEFORE DELETE
    ON league.league_type
    FOR EACH ROW
EXECUTE PROCEDURE league.drop_league_partition();

CREATE OR REPLACE FUNCTION league.create_league_partition() RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE FORMAT('CREATE TABLE IF NOT EXISTS league.league_%s PARTITION OF league.league FOR VALUES IN (%L)',
                   NEW.league_type_id,
                   NEW.league_type_id
            );
    RETURN NULL; -- Result is ignored for AFTER triggers
END;
$$;

CREATE TRIGGER trg_create_league_partition
    AFTER INSERT
    ON league.league_type
    FOR EACH ROW
EXECUTE PROCEDURE league.create_league_partition(); 