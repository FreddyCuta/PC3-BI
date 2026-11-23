CREATE TABLE stg.despacho (
  id_movimiento NVARCHAR(100), version NVARCHAR(100), fecha_salida NVARCHAR(100), tienda NVARCHAR(100),
  marca NVARCHAR(200), producto NVARCHAR(100), contrato NVARCHAR(100), detalle NVARCHAR(100),
  cantidad_contratada NVARCHAR(100), cantidad_despachada NVARCHAR(100), importe_pen NVARCHAR(100),
  fecha_actualizacion_origen NVARCHAR(100), lote_id VARCHAR(10), archivo NVARCHAR(300));
CREATE TABLE stg.reclamo (
  id_reclamo NVARCHAR(100), id_movimiento NVARCHAR(100), fecha_reclamo NVARCHAR(100),
  cantidad_devuelta NVARCHAR(100), importe_devuelto_pen NVARCHAR(100), motivo NVARCHAR(100),
  fecha_actualizacion_origen NVARCHAR(100), lote_id VARCHAR(10), archivo NVARCHAR(300));
CREATE TABLE stg.tienda (
  tienda NVARCHAR(100), zona_comercial NVARCHAR(100), vigente_desde NVARCHAR(100), vigente_hasta NVARCHAR(100),
  lote_id VARCHAR(10), archivo NVARCHAR(300));