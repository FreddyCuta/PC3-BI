-- P2 incremental L1 — Tobotex. Manual §12.3. Recepción esperada 2026-10-04.
-- Ejecutar con bi_reader; cur.* requiere administrador.
-- Clasificación despacho esperada: 45 = 40 ins + 2 upd + 1 omit + 2 rech.
SELECT lote_id, intento, fuente, filas_leadas, filas_ins, filas_upd,
       filas_omit, filas_rech, estado
FROM ctl.lote WHERE lote_id = 'L1' ORDER BY intento, fuente;

SELECT fuente, lote_id, intento, clave, control, motivo
FROM quar.rechazo WHERE lote_id = 'L1' ORDER BY fuente, clave;  -- 2 rechazos

SELECT COUNT(*) AS despachos_vigentes FROM bi.v_despacho;  -- esperado 640
SELECT * FROM bi.v_corte_publicado;
SELECT * FROM bi.v_k2 ORDER BY periodo, tienda;

-- La versión física puede coexistir; verificar conservación de historia del movimiento.
SELECT id_movimiento, version, fecha_salida, importe_pen
FROM cur.fact_despacho WHERE id_movimiento IN (
    SELECT id_movimiento FROM stg.despacho WHERE lote_id = 'L1'
)
ORDER BY id_movimiento, version;
