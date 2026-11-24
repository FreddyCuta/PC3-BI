-- P6 conciliación independiente = SQL = tablero. Manual §12.7 y §10.8.
-- Fijar septiembre 2026 posterior a L2, todas las tiendas/marcas y corte publicado.
-- Ejecutar con bi_reader. Referencia local previa, NO observado SQL:
--   Bruto 47593.98 | Devuelto 620.90 | Neto 46973.08 | Tasa 1.30 % redondeado.
SELECT * FROM bi.v_corte_publicado;

SELECT periodo, SUM(bruto_pen) AS bruto,
       SUM(devuelto_pen) AS devuelto, SUM(k2_neto_pen) AS neto
FROM bi.v_k2
WHERE periodo = '2026-09'
GROUP BY periodo;

SELECT periodo,
       SUM(numerador_devuelto) AS numerador,
       SUM(denominador_despachado) AS denominador,
       100.0 * SUM(numerador_devuelto) / NULLIF(SUM(denominador_despachado), 0) AS tasa_pct
FROM bi.v_k3
WHERE periodo = '2026-09'
GROUP BY periodo;

-- Subconjunto trazable (~20 filas) para inspección manual: NO comparar contra el total.
-- Recalcular aparte y contrastar con el cálculo local fila por fila.
SELECT TOP (20) d.id_movimiento, d.version, d.fecha_salida, d.tienda, d.marca_codigo,
       d.contrato, d.detalle, d.importe_pen
FROM bi.v_despacho d
WHERE d.periodo = '2026-09'
ORDER BY d.id_movimiento, d.version;

SELECT r.id_reclamo, r.id_movimiento, r.fecha_reclamo, r.tienda,
       r.motivo, r.importe_devuelto_pen
FROM bi.v_reclamo r
WHERE r.periodo = '2026-09'
  AND r.id_movimiento IN (
      SELECT TOP (20) d.id_movimiento FROM bi.v_despacho d
      WHERE d.periodo = '2026-09' ORDER BY d.id_movimiento, d.version
  )
ORDER BY r.id_reclamo;

-- python datos/generador/calculo_independiente_tobotex.py  (desde carga/Carga)
-- Salida previa: revision_fase3/calculo_independiente_tobotex.txt
