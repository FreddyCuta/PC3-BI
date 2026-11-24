-- P4 tardío L2 — Control. Manual §8.4 y §12.5.
-- Esperado C2: ene 100/0/100 | feb 120/19/101 | mar 160/8/152.
-- D04 corresponde a S1/Norte por fecha 20 feb aunque la sede luego pase a Centro.
SELECT * FROM bi.v_comparacion_cortes ORDER BY corte_seq, periodo;
SELECT * FROM bi.v_periodo_revisado ORDER BY periodo;
SELECT periodo, SUM(bruto_pen) AS bruto, SUM(devuelto_pen) AS devuelto,
       SUM(k2_neto_pen) AS neto
FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
SELECT id_reclamo, id_movimiento, fecha_reclamo, tienda, motivo, importe_devuelto_pen
FROM bi.v_reclamo ORDER BY id_reclamo;
SELECT tienda, zona_comercial, vigente_desde, vigente_hasta
FROM cur.dim_tienda WHERE tienda_sk > 0 ORDER BY tienda, vigente_desde;
