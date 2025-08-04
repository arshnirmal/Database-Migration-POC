CREATE OR REPLACE PROCEDURE log.log_error(
    p_error_type INTEGER,
    p_function_name CHARACTER VARYING,
    p_error_message TEXT,
    p_error_code TEXT,
    p_error_data jsonb
)
    LANGUAGE plpgsql
AS
$$
DECLARE
BEGIN
    IF p_error_type = 1 THEN
        INSERT INTO log.engine_error_log (function_name, error_message, error_code, error_data)
        VALUES (p_function_name, p_error_message, p_error_code, p_error_data);
    ELSIF p_error_type = 2 THEN
        INSERT INTO log.gameplay_error_log (function_name, error_message, error_code, error_data)
        VALUES (p_function_name, p_error_message, p_error_code, p_error_data);
    END IF;
END;
$$; 