-- Manual §5.1. Ejecutar en CADA base necesaria (sqldb-test, sqldb-tobotex, sqldb-control)
-- con una cuenta de administrador. La creación de usuarios y sus secretos se hace
-- fuera del paquete entregable; aquí sólo se versionan los permisos.
-- No conceder db_owner. No reutilizar secretos de "SQL query 7.sql".

GRANT SELECT, INSERT, DELETE ON SCHEMA::stg TO etl_loader;
GRANT EXECUTE ON SCHEMA::ctl TO etl_loader;
GRANT EXECUTE ON SCHEMA::trusted TO etl_loader;
GRANT EXECUTE ON SCHEMA::cur TO etl_loader;
GRANT SELECT ON OBJECT::ctl.lote TO etl_loader;

GRANT SELECT ON SCHEMA::bi TO bi_reader;
DENY SELECT ON SCHEMA::stg TO bi_reader;
DENY SELECT ON SCHEMA::trusted TO bi_reader;
DENY SELECT ON SCHEMA::cur TO bi_reader;
DENY SELECT ON SCHEMA::quar TO bi_reader;
DENY SELECT ON SCHEMA::ctl TO bi_reader;
GO

-- Para mínimo privilegio estricto, sustituye los GRANT EXECUTE por esquema
-- por concedEXECUTE únicamente en los procedimientos usados por la ingesta:
--   ctl.sp_iniciar_lote, ctl.sp_validar_contrato, ctl.sp_abrir_corte,
--   ctl.sp_marcar_falla, ctl.sp_simular_falla, ctl.sp_publicar_corte (si aplica),
--   trusted.sp_merge_tienda, trusted.sp_merge_despacho, trusted.sp_merge_reclamo,
--   cur.sp_preparar_hecho_despacho, cur.sp_preparar_hecho_reclamo.
-- No ejecutar este bloque sin confirmar la lista real del pipeline.
