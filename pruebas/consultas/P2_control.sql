-- P2 incremental L1 — Control. Manual §8.3 y §8.4.
-- UMBRAL 0.2500: 4 ventas, 1 inválida => 25 % NO bloquea con comparación estricta >.
-- Si el docente exige 20 % universal, registrar incompatibilidad y NO declarar aprobada.
-- Esperado C1: ene 100/0/100 | feb 120/15/105 | mar 160/8/152.
-- Clasificación esperada: 1 ins, 1 upd, 1 omit, 1 rech.
SELECT lote_id, intento, fuente, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech, estado
FROM ctl.lote WHERE lote_id = 'L1' ORDER BY intento, fuente;
SELECT fuente, lote_id, intento, clave, control, motivo
FROM quar.rechazo WHERE lote_id = 'L1';
SELECT * FROM bi.v_corte_publicado;
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
