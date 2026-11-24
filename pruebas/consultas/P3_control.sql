-- P3 reenvío L1 — Control. Manual §12.4.
-- Exportar antes/después: corte publicado, hechos vigentes y KPIs.
-- Esperado: intento +1, SIN_CAMBIOS, mismo corte_id/corte_seq, sin otro corte publicado.
SELECT * FROM bi.v_corte_publicado;
SELECT id_movimiento, version, importe_pen FROM bi.v_despacho ORDER BY id_movimiento;
SELECT id_reclamo, id_movimiento, importe_devuelto_pen FROM bi.v_reclamo ORDER BY id_reclamo;
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
SELECT lote_id, intento, fuente, estado, filas_leadas, filas_ins, filas_upd,
       filas_omit, filas_rech, corte_seq
FROM ctl.lote WHERE lote_id = 'L1' ORDER BY intento, fuente;
SELECT corte_seq, corte_id, intento, estado FROM ctl.corte ORDER BY corte_seq;
