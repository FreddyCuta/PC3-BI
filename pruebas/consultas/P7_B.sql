-- P7 consulta B: agregación condicional. Manual §12.8.
-- Conserva bruto NULL cuando sólo existen devoluciones. @corte = 1 es placeholder.
DECLARE @corte int = 1;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
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
FROM eventos
GROUP BY periodo, tienda
ORDER BY periodo, tienda;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
