-- P7 permisos — Tobotex. Manual §5.1/§12.8. Ejecutar como administrador.
-- Comprobar que existen ambos usuarios contenidos y sus permisos explícitos.
SELECT name, type_desc, authentication_type_desc
FROM sys.database_principals
WHERE name IN ('etl_loader', 'bi_reader')
ORDER BY name;

SELECT dp.name AS usuario, p.permission_name, p.state_desc,
       s.name AS esquema_o_objeto
FROM sys.database_permissions p
JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
LEFT JOIN sys.schemas s ON p.major_id = s.schema_id AND p.class_desc = 'SCHEMA'
WHERE dp.name IN ('etl_loader', 'bi_reader')
ORDER BY dp.name, s.name, p.permission_name;

-- Prueba de lector: bi_reader debe ver bi.* y NO poder leer stg/trusted/cur/quar/ctl.
-- Ejecutar cada SELECT por separado con la cuenta bi_reader y conservar el error de denegación.
-- SELECT COUNT(*) FROM bi.v_despacho;              -- permitido
-- SELECT COUNT(*) FROM stg.despacho;               -- denegado
-- SELECT COUNT(*) FROM trusted.despacho;           -- denegado
-- SELECT COUNT(*) FROM cur.dim_tienda;             -- denegado
-- SELECT COUNT(*) FROM quar.rechazo;               -- denegado
-- SELECT COUNT(*) FROM ctl.lote;                   -- denegado
