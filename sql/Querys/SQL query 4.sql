CREATE TABLE trusted.despacho (
  id_movimiento VARCHAR(20) NOT NULL, version INT NOT NULL, fecha_salida DATE NOT NULL, tienda VARCHAR(10) NOT NULL,
  marca NVARCHAR(100) NOT NULL, producto VARCHAR(20) NOT NULL, contrato VARCHAR(20) NOT NULL, detalle VARCHAR(20) NOT NULL,
  cantidad_contratada INT NOT NULL, cantidad_despachada INT NOT NULL, importe_pen DECIMAL(18,2) NOT NULL,
  fecha_actualizacion_origen DATETIME2(0) NULL, hash_fila CHAR(64) NOT NULL,
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, ingesta_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT pk_trusted_despacho PRIMARY KEY (id_movimiento, version));
CREATE TABLE trusted.reclamo (
  id_reclamo VARCHAR(20) NOT NULL PRIMARY KEY, id_movimiento VARCHAR(20) NOT NULL, fecha_reclamo DATE NOT NULL,
  cantidad_devuelta INT NOT NULL, importe_devuelto_pen DECIMAL(18,2) NOT NULL, motivo VARCHAR(30) NULL,
  fecha_actualizacion_origen DATETIME2(0) NULL, hash_fila CHAR(64) NOT NULL,
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, ingesta_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE trusted.tienda (
  tienda VARCHAR(10) NOT NULL, zona_comercial VARCHAR(40) NOT NULL, vigente_desde DATE NOT NULL, vigente_hasta DATE NOT NULL,
  lote_id VARCHAR(10) NOT NULL, CONSTRAINT pk_trusted_tienda PRIMARY KEY (tienda, vigente_desde));
CREATE TABLE quar.rechazo (
  rechazo_id BIGINT IDENTITY PRIMARY KEY, fuente VARCHAR(20) NOT NULL, lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL,
  clave NVARCHAR(100) NULL, control VARCHAR(5) NOT NULL, motivo NVARCHAR(200) NOT NULL, hash_fila CHAR(64) NOT NULL,
  fila_json NVARCHAR(MAX) NULL, registrado_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT uq_rechazo UNIQUE (fuente, lote_id, hash_fila));