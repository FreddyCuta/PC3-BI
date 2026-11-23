CREATE OR ALTER VIEW bi.v_k1 AS
  SELECT periodo, tienda, SUM(importe_pen) AS k1_bruto_pen, COUNT(*) AS movimientos
  FROM bi.v_despacho GROUP BY periodo, tienda;
GO
CREATE OR ALTER VIEW bi.v_k2 AS
  WITH b AS (SELECT periodo, tienda, SUM(importe_pen) AS bruto FROM bi.v_despacho GROUP BY periodo, tienda),
       r AS (SELECT periodo, tienda, SUM(importe_devuelto_pen) AS devuelto FROM bi.v_reclamo GROUP BY periodo, tienda)
  SELECT COALESCE(b.periodo, r.periodo) AS periodo, COALESCE(b.tienda, r.tienda) AS tienda,
         b.bruto AS bruto_pen, ISNULL(r.devuelto, 0) AS devuelto_pen, b.bruto - ISNULL(r.devuelto, 0) AS k2_neto_pen
  FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda;
GO
CREATE OR ALTER VIEW bi.v_k3 AS
  WITH b AS (SELECT periodo, tienda, marca_codigo, SUM(importe_pen) AS despachado FROM bi.v_despacho GROUP BY periodo, tienda, marca_codigo),
       r AS (SELECT periodo, tienda, marca_codigo, SUM(importe_devuelto_pen) AS devuelto FROM bi.v_reclamo GROUP BY periodo, tienda, marca_codigo)
  SELECT COALESCE(b.periodo, r.periodo) AS periodo, COALESCE(b.tienda, r.tienda) AS tienda,
         COALESCE(b.marca_codigo, r.marca_codigo) AS marca_codigo,
         ISNULL(r.devuelto, 0) AS numerador_devuelto, b.despachado AS denominador_despachado,
         CAST(100.0 * ISNULL(r.devuelto, 0) / NULLIF(b.despachado, 0) AS DECIMAL(9, 2)) AS k3_tasa_pct
  FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda AND r.marca_codigo = b.marca_codigo;
GO
CREATE OR ALTER VIEW bi.v_k4 AS
  WITH m AS (SELECT periodo, SUM(importe_pen) AS k1 FROM bi.v_despacho GROUP BY periodo)
  SELECT periodo, k1, LAG(k1) OVER (ORDER BY periodo) AS k1_anterior,
         CAST(100.0 * (k1 - LAG(k1) OVER (ORDER BY periodo)) / NULLIF(LAG(k1) OVER (ORDER BY periodo), 0) AS DECIMAL(9, 2)) AS k4_variacion_pct
  FROM m;
GO
CREATE OR ALTER VIEW bi.v_k5 AS
  SELECT contrato, detalle, tienda, marca_codigo, MAX(periodo) AS periodo_ultimo_despacho,
         MAX(cantidad_contratada) AS contratada, SUM(cantidad_despachada) AS despachada,
         IIF(SUM(cantidad_despachada) < MAX(cantidad_contratada), SUM(cantidad_despachada), MAX(cantidad_contratada)) AS cubierta,
         IIF(SUM(cantidad_despachada) < MAX(cantidad_contratada), MAX(cantidad_contratada) - SUM(cantidad_despachada), 0) AS faltante
  FROM bi.v_despacho GROUP BY contrato, detalle, tienda, marca_codigo;
GO
CREATE OR ALTER VIEW bi.v_k6 AS
  SELECT periodo, marca_codigo, COUNT(*) AS reclamos, SUM(CAST(motivo_valido AS INT)) AS con_motivo,
         CAST(100.0 * SUM(CAST(motivo_valido AS INT)) / NULLIF(COUNT(*), 0) AS DECIMAL(9, 2)) AS k6_pct
  FROM bi.v_reclamo GROUP BY periodo, marca_codigo;
GO