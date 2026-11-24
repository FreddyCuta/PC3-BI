-- P7 consulta A: agregación separada. Manual §12.8.
-- Versión DBeaver: sin variable @corte, usa el literal 6 (C-20261123-06).
-- Ejecutar el archivo completo; STATISTICS IO/TIME salen en la pestaña Output/Messages.
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
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
FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda
ORDER BY periodo, tienda;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
