-- Manual §§4.4 y 8.3. Versión propuesta que sustituye a "SQL query 10.sql".
-- Cambios respecto del archivo original:
--   1. @umbral_rechazo DECIMAL(5,4) = 0.2000 en despacho y reclamo.
--   2. Comparación estricta '>' contra el parámetro en estado y THROW.
--   3. La cuarentena se inserta antes de la comprobación C8 y fuera de la
--      transacción que inserta en trusted, para conservar las filas rechazadas
--      de un lote bloqueado (manual §4.4.5).
--   4. trusted.sp_merge_tienda se conserva sin cambios.
-- No ejecutar en las bases del caso sin antes validar en sqldb-test.
-- Tobotex: 0.2000. Control Anexo E: 0.2500 (decisión documentada, no regla oficial).

CREATE OR ALTER PROCEDURE trusted.sp_merge_tienda @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.tienda WHERE lote_id = @lote_id) RETURN;
  INSERT INTO trusted.tienda (tienda, zona_comercial, vigente_desde, vigente_hasta, lote_id)
  SELECT UPPER(TRIM(s.tienda)), TRIM(s.zona_comercial), CAST(s.vigente_desde AS DATE),
         ISNULL(TRY_CAST(NULLIF(TRIM(s.vigente_hasta), '') AS DATE), '9999-12-31'), @lote_id
  FROM stg.tienda s
  WHERE s.lote_id = @lote_id
    AND NOT EXISTS (SELECT 1 FROM trusted.tienda t WHERE t.tienda = UPPER(TRIM(s.tienda)) AND t.vigente_desde = CAST(s.vigente_desde AS DATE));
  DECLARE @ins INT = @@ROWCOUNT;
  INSERT INTO cur.dim_tienda (tienda, zona_comercial, vigente_desde, vigente_hasta, es_actual)
  SELECT t.tienda, t.zona_comercial, t.vigente_desde, t.vigente_hasta, 0
  FROM trusted.tienda t
  WHERE NOT EXISTS (SELECT 1 FROM cur.dim_tienda d WHERE d.tienda = t.tienda AND d.vigente_desde = t.vigente_desde);
  UPDATE cur.dim_tienda SET es_actual = CASE WHEN vigente_hasta = '9999-12-31' THEN 1 ELSE 0 END WHERE tienda_sk > 0;
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  SELECT @lote_id, @intento, 'tienda', l.fecha_recepcion, (SELECT TOP 1 archivo FROM stg.tienda WHERE lote_id = @lote_id),
         (SELECT COUNT(*) FROM stg.tienda WHERE lote_id = @lote_id), @ins, 0,
         (SELECT COUNT(*) FROM stg.tienda WHERE lote_id = @lote_id) - @ins, 0, 'CLASIFICADO'
  FROM ctl.lote l WHERE l.lote_id = @lote_id AND l.intento = @intento AND l.fuente = 'LOTE';
