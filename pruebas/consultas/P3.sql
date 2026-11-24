-- P3 reenvío L1 — Tobotex. Manual §12.4.
-- ANTES de reenviar: exportar el bloque A a CSV. DESPUÉS: exportar el bloque B y comparar.
-- Comparar claves y versiones vigentes, no sólo SUM. Esperado: intento +1, SIN_CAMBIOS,
-- mismo corte_id/corte_seq, sin otro corte publicado, 43 filas omitidas y 2 rechazadas
-- (verificar el resultado real antes de escribirlo como observado).

-- A: estado previo
SELECT * FROM bi.v_corte_publicado;
SELECT id_movimiento, version, importe_pen FROM bi.v_despacho ORDER BY id_movimiento;
SELECT id_reclamo, id_movimiento, importe_devuelto_pen FROM bi.v_reclamo ORDER BY id_reclamo;
SELECT periodo, tienda, SUM(importe_pen) AS bruto
FROM bi.v_despacho GROUP BY periodo, tienda ORDER BY periodo, tienda;

-- B: estado posterior al reenvío (mismas consultas + bitácora del intento)
SELECT lote_id, intento, fuente, estado, filas_leadas, filas_ins, filas_upd,
       filas_omit, filas_rech, corte_seq
FROM ctl.lote WHERE lote_id = 'L1' ORDER BY intento, fuente;
SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc
FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM bi.v_corte_publicado;
