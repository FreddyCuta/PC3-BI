-- Manual §4.3. Ejecutar después de "SQL query 6.sql" y antes de preparar hechos.
-- Depende de que cur.dim_fecha exista;
-- el WHERE NOT EXISTS evita duplicar fechas si se vuelve a ejecutar.
-- Validar primero en sqldb-test. No llamar a GETDATE(): el caso usa 2026.

;WITH fechas AS (
    SELECT CONVERT(date, '20260101', 112) AS fecha
    UNION ALL
    SELECT DATEADD(day, 1, fecha)
    FROM fechas
    WHERE fecha < CONVERT(date, '20261231', 112)
)
INSERT INTO cur.dim_fecha (fecha_sk, fecha, anio, mes, periodo, nombre_mes)
SELECT YEAR(f.fecha) * 10000 + MONTH(f.fecha) * 100 + DAY(f.fecha),
       f.fecha, YEAR(f.fecha), MONTH(f.fecha), CONVERT(char(7), f.fecha, 126),
       CHOOSE(MONTH(f.fecha), 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo',
              'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre')
FROM fechas f
WHERE NOT EXISTS (SELECT 1 FROM cur.dim_fecha d WHERE d.fecha = f.fecha)
OPTION (MAXRECURSION 366);

SELECT MIN(fecha) AS primera, MAX(fecha) AS ultima, COUNT(*) AS dias
FROM cur.dim_fecha;