END
GO
CREATE OR ALTER PROCEDURE trusted.sp_merge_despacho
  @lote_id VARCHAR(10), @intento INT, @umbral_rechazo DECIMAL(5,4) = 0.2000
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.despacho WHERE lote_id = @lote_id) RETURN;
  DECLARE @recepcion DATE = (SELECT fecha_recepcion FROM ctl.lote WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE');

  SELECT NULLIF(TRIM(s.id_movimiento), '')                         AS id_movimiento,
         TRY_CAST(NULLIF(TRIM(s.version), '') AS INT)               AS version,
         TRY_CAST(NULLIF(TRIM(s.fecha_salida), '') AS DATE)         AS fecha_salida,
         UPPER(NULLIF(TRIM(s.tienda), ''))                          AS tienda,
         NULLIF(TRIM(s.marca), '')                                  AS marca,
         UPPER(NULLIF(TRIM(s.producto), ''))                        AS producto,
         NULLIF(TRIM(s.contrato), '')                               AS contrato,
         NULLIF(TRIM(s.detalle), '')                                AS detalle,
         TRY_CAST(NULLIF(TRIM(s.cantidad_contratada), '') AS INT)   AS cantidad_contratada,
         TRY_CAST(NULLIF(TRIM(s.cantidad_despachada), '') AS INT)   AS cantidad_despachada,
         TRY_CAST(NULLIF(TRIM(s.importe_pen), '') AS DECIMAL(18,2)) AS importe_pen,
         TRY_CAST(NULLIF(TRIM(s.fecha_actualizacion_origen), '') AS DATETIME2(0)) AS fecha_actualizacion_origen,
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|', s.id_movimiento, s.version, s.fecha_salida, s.tienda, s.marca,
                 s.producto, s.contrato, s.detalle, s.cantidad_contratada, s.cantidad_despachada, s.importe_pen)), 2) AS hash_fila,
         (SELECT s.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS fila_json
  INTO #t FROM stg.despacho s WHERE s.lote_id = @lote_id;

  SELECT t.*,
    CASE
      WHEN t.id_movimiento IS NULL OR t.version IS NULL OR t.fecha_salida IS NULL OR t.tienda IS NULL OR t.marca IS NULL
        OR t.producto IS NULL OR t.contrato IS NULL OR t.detalle IS NULL OR t.cantidad_contratada IS NULL
        OR t.cantidad_despachada IS NULL OR t.importe_pen IS NULL                                        THEN 'C4'
      WHEN t.cantidad_contratada <= 0 OR t.cantidad_despachada <= 0 OR t.importe_pen <= 0
        OR NOT EXISTS (SELECT 1 FROM cur.dim_producto p WHERE p.producto = t.producto AND p.producto_sk > 0) THEN 'C5'
      WHEN NOT EXISTS (SELECT 1 FROM trusted.tienda x WHERE x.tienda = t.tienda
                       AND t.fecha_salida >= x.vigente_desde AND t.fecha_salida < x.vigente_hasta)        THEN 'C6'
      WHEN @recepcion > DATEADD(day, 90, DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(t.fecha_salida), MONTH(t.fecha_salida), 1))))
                                                                                                           THEN 'C7'
      WHEN MIN(t.hash_fila) OVER (PARTITION BY t.id_movimiento, t.version)
        <> MAX(t.hash_fila) OVER (PARTITION BY t.id_movimiento, t.version)                                THEN 'C3'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento
                   AND d.version = t.version AND d.hash_fila <> t.hash_fila)                              THEN 'C3'
      WHEN ROW_NUMBER() OVER (PARTITION BY t.id_movimiento, t.version, t.hash_fila ORDER BY (SELECT NULL)) > 1 THEN 'C2'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento AND d.version = t.version) THEN 'C2R'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento AND d.version > t.version)  THEN 'VOBS'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento)                           THEN 'UPD'
      ELSE 'INS' END AS control,
    ROW_NUMBER() OVER (PARTITION BY t.hash_fila ORDER BY (SELECT NULL)) AS rn_hash
  INTO #c FROM #t t;

  DECLARE @leidas INT, @ins INT, @upd INT, @omit INT, @rech INT, @msg NVARCHAR(400);
  SELECT @leidas = COUNT(*), @ins = SUM(IIF(control = 'INS', 1, 0)), @upd = SUM(IIF(control = 'UPD', 1, 0)),
         @omit = SUM(IIF(control IN ('C2', 'C2R', 'VOBS'), 1, 0)), @rech = SUM(IIF(control IN ('C3','C4','C5','C6','C7'), 1, 0))
  FROM #c;

  -- Cuarentena antes de C8 y fuera de la transacción de trusted (manual §4.4.5).
  INSERT INTO quar.rechazo (fuente, lote_id, intento, clave, control, motivo, hash_fila, fila_json)
  SELECT 'despacho', @lote_id, @intento, CONCAT(c.id_movimiento, ' v', c.version), c.control,
         CASE c.control WHEN 'C3' THEN 'Misma clave y version con contenido distinto'
                        WHEN 'C4' THEN 'Campo requerido nulo o con tipo invalido'
                        WHEN 'C5' THEN 'Cantidad o importe no positivo, o producto fuera de catalogo'
                        WHEN 'C6' THEN 'Tienda inexistente o sin vigencia en la fecha de salida'
                        WHEN 'C7' THEN 'Correccion fuera de la ventana de 90 dias posterior al cierre' END,
         c.hash_fila, c.fila_json
  FROM #c c
  WHERE c.control IN ('C3','C4','C5','C6','C7') AND c.rn_hash = 1
    AND NOT EXISTS (SELECT 1 FROM quar.rechazo q WHERE q.fuente = 'despacho' AND q.lote_id = @lote_id AND q.hash_fila = c.hash_fila);

  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  VALUES (@lote_id, @intento, 'despacho', @recepcion, (SELECT TOP 1 archivo FROM stg.despacho WHERE lote_id = @lote_id),
          @leidas, @ins, @upd, @omit, @rech,
          IIF(CAST(@rech AS DECIMAL(10,4)) / NULLIF(@leidas, 0) > @umbral_rechazo, 'BLOQUEADO_C8', 'CLASIFICADO'));
  IF CAST(@rech AS DECIMAL(10,4)) / NULLIF(@leidas, 0) > @umbral_rechazo
  BEGIN
    SET @msg = CONCAT(N'C8: rechazos de despacho por encima del umbral parametrizado ', @umbral_rechazo, N'; no se publica');
    THROW 50020, @msg, 1;
  END

  BEGIN TRAN;
    INSERT INTO trusted.despacho (id_movimiento, version, fecha_salida, tienda, marca, producto, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, fecha_actualizacion_origen, hash_fila, lote_id, intento)
    SELECT id_movimiento, version, fecha_salida, tienda, marca, producto, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, fecha_actualizacion_origen, hash_fila, @lote_id, @intento
    FROM #c WHERE control IN ('INS', 'UPD');
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE trusted.sp_merge_reclamo
  @lote_id VARCHAR(10), @intento INT, @umbral_rechazo DECIMAL(5,4) = 0.2000
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.reclamo WHERE lote_id = @lote_id) RETURN;
  DECLARE @recepcion DATE = (SELECT fecha_recepcion FROM ctl.lote WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE');

  SELECT NULLIF(TRIM(s.id_reclamo), '')                                   AS id_reclamo,
         NULLIF(TRIM(s.id_movimiento), '')                                AS id_movimiento,
         TRY_CAST(NULLIF(TRIM(s.fecha_reclamo), '') AS DATE)              AS fecha_reclamo,
         TRY_CAST(NULLIF(TRIM(s.cantidad_devuelta), '') AS INT)           AS cantidad_devuelta,
         TRY_CAST(NULLIF(TRIM(s.importe_devuelto_pen), '') AS DECIMAL(18,2)) AS importe_devuelto_pen,
         UPPER(NULLIF(TRIM(s.motivo), ''))                                AS motivo,
         TRY_CAST(NULLIF(TRIM(s.fecha_actualizacion_origen), '') AS DATETIME2(0)) AS fecha_actualizacion_origen,
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|', s.id_reclamo, s.id_movimiento, s.fecha_reclamo,
                 s.cantidad_devuelta, s.importe_devuelto_pen, s.motivo)), 2) AS hash_fila,
         (SELECT s.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS fila_json
  INTO #t FROM stg.reclamo s WHERE s.lote_id = @lote_id;

  SELECT t.*,
    CASE
      WHEN t.id_reclamo IS NULL OR t.id_movimiento IS NULL OR t.fecha_reclamo IS NULL
        OR t.cantidad_devuelta IS NULL OR t.importe_devuelto_pen IS NULL                              THEN 'C4'
      WHEN t.cantidad_devuelta <= 0 OR t.importe_devuelto_pen <= 0                                    THEN 'C5'
      WHEN NOT EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento)       THEN 'C6'
      WHEN @recepcion > DATEADD(day, 90, DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(t.fecha_reclamo), MONTH(t.fecha_reclamo), 1))))
                                                                                                       THEN 'C7'
      WHEN MIN(t.hash_fila) OVER (PARTITION BY t.id_reclamo) <> MAX(t.hash_fila) OVER (PARTITION BY t.id_reclamo) THEN 'C3'
      WHEN EXISTS (SELECT 1 FROM trusted.reclamo r WHERE r.id_reclamo = t.id_reclamo AND r.hash_fila <> t.hash_fila) THEN 'C3'
      WHEN ROW_NUMBER() OVER (PARTITION BY t.id_reclamo, t.hash_fila ORDER BY (SELECT NULL)) > 1      THEN 'C2'
      WHEN EXISTS (SELECT 1 FROM trusted.reclamo r WHERE r.id_reclamo = t.id_reclamo)                 THEN 'C2R'
      ELSE 'INS' END AS control,
    ROW_NUMBER() OVER (PARTITION BY t.hash_fila ORDER BY (SELECT NULL)) AS rn_hash
  INTO #c FROM #t t;

  DECLARE @leidas INT, @ins INT, @omit INT, @rech INT, @msg NVARCHAR(400);
  SELECT @leidas = COUNT(*), @ins = SUM(IIF(control = 'INS', 1, 0)),
         @omit = SUM(IIF(control IN ('C2', 'C2R'), 1, 0)), @rech = SUM(IIF(control IN ('C3','C4','C5','C6','C7'), 1, 0))
  FROM #c;

  INSERT INTO quar.rechazo (fuente, lote_id, intento, clave, control, motivo, hash_fila, fila_json)
  SELECT 'reclamo', @lote_id, @intento, c.id_reclamo, c.control,
         CASE c.control WHEN 'C3' THEN 'Mismo reclamo con contenido distinto'
                        WHEN 'C4' THEN 'Campo requerido nulo o con tipo invalido'
                        WHEN 'C5' THEN 'Cantidad o importe devuelto no positivo'
                        WHEN 'C6' THEN 'El reclamo no apunta a un movimiento valido'
                        WHEN 'C7' THEN 'Correccion fuera de la ventana de 90 dias posterior al cierre' END,
         c.hash_fila, c.fila_json
  FROM #c c
  WHERE c.control IN ('C3','C4','C5','C6','C7') AND c.rn_hash = 1
    AND NOT EXISTS (SELECT 1 FROM quar.rechazo q WHERE q.fuente = 'reclamo' AND q.lote_id = @lote_id AND q.hash_fila = c.hash_fila);

  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  VALUES (@lote_id, @intento, 'reclamo', @recepcion, (SELECT TOP 1 archivo FROM stg.reclamo WHERE lote_id = @lote_id),
          @leidas, @ins, 0, @omit, @rech,
          IIF(CAST(@rech AS DECIMAL(10,4)) / NULLIF(@leidas, 0) > @umbral_rechazo, 'BLOQUEADO_C8', 'CLASIFICADO'));
  IF CAST(@rech AS DECIMAL(10,4)) / NULLIF(@leidas, 0) > @umbral_rechazo
  BEGIN
    SET @msg = CONCAT(N'C8: rechazos de reclamos por encima del umbral parametrizado ', @umbral_rechazo, N'; no se publica');
    THROW 50021, @msg, 1;
  END

  BEGIN TRAN;
    INSERT INTO trusted.reclamo (id_reclamo, id_movimiento, fecha_reclamo, cantidad_devuelta, importe_devuelto_pen, motivo,
           fecha_actualizacion_origen, hash_fila, lote_id, intento)
    SELECT id_reclamo, id_movimiento, fecha_reclamo, cantidad_devuelta, importe_devuelto_pen, motivo,
           fecha_actualizacion_origen, hash_fila, @lote_id, @intento
    FROM #c WHERE control = 'INS';
  COMMIT;
END
GO
