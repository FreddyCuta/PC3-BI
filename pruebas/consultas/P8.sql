-- P8 interrupción y recuperación L3 — Tobotex. Manual §12.9.
-- Parte del corte posterior a L2. Bloque A: tras fallo con simular_falla=tras_despacho.
-- Bloque B: tras reejecución con simular_falla=no. Conservar AMBOS y el RunId.
-- Esperado tras recuperación: octubre bruto 14104.14 / devuelto 140.81 / neto 13963.33;
-- total vigente 655 despachos y 55 reclamos; un único corte nuevo respecto de L2.
-- El intento fallido permanece en bitácora; un candidato descartado puede consumir secuencia.

-- A: estado de fallo
SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc
FROM ctl.corte ORDER BY corte_seq;
SELECT corte_seq, objeto, estado FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT * FROM bi.v_corte_publicado;
SELECT lote_id, intento, fuente, estado, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech
FROM ctl.lote WHERE lote_id = 'L3' ORDER BY intento, fuente;
SELECT * FROM bi.v_k2 WHERE periodo IN ('2026-09', '2026-10') ORDER BY periodo, tienda;

-- B: estado tras recuperación (mismas consultas)
SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc
FROM ctl.corte ORDER BY corte_seq;
SELECT corte_seq, objeto, estado FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT * FROM bi.v_corte_publicado;
SELECT COUNT(*) AS despachos FROM bi.v_despacho;   -- esperado 655
SELECT COUNT(*) AS reclamos FROM bi.v_reclamo;     -- esperado 55
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 WHERE periodo = '2026-10' GROUP BY periodo;
