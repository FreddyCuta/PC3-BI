-- P7 equivalencia A vs B. Manual §12.8.
-- Versión derivada de P7_EXCEPT.sql con @corte = 6 (C-20261123-06), 23/11/2026.
-- Materializar cada SELECT sin ORDER BY en #A y #B en la MISMA sesión.
-- DBeaver reutiliza la conexión: limpiar tablas temporales de ejecuciones anteriores.
IF OBJECT_ID('tempdb..#A') IS NOT NULL DROP TABLE #A;
IF OBJECT_ID('tempdb..#B') IS NOT NULL DROP TABLE #B;
DECLARE @corte int = 6;
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
INTO #A
FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda;

;WITH eventos AS (
    SELECT periodo, tienda, importe_pen AS bruto,
           CAST(NULL AS decimal(18,2)) AS devuelto
    FROM bi.fn_despacho(@corte)
    UNION ALL
    SELECT periodo, tienda, CAST(NULL AS decimal(18,2)), importe_devuelto_pen
    FROM bi.fn_reclamo(@corte)
)
SELECT periodo, tienda, SUM(bruto) AS bruto,
       COALESCE(SUM(devuelto), 0) AS devuelto,
       SUM(bruto) - COALESCE(SUM(devuelto), 0) AS neto
INTO #B
FROM eventos
GROUP BY periodo, tienda;

SELECT * FROM #A EXCEPT SELECT * FROM #B;  -- esperado: 0 filas
SELECT * FROM #B EXCEPT SELECT * FROM #A;  -- esperado: 0 filas
SELECT COUNT(*) AS filas_a FROM #A;
SELECT COUNT(*) AS filas_b FROM #B;

-- Verificar unicidad de período/tienda en cada tabla (EXCEPT por sí solo no comprueba multiplicidad).
SELECT periodo, tienda, COUNT(*) AS n FROM #A GROUP BY periodo, tienda HAVING COUNT(*) > 1;
SELECT periodo, tienda, COUNT(*) AS n FROM #B GROUP BY periodo, tienda HAVING COUNT(*) > 1;
