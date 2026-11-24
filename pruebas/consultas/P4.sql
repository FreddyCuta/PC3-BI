-- P4 tardío L2 — Tobotex. Manual §12.5. Recepción esperada 2026-10-20.
-- Ejecutar con bi_reader salvo cur.* (administrador).
-- Esperado: 1 actualización de despacho, 3 reclamos nuevos, septiembre neto 46973.08,
-- julio/agosto sin cambios, dos versiones de LEO y período septiembre marcado revisado.
SELECT * FROM bi.v_comparacion_cortes ORDER BY corte_seq, periodo;
SELECT * FROM bi.v_periodo_revisado ORDER BY periodo;
SELECT * FROM bi.v_k2 WHERE periodo IN ('2026-07', '2026-08', '2026-09') ORDER BY periodo, tienda;

SELECT tienda, zona_comercial, vigente_desde, vigente_hasta
FROM cur.dim_tienda WHERE tienda = 'LEO' ORDER BY vigente_desde;

SELECT * FROM cur.fact_despacho WHERE id_movimiento = 'M000413' ORDER BY corte_desde;
SELECT * FROM bi.v_despacho WHERE id_movimiento = 'M000413';

-- Reclamo tardío R000051 (fecha 2026-09-22 -> zona de Gamarra Centro por vigencia).
SELECT * FROM bi.v_reclamo WHERE id_reclamo = 'R000051';

SELECT lote_id, intento, fuente, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech, estado
FROM ctl.lote WHERE lote_id = 'L2' ORDER BY intento, fuente;
