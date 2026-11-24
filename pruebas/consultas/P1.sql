-- P1 carga inicial L0 — Tobotex. Manual §12.2. Recepción esperada 2026-10-01.
-- Estado previo: cero hechos vigentes, ningún corte publicado.
-- Ejecutar con bi_reader salvo la última consulta (cur, administrador).
SELECT COUNT(*) AS despachos FROM bi.v_despacho;      -- esperado 600
SELECT COUNT(*) AS reclamos FROM bi.v_reclamo;        -- esperado 49
SELECT * FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM ctl.corte_objeto ORDER BY corte_seq, objeto;  -- ambos objetos LISTO
SELECT * FROM bi.v_corte_publicado;
SELECT * FROM bi.v_k2 ORDER BY periodo, tienda;
SELECT * FROM ctl.lote WHERE lote_id = 'L0' ORDER BY intento, fuente;

-- Tres versiones de tienda recibidas; no contar miembro desconocido como fila de fuente.
SELECT tienda, zona_comercial, vigente_desde, vigente_hasta
FROM cur.dim_tienda WHERE tienda_sk > 0 ORDER BY tienda, vigente_desde;

-- Referencia local previa (NO observado SQL): julio K1 49197.85 / K2 47914.22;
-- agosto 55318.59 / 54409.78; septiembre 47590.98 / 47179.72.
