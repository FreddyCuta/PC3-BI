SELECT SCHEMA_NAME(schema_id) AS esquema, name
FROM sys.procedures
ORDER BY 1, 2;