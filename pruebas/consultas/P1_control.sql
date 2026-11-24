-- P1 carga inicial L0 — Control (Anexo E adaptado). Manual §8.4 y §12.2.
-- Base sqldb-control, datos adaptados (control_adaptado), umbral C8 0.2500.
-- Esperado C0: ene 100/0/100 | feb 120/15/105 | mar 120/8/112.
SELECT * FROM bi.v_corte_publicado;
SELECT * FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT COUNT(*) AS despachos FROM bi.v_despacho;  -- esperado 4
SELECT COUNT(*) AS reclamos FROM bi.v_reclamo;    -- esperado 3
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
SELECT lote_id, intento, fuente, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech, estado
FROM ctl.lote WHERE lote_id = 'L0' ORDER BY intento, fuente;

-- No usar K5/K6 de esta adaptación para análisis de negocio (cantidades artificiales).
