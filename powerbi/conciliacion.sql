-- Manual §10.8. Ejecutar como bi_reader después de L2, con septiembre 2026 y todas las
-- tiendas/marcas seleccionadas en el informe. Referencia local, NO resultado observado en SQL.
-- La salida real debe exportarse a evidencias/P6 y compararse al centavo con el tablero.

SELECT * FROM bi.v_corte_publicado;

SELECT periodo, SUM(bruto_pen) AS bruto,
       SUM(devuelto_pen) AS devuelto, SUM(k2_neto_pen) AS neto
FROM bi.v_k2
WHERE periodo = '2026-09'
GROUP BY periodo;

SELECT periodo,
       SUM(numerador_devuelto) AS numerador,
       SUM(denominador_despachado) AS denominador,
       100.0 * SUM(numerador_devuelto)
           / NULLIF(SUM(denominador_despachado), 0) AS tasa_pct
FROM bi.v_k3
WHERE periodo = '2026-09'
GROUP BY periodo;

-- Referencia local del cálculo independiente tras L2 (revision_fase3/calculo_independiente_tobotex.txt):
--   Bruto 47593.98 | Devuelto 620.90 | Neto 46973.08
--   Tasa 100 × 620.90 / 47593.98 = 1.30 % redondeado
-- Estas cifras son de cálculo local previo, no evidencia de ejecución SQL ni de Power BI.
-- En tarjetas desactivar unidades automáticas K/M, mostrar 2 decimales, corte y filtros.

-- Si se carga k3_tasa_pct directamente en Power BI, dividir entre 100 antes de aplicar
-- formato porcentual: la vista expresa 1,30 para 1,30 %.
