-- 1. Verificar que existan ambos usuarios contenidos
SELECT name, type_desc, authentication_type_desc
FROM sys.database_principals
WHERE name IN ('etl_loader', 'bi_reader')
ORDER BY name;

-- 2. Verificar permisos explícitos (GRANT / DENY) asignados a cada uno
SELECT dp.name AS usuario,
       p.permission_name,
       p.state_desc,
       s.name AS esquema_o_objeto
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
LEFT JOIN sys.schemas s ON p.major_id = s.schema_id AND p.class_desc = 'SCHEMA'
WHERE dp.name IN ('etl_loader', 'bi_reader')
ORDER BY dp.name, s.name, p.permission_name;