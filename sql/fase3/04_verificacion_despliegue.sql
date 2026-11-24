-- Manual §4.6 y §12.1. Consultas de lectura posteriores al despliegue.
-- Antes de L0 es normal que las vistas estén vacías y el puntero valga 0.
-- Después de L0 debe existir un corte PUBLICADO. C0 no equivale a corte_seq=0.

SELECT DB_NAME() AS base_actual, USER_NAME() AS usuario_actual;

SELECT SCHEMA_NAME(schema_id) AS esquema, name
FROM sys.procedures
ORDER BY 1, 2;

SELECT * FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM ctl.corte_vigente;
SELECT * FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT COUNT(*) AS fechas FROM cur.dim_fecha;
SELECT TOP (5) * FROM bi.v_despacho;
SELECT TOP (5) * FROM bi.v_reclamo;

-- Conciliación de fuentes clasificadas (manual §12.1).
SELECT lote_id, intento, fuente, estado,
       filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech,
       filas_leadas - (filas_ins + filas_upd + filas_omit + filas_rech) AS diferencia
FROM ctl.lote
WHERE fuente <> 'LOTE' AND filas_leadas IS NOT NULL
ORDER BY lote_id, intento, fuente;

-- C1 único de dimensiones BI (manual §9.1): ambas deben devolver cero filas.
SELECT marca_codigo, COUNT(*) AS filas
FROM bi.v_dim_marca_bi GROUP BY marca_codigo HAVING COUNT(*) > 1;
SELECT tienda, COUNT(*) AS filas
FROM bi.v_dim_tienda_bi GROUP BY tienda HAVING COUNT(*) > 1;
