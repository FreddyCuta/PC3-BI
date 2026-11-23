CREATE OR ALTER FUNCTION bi.fn_despacho (@corte INT) RETURNS TABLE AS RETURN
  SELECT f.despacho_sk, f.id_movimiento, f.version, d.fecha, d.periodo, t.tienda, t.zona_comercial, m.marca_codigo,
         p.producto, f.contrato, f.detalle, f.cantidad_contratada, f.cantidad_despachada, f.importe_pen
  FROM cur.fact_despacho f
  JOIN cur.dim_fecha d ON d.fecha_sk = f.fecha_sk
  JOIN cur.dim_tienda t ON t.tienda_sk = f.tienda_sk
  JOIN cur.dim_marca m ON m.marca_sk = f.marca_sk
  JOIN cur.dim_producto p ON p.producto_sk = f.producto_sk
  WHERE f.corte_desde <= @corte AND (f.corte_hasta IS NULL OR f.corte_hasta > @corte);
GO
CREATE OR ALTER FUNCTION bi.fn_reclamo (@corte INT) RETURNS TABLE AS RETURN
  SELECT f.reclamo_sk, f.id_reclamo, f.id_movimiento, d.fecha, d.periodo, t.tienda, t.zona_comercial, m.marca_codigo,
         p.producto, mo.motivo, mo.es_valido AS motivo_valido, f.cantidad_devuelta, f.importe_devuelto_pen
  FROM cur.fact_reclamo f
  JOIN cur.dim_fecha d ON d.fecha_sk = f.fecha_sk
  JOIN cur.dim_tienda t ON t.tienda_sk = f.tienda_sk
  JOIN cur.dim_marca m ON m.marca_sk = f.marca_sk
  JOIN cur.dim_producto p ON p.producto_sk = f.producto_sk
  JOIN cur.dim_motivo mo ON mo.motivo_sk = f.motivo_sk
  WHERE f.corte_desde <= @corte AND (f.corte_hasta IS NULL OR f.corte_hasta > @corte);
GO
CREATE OR ALTER VIEW bi.v_despacho AS
  SELECT f.* FROM ctl.corte_vigente v CROSS APPLY bi.fn_despacho(v.corte_seq) f;
GO
CREATE OR ALTER VIEW bi.v_reclamo AS
  SELECT f.* FROM ctl.corte_vigente v CROSS APPLY bi.fn_reclamo(v.corte_seq) f;
GO
CREATE OR ALTER VIEW bi.v_corte_publicado AS
  SELECT c.corte_seq, c.corte_id, c.lote_id,
         CAST(c.publicado_utc AT TIME ZONE 'UTC' AT TIME ZONE 'SA Pacific Standard Time' AS DATETIME2(0)) AS publicado_lima
  FROM ctl.corte c JOIN ctl.corte_vigente v ON v.corte_seq = c.corte_seq;
GO
CREATE OR ALTER VIEW bi.v_periodo_revisado AS
  SELECT DISTINCT p.periodo, c.corte_id AS revisado_en_corte
  FROM ctl.periodo_revisado p JOIN ctl.corte c ON c.corte_seq = p.corte_seq
  CROSS JOIN ctl.corte_vigente v
  WHERE c.estado = 'PUBLICADO' AND c.corte_seq <= v.corte_seq;
GO
CREATE OR ALTER VIEW bi.v_comparacion_cortes AS
  WITH b AS (SELECT c.corte_seq, c.corte_id, f.periodo, SUM(f.importe_pen) AS bruto
             FROM ctl.corte c CROSS APPLY bi.fn_despacho(c.corte_seq) f WHERE c.estado = 'PUBLICADO'
             GROUP BY c.corte_seq, c.corte_id, f.periodo),
       r AS (SELECT c.corte_seq, f.periodo, SUM(f.importe_devuelto_pen) AS devuelto
             FROM ctl.corte c CROSS APPLY bi.fn_reclamo(c.corte_seq) f WHERE c.estado = 'PUBLICADO'
             GROUP BY c.corte_seq, f.periodo)
  SELECT b.corte_seq, b.corte_id, b.periodo, b.bruto, ISNULL(r.devuelto, 0) AS devuelto, b.bruto - ISNULL(r.devuelto, 0) AS neto
  FROM b LEFT JOIN r ON r.corte_seq = b.corte_seq AND r.periodo = b.periodo;
GO