-- P7 equivalencia A vs B. Manual §12.8.
-- Versión DBeaver: sin variable @corte, usa el literal 6 (C-20261123-06).
-- #A y #B se crean en la misma sesión; ejecutar este archivo en una sola ventana.
-- DBeaver reutiliza la conexión: limpiar tablas temporales de ejecuciones anteriores.
IF OBJECT_ID('tempdb..#A') IS NOT NULL DROP TABLE #A;
IF OBJECT_ID('tempdb..#B') IS NOT NULL DROP TABLE #B;
;WITH b AS (
    SELECT periodo, tienda, SUM(importe_pen) AS bruto
    FROM bi.fn_despacho(6) GROUP BY periodo, tienda
), r AS (
    SELECT periodo, tienda, SUM(importe_devuelto_pen) AS devuelto
    FROM bi.fn_reclamo(6) GROUP BY periodo, tienda
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
    FROM bi.fn_despacho(6)
    UNION ALL
    SELECT periodo, tienda, CAST(NULL AS decimal(18,2)), importe_devuelto_pen
    FROM bi.fn_reclamo(6)
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
