CREATE TABLE cur.dim_fecha (
  fecha_sk INT NOT NULL PRIMARY KEY, fecha DATE NOT NULL UNIQUE, anio SMALLINT NOT NULL, mes TINYINT NOT NULL,
  periodo CHAR(7) NOT NULL, nombre_mes VARCHAR(12) NOT NULL);
CREATE TABLE cur.dim_tienda (
  tienda_sk INT IDENTITY PRIMARY KEY, tienda VARCHAR(10) NOT NULL, zona_comercial VARCHAR(40) NOT NULL,
  vigente_desde DATE NOT NULL, vigente_hasta DATE NOT NULL, es_actual BIT NOT NULL,
  CONSTRAINT uq_dim_tienda UNIQUE (tienda, vigente_desde));
CREATE TABLE cur.dim_marca (
  marca_sk INT IDENTITY PRIMARY KEY, marca NVARCHAR(100) NOT NULL UNIQUE,
  marca_codigo AS CAST('MK-' + LEFT(CONVERT(CHAR(64), HASHBYTES('SHA2_256', marca), 2), 8) AS VARCHAR(11)) PERSISTED);
CREATE TABLE cur.dim_producto (
  producto_sk INT IDENTITY PRIMARY KEY, producto VARCHAR(20) NOT NULL UNIQUE, familia VARCHAR(30) NOT NULL);
CREATE TABLE cur.dim_motivo (
  motivo_sk INT IDENTITY PRIMARY KEY, motivo VARCHAR(30) NOT NULL UNIQUE, es_valido BIT NOT NULL);

CREATE TABLE cur.fact_despacho (
  despacho_sk BIGINT IDENTITY PRIMARY KEY, id_movimiento VARCHAR(20) NOT NULL, version INT NOT NULL,
  fecha_sk INT NOT NULL REFERENCES cur.dim_fecha(fecha_sk), tienda_sk INT NOT NULL REFERENCES cur.dim_tienda(tienda_sk),
  marca_sk INT NOT NULL REFERENCES cur.dim_marca(marca_sk), producto_sk INT NOT NULL REFERENCES cur.dim_producto(producto_sk),
  contrato VARCHAR(20) NOT NULL, detalle VARCHAR(20) NOT NULL,
  cantidad_contratada INT NOT NULL, cantidad_despachada INT NOT NULL, importe_pen DECIMAL(18,2) NOT NULL,
  hash_fila CHAR(64) NOT NULL, lote_id VARCHAR(10) NOT NULL, corte_desde INT NOT NULL, corte_hasta INT NULL);
CREATE TABLE cur.fact_reclamo (
  reclamo_sk BIGINT IDENTITY PRIMARY KEY, id_reclamo VARCHAR(20) NOT NULL, id_movimiento VARCHAR(20) NOT NULL,
  fecha_sk INT NOT NULL REFERENCES cur.dim_fecha(fecha_sk), tienda_sk INT NOT NULL REFERENCES cur.dim_tienda(tienda_sk),
  marca_sk INT NOT NULL REFERENCES cur.dim_marca(marca_sk), producto_sk INT NOT NULL REFERENCES cur.dim_producto(producto_sk),
  motivo_sk INT NOT NULL REFERENCES cur.dim_motivo(motivo_sk),
  cantidad_devuelta INT NOT NULL, importe_devuelto_pen DECIMAL(18,2) NOT NULL,
  hash_fila CHAR(64) NOT NULL, lote_id VARCHAR(10) NOT NULL, corte_desde INT NOT NULL, corte_hasta INT NULL);
CREATE INDEX ix_fd_corte ON cur.fact_despacho (corte_desde, corte_hasta) INCLUDE (id_movimiento);
CREATE INDEX ix_fr_corte ON cur.fact_reclamo  (corte_desde, corte_hasta) INCLUDE (id_reclamo);