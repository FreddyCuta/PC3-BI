-- Las dos versiones de LEO en cur.dim_tienda
SELECT *
FROM cur.dim_tienda
WHERE tienda = 'LEO'
ORDER BY vigente_desde;

-- 1. Despacho tardío M000413 (fecha 2026-09-09 -> debe mostrar Gamarra Norte)
SELECT *
FROM bi.v_despacho
WHERE id_movimiento = 'M000413';

-- 2. Reclamo tardío R000051 (fecha 2026-09-22 -> debe mostrar Gamarra Centro)
SELECT *
FROM bi.v_reclamo
WHERE id_reclamo = 'R000051';

SELECT TOP 1 * FROM bi.v_despacho;
SELECT TOP 1 * FROM bi.v_reclamo;

-- (a) Solo el hecho de despacho en julio 2026 (esperado: 49197.85)
SELECT 
    '(a) Solo despacho' AS calculo,
    SUM(importe_pen) AS despacho_bruto_julio
FROM bi.v_despacho
WHERE periodo = '2026-07';

-- (b) Unión directa a nivel de línea de movimiento (esperado: 49403.93 - se infla)
SELECT 
    '(b) Union directa a nivel de linea' AS calculo,
    SUM(d.importe_pen) AS despacho_bruto_julio
FROM bi.v_despacho d
LEFT JOIN bi.v_reclamo r 
    ON d.id_movimiento = r.id_movimiento
WHERE d.periodo = '2026-07';

-- (c) Agregación previa por mes y tienda antes de combinar (esperado: 49197.85)
WITH desp_agg AS (
    SELECT periodo, tienda, SUM(importe_pen) AS bruto
    FROM bi.v_despacho
    WHERE periodo = '2026-07'
    GROUP BY periodo, tienda
),
rec_agg AS (
    SELECT periodo, tienda, SUM(importe_devuelto_pen) AS devuelto
    FROM bi.v_reclamo
    GROUP BY periodo, tienda
)
SELECT 
    '(c) Agregado previo por mes y tienda' AS calculo,
    SUM(d.bruto) AS despacho_bruto_julio
FROM desp_agg d
LEFT JOIN rec_agg r 
    ON d.periodo = r.periodo AND d.tienda = r.tienda;
