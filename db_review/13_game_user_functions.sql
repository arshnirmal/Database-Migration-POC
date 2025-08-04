CREATE OR REPLACE FUNCTION game_user.user_session(p_input jsonb, p_user_details REFCURSOR, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "device_id": 1,
  "login_platform_source": 1,
  "guid": "a5a74150-364f-4a2a-baab-e4a5d37835ea",
  "source_id": "1234567890",
  "user_name": "Shreyas(urlencode)",
  "first_name": "Shreyas(urlencode)",
  "last_name": "Shreyas(urlencode)",
  "profanity_status": 1,
  "user_properties": [
    {
      "key": "residence_country",
      "value": "IN"
    },
    {
      "key": "subscription_active",
      "value": "1"
    },
    {
      "key": "profile_pic_url",
      "value": "https://uefa.com/images/1234567890.png"
    }
  ]
}
*/
DECLARE
    v_partition_id         SMALLINT;
    v_source_id            VARCHAR(150);
    v_number_of_partitions SMALLINT := 10;
    v_user_id              NUMERIC;
BEGIN
    v_source_id := p_input ->> 'source_id';

    IF v_source_id IS NULL THEN
        p_ret_type := 2; -- Missing external_id
        RETURN;
    END IF;

    v_partition_id := ((ABS(hashtext(v_source_id)::BIGINT) % v_number_of_partitions) + 1)::SMALLINT;

    SELECT user_id
    INTO v_user_id
    FROM game_user."user"
    WHERE source_id = v_source_id
      AND partition_id = v_partition_id;

    IF v_user_id IS NULL THEN

        INSERT INTO game_user."user"
        (user_id,
         source_id,
         first_name,
         last_name,
         user_name,
         device_id,
         device_version,
         login_platform_source,
         created_date,
         updated_date,
         registered_date,
         partition_id,
         user_guid,
         opt_in,
         user_properties,
         user_preference,
         profanity_status)
        SELECT NEXTVAL('game_user.user_id_seq'),
               v_source_id,
               p_input ->> 'first_name',
               p_input ->> 'last_name',
               p_input ->> 'user_name',
               (p_input ->> 'device_id')::SMALLINT,
               p_input ->> 'device_version',
               (p_input ->> 'login_platform_source')::SMALLINT,
               NOW(),
               NOW(),
               NOW(),
               v_partition_id,
               p_input ->> 'guid',
               p_input ->> 'opt_in',
               p_input ->> 'user_properties',
               p_input ->> 'user_preference',
               (p_input ->> 'profanity_status')::SMALLINT;
    END IF;

    OPEN p_user_details FOR
        SELECT u.user_id,
               u.source_id,
               u.first_name,
               u.last_name,
               u.user_name,
               u.user_preference,
               u.device_id,
               u.device_version,
               u.login_platform_source,
               u.created_date,
               u.updated_date,
               u.registered_date,
               u.partition_id,
               u.user_guid AS guid,
               u.opt_in,
               u.user_properties,
               u.profanity_status
        FROM game_user."user" u
        WHERE u.source_id = v_source_id
          AND u.partition_id = v_partition_id;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'game_user.user_session',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$;

CREATE OR REPLACE FUNCTION game_user.upd_user_preference(p_input jsonb, OUT p_ret_type INTEGER) RETURNS INTEGER
    LANGUAGE plpgsql
AS
$$
/*
{
  "user_id": 2,
  "preferences": [
    {
      "preference": "team_1",
      "value": 1
    },
    {
      "preference": "team_2",
      "value": 2
    },
    {
      "preference": "player_1",
      "value": 2
    },
    {
      "preference": "player_2",
      "value": 6
    },
    {
      "preference": "tnc",
      "value": 1
    }
  ]
}
*/
DECLARE
    v_user_id NUMERIC;
BEGIN
    v_user_id := (p_input ->> 'user_id')::NUMERIC;

    UPDATE game_user."user"
    SET user_preference = p_input -> 'preferences'
    WHERE user_id = v_user_id;

    p_ret_type := 1;
EXCEPTION
    WHEN OTHERS THEN
        p_ret_type := -1;
        CALL log.log_error(
                p_error_type := 2,
                p_function_name := 'game_user.upd_user_preference',
                p_error_message := SQLERRM,
                p_error_code := SQLSTATE,
                p_error_data := p_input
             );
END;
$$; 