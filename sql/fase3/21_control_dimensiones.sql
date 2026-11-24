-- Manual §8.3. Ejecutar en sqldb-control después del despliegue base y del calendario.
-- La adaptación del Anexo E conserva P1/P2 y usa motivo CONTROL. Estos miembros
-- son propios del fixture adaptado; no se usan para análisis de negocio real.

INSERT INTO cur.dim_producto (producto, familia)
SELECT v.producto, 'Control'
FROM (VALUES ('P1'), ('P2')) v(producto)
WHERE NOT EXISTS (SELECT 1 FROM cur.dim_producto p WHERE p.producto = v.producto);

IF NOT EXISTS (SELECT 1 FROM cur.dim_motivo WHERE motivo = 'CONTROL')
    INSERT INTO cur.dim_motivo (motivo, es_valido) VALUES ('CONTROL', 1);

SELECT producto, familia FROM cur.dim_producto WHERE producto IN ('P1', 'P2');
SELECT motivo_sk, motivo, es_valido FROM cur.dim_motivo WHERE motivo = 'CONTROL';
