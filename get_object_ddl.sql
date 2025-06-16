CREATE OR REPLACE PROCEDURE get_object_ddl(
    p_schema STRING,
    p_catalog STRING
)
RETURNS TABLE (object_name STRING, object_type STRING, ddl STRING)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    cur CURSOR FOR
        SELECT table_catalog || '.' || table_schema || '.' || table_name AS full_name,
               table_type AS object_type
        FROM INFORMATION_SCHEMA.TABLES
        WHERE table_schema = :p_schema
          AND table_catalog = :p_catalog
          AND table_type IN ('TABLE', 'VIEW')
        UNION ALL
        SELECT routine_catalog || '.' || routine_schema || '.' || routine_name AS full_name,
               routine_type AS object_type
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE routine_schema = :p_schema
          AND routine_catalog = :p_catalog
          AND routine_type IN ('FUNCTION', 'PROCEDURE');
    err_msg STRING; -- Variable to hold error message

BEGIN
    CREATE OR REPLACE TEMPORARY TABLE temp_defs (
        object_name STRING,
        object_type STRING,
        ddl STRING
    );

    FOR rec IN cur DO
        BEGIN
            EXECUTE IMMEDIATE '
                INSERT INTO temp_defs(object_name, object_type, ddl)
                SELECT ''' || rec.full_name || ''', ''' || rec.object_type || ''', GET_DDL(''' || rec.object_type || ''', ''' || rec.full_name || ''')
            ';
        EXCEPTION
            WHEN OTHER THEN
                err_msg := 'Failed to get DDL: ' || SQLERRM;
                -- Escape single quotes, backslashes, newlines, and carriage returns
                err_msg := REPLACE(REPLACE(err_msg, '''', ''''''), '\\', '\\\\');
                err_msg := REPLACE(err_msg, CHR(10), ' '); -- Replace newline with a space
                err_msg := REPLACE(err_msg, CHR(13), ' '); -- Replace carriage return with a space
                EXECUTE IMMEDIATE '
                    INSERT INTO temp_defs(object_name, object_type, ddl)
                    VALUES (''' || rec.full_name || ''', ''' || rec.object_type || ''', ''' || err_msg || ''')
                ';
        END;
    END FOR;

    RETURN TABLE (
        SELECT * FROM temp_defs
    );
END;
$$;
