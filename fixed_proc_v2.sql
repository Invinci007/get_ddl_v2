--select * from STANDARDIZED_DEV.information_schema.columns where comment is not null AND TABLE_SCHEMA != 'INFORMATION_SCHEMA';

--CREATE TABLE DATAIKU_ELT_DEV.WORK_SPACE.GET_DDL_TABLE (TABLE_NAME VARCHAR(1000),DDL_STATEMENT VARCHAR);

--SELECT GET_DDL('TABLE','DATAIKU_ELT_DEV.WORK_SPACE.GET_DDL_TABLE');

CREATE OR REPLACE PROCEDURE DATAIKU_ELT_DEV.WORK_SPACE.GET_OBJECT_DDL_JS("P_CATALOG" VARCHAR, "P_SCHEMA" VARCHAR, "P_INFO_SCHEMA" VARCHAR, "P_COLUMNS_TABLE" VARCHAR)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS $$
var errors = [];
var success_count = 0;
var tables_query = "SELECT DISTINCT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME FROM \"" + P_CATALOG + "\".\"" + P_INFO_SCHEMA + "\".\"" + P_COLUMNS_TABLE + "\" WHERE TABLE_SCHEMA = ? AND COMMENT IS NOT NULL AND TABLE_SCHEMA != 'INFORMATION_SCHEMA' OR TABLE_NAME IN (SELECT TABLE_NAME FROM \"" + P_CATALOG + "\".\"" + P_INFO_SCHEMA + "\".\"TABLES\" where comment is not null and comment <> '' and table_schema <> 'INFORMATION_SCHEMA')";

var tables_stmt = snowflake.createStatement({sqlText: tables_query, binds:[P_SCHEMA]});
var rs_tables = tables_stmt.execute();

while (rs_tables.next()) {
    var table_catalog_val = rs_tables.getColumnValue('TABLE_CATALOG');
    var table_schema_val = rs_tables.getColumnValue('TABLE_SCHEMA');
    var table_name_val = rs_tables.getColumnValue('TABLE_NAME');
    var table_type_val = 'TABLE';

    var object_name_str = table_catalog_val + "." + table_schema_val + "." + table_name_val;

    try {
        var get_ddl_sql = "INSERT INTO DATAIKU_ELT_DEV.WORK_SPACE.GET_DDL_TABLE (TABLE_NAME, DDL_STATEMENT) SELECT ?, GET_DDL(?, ?) AS DDL_STATEMENT;";
        var get_ddl_stmt = snowflake.createStatement({sqlText: get_ddl_sql, binds:[object_name_str, table_type_val, object_name_str]});
        get_ddl_stmt.execute();
        success_count++;
    } catch (err) {
        errors.push({
            "object_name": object_name_str,
            "object_type": table_type_val,
            "error_message": "Error retrieving DDL: " + err.message
        });
    }
}

return {
    "tables_successfully_processed": success_count,
    "errors": errors
};
$$;
