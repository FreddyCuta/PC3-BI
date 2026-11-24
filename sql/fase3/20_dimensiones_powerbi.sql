-- Manual §9.1. Ejecutar como administrador en la base Tobotex después del despliegue.
-- El usuario bi_reader no lee cur; estas vistas exponen sólo dimensiones necesarias.
-- No relacionar hechos mediante v_dim_tienda_bi con múltiples versiones SCD2.
-- La zona histórica ya está resuelta en bi.v_despacho y bi.v_reclamo.

CREATE OR ALTER VIEW bi.v_dim_fecha AS
SELECT fecha, fecha_sk, anio, mes, periodo, nombre_mes
FROM cur.dim_fecha;
GO
CREATE OR ALTER VIEW bi.v_dim_tienda_bi AS
SELECT DISTINCT tienda FROM cur.dim_tienda WHERE tienda_sk > 0;
GO
CREATE OR ALTER VIEW bi.v_dim_marca_bi AS
SELECT marca_codigo FROM cur.dim_marca WHERE marca_sk > 0;
GO
CREATE OR ALTER VIEW bi.v_dim_producto_bi AS
SELECT producto FROM cur.dim_producto WHERE producto_sk > 0;
GO

-- Verificación de unicidad: ambas deben devolver cero filas.
SELECT marca_codigo, COUNT(*) AS filas
FROM bi.v_dim_marca_bi GROUP BY marca_codigo HAVING COUNT(*) > 1;
SELECT tienda, COUNT(*) AS filas
FROM bi.v_dim_tienda_bi GROUP BY tienda HAVING COUNT(*) > 1;
