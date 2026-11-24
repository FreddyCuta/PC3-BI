-- P7 consulta A: agregación separada. Manual §12.8.
-- Versión derivada de P7_A.sql con @corte = 6 (C-20261123-06), 23/11/2026.
-- Calentar una vez, ejecutar 3 veces alternadas con B, registrar lecturas lógicas,
-- CPU, tiempo y filas. No declarar "B más rápida" sin resultados medidos.
DECLARE @corte int = 6;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
;WITH b AS (
    SELECT periodo, tienda, SUM(importe_pen) AS bruto
    FROM bi.fn_despacho(@corte) GROUP BY periodo, tienda
), r AS (
    SELECT periodo, tienda, SUM(importe_devuelto_pen) AS devuelto
    FROM bi.fn_reclamo(@corte) GROUP BY periodo, tienda
)
SELECT COALESCE(b.periodo, r.periodo) AS periodo,
       COALESCE(b.tienda, r.tienda) AS tienda,
       b.bruto, COALESCE(r.devuelto, 0) AS devuelto,
       b.bruto - COALESCE(r.devuelto, 0) AS neto
FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda
ORDER BY periodo, tienda;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
