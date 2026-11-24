-- P8 interrupción y recuperación L3 — Control. Manual §8.4 y §12.9.
-- Durante la falla debe seguir visible marzo 160/8/152. NUNCA publicar 180/8/172.
-- Tras recuperación esperado C3: ene 100/0/100 | feb 120/19/101 | mar 180/13/167.
SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc FROM ctl.corte ORDER BY corte_seq;
SELECT corte_seq, objeto, estado FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT * FROM bi.v_corte_publicado;
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
SELECT lote_id, intento, fuente, estado, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech
FROM ctl.lote WHERE lote_id = 'L3' ORDER BY intento, fuente;
