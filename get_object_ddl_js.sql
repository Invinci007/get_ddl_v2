CREATE OR REPLACE PROCEDURE get_object_ddl_js(
    P_CATALOG STRING,
    P_SCHEMA STRING
)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
// Main JavaScript code block
// Input parameters are P_CATALOG and P_SCHEMA

var results = []; // Array to store the results

// Query for Tables and Views
var tables_query = "SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE FROM \"" + P_CATALOG + "\".\"INFORMATION_SCHEMA\".\"TABLES\" WHERE TABLE_SCHEMA = ? AND TABLE_TYPE IN ('TABLE', 'VIEW')";
var tables_stmt = snowflake.createStatement({sqlText: tables_query, binds:[P_SCHEMA]});
var rs_tables = tables_stmt.execute();

while (rs_tables.next()) {
    var table_catalog_val = rs_tables.getColumnValue('TABLE_CATALOG');
    var table_schema_val = rs_tables.getColumnValue('TABLE_SCHEMA');
    var table_name_val = rs_tables.getColumnValue('TABLE_NAME');
    var table_type_val = rs_tables.getColumnValue('TABLE_TYPE');

    var object_name_str = table_catalog_val + "." + table_schema_val + "." + table_name_val;

    try {
        var get_ddl_sql = "SELECT GET_DDL(?, ?) AS DDL_VALUE;";
        var get_ddl_stmt = snowflake.createStatement({sqlText: get_ddl_sql, binds:[table_type_val, object_name_str]});
        var rs_ddl = get_ddl_stmt.execute();
        rs_ddl.next();
        var ddl_value = rs_ddl.getColumnValue('DDL_VALUE');
        results.push({
            "object_name": object_name_str,
            "object_type": table_type_val,
            "ddl": ddl_value
        });
    } catch (err) {
        results.push({
            "object_name": object_name_str,
            "object_type": table_type_val,
            "ddl": "Error retrieving DDL: " + err.message
        });
    }
}

return results; // Return the array of results
$$;
