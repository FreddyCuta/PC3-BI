CREATE OR ALTER PROCEDURE ctl.sp_abrir_corte @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @cambios INT = (SELECT SUM(ISNULL(filas_ins, 0) + ISNULL(filas_upd, 0)) FROM ctl.lote
                          WHERE lote_id = @lote_id AND intento = @intento AND fuente IN ('despacho', 'reclamo'));
  IF ISNULL(@cambios, 0) = 0
  BEGIN
    UPDATE ctl.lote SET estado = 'SIN_CAMBIOS', corte_seq = (SELECT corte_seq FROM ctl.corte_vigente), fin_utc = SYSUTCDATETIME()
    WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE';
    SELECT -1 AS corte_seq;
    RETURN;
  END
  DECLARE @c INT = (SELECT ISNULL(MAX(corte_seq), 0) + 1 FROM ctl.corte);
  DECLARE @hoy CHAR(8) = CONVERT(CHAR(8), CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SA Pacific Standard Time' AS DATE), 112);
  DECLARE @n INT = (SELECT COUNT(*) + 1 FROM ctl.corte WHERE corte_id LIKE 'C-' + @hoy + '-%');
  INSERT INTO ctl.corte (corte_seq, corte_id, estado, lote_id, intento, creado_utc)
  VALUES (@c, CONCAT('C-', @hoy, '-', RIGHT(CONCAT('0', @n), 2)), 'CANDIDATO', @lote_id, @intento, SYSUTCDATETIME());
  SELECT @c AS corte_seq;
END
GO
CREATE OR ALTER PROCEDURE cur.sp_preparar_hecho_despacho @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  DECLARE @lote_id VARCHAR(10), @intento INT, @recepcion DATE;
  SELECT @lote_id = c.lote_id, @intento = c.intento, @recepcion = l.fecha_recepcion
  FROM ctl.corte c JOIN ctl.lote l ON l.lote_id = c.lote_id AND l.intento = c.intento AND l.fuente = 'LOTE'
  WHERE c.corte_seq = @corte_seq AND c.estado = 'CANDIDATO';
  IF @lote_id IS NULL THROW 50030, 'El corte no existe o no es candidato', 1;

  SELECT d.* INTO #n FROM trusted.despacho d
  WHERE d.lote_id = @lote_id AND d.intento = @intento
    AND d.version = (SELECT MAX(x.version) FROM trusted.despacho x WHERE x.id_movimiento = d.id_movimiento);

  BEGIN TRAN;
    INSERT INTO cur.dim_marca (marca)
    SELECT DISTINCT n.marca FROM #n n WHERE NOT EXISTS (SELECT 1 FROM cur.dim_marca m WHERE m.marca = n.marca);

    UPDATE f SET corte_hasta = @corte_seq
    FROM cur.fact_despacho f JOIN #n n ON n.id_movimiento = f.id_movimiento
    WHERE f.corte_hasta IS NULL;

    INSERT INTO cur.fact_despacho (id_movimiento, version, fecha_sk, tienda_sk, marca_sk, producto_sk, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, hash_fila, lote_id, corte_desde, corte_hasta)
    SELECT n.id_movimiento, n.version, YEAR(n.fecha_salida) * 10000 + MONTH(n.fecha_salida) * 100 + DAY(n.fecha_salida),
           ISNULL(t.tienda_sk, -1), ISNULL(m.marca_sk, -1), ISNULL(p.producto_sk, -1), n.contrato, n.detalle,
           n.cantidad_contratada, n.cantidad_despachada, n.importe_pen, n.hash_fila, n.lote_id, @corte_seq, NULL
    FROM #n n
    LEFT JOIN cur.dim_tienda t ON t.tienda = n.tienda AND n.fecha_salida >= t.vigente_desde AND n.fecha_salida < t.vigente_hasta
    LEFT JOIN cur.dim_marca m ON m.marca = n.marca
    LEFT JOIN cur.dim_producto p ON p.producto = n.producto;

    INSERT INTO ctl.periodo_revisado (corte_seq, periodo, hecho, filas)
    SELECT @corte_seq, CONVERT(CHAR(7), n.fecha_salida, 126), 'fact_despacho', COUNT(*)
    FROM #n n
    WHERE @recepcion > DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(n.fecha_salida), MONTH(n.fecha_salida), 1)))
      AND EXISTS (SELECT 1 FROM cur.fact_despacho f JOIN cur.dim_fecha df ON df.fecha_sk = f.fecha_sk
                  WHERE df.periodo = CONVERT(CHAR(7), n.fecha_salida, 126) AND f.corte_desde < @corte_seq)
    GROUP BY CONVERT(CHAR(7), n.fecha_salida, 126);

    DELETE FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND objeto = 'fact_despacho';
    INSERT INTO ctl.corte_objeto (corte_seq, objeto, estado, filas) SELECT @corte_seq, 'fact_despacho', 'LISTO', COUNT(*) FROM #n;
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE cur.sp_preparar_hecho_reclamo @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  DECLARE @lote_id VARCHAR(10), @intento INT, @recepcion DATE;
  SELECT @lote_id = c.lote_id, @intento = c.intento, @recepcion = l.fecha_recepcion
  FROM ctl.corte c JOIN ctl.lote l ON l.lote_id = c.lote_id AND l.intento = c.intento AND l.fuente = 'LOTE'
  WHERE c.corte_seq = @corte_seq AND c.estado = 'CANDIDATO';
  IF @lote_id IS NULL THROW 50031, 'El corte no existe o no es candidato', 1;

  SELECT r.*, d.tienda, d.marca, d.producto INTO #n
  FROM trusted.reclamo r
  JOIN trusted.despacho d ON d.id_movimiento = r.id_movimiento
   AND d.version = (SELECT MAX(x.version) FROM trusted.despacho x WHERE x.id_movimiento = r.id_movimiento)
  WHERE r.lote_id = @lote_id AND r.intento = @intento;

  BEGIN TRAN;
    INSERT INTO cur.fact_reclamo (id_reclamo, id_movimiento, fecha_sk, tienda_sk, marca_sk, producto_sk, motivo_sk,
           cantidad_devuelta, importe_devuelto_pen, hash_fila, lote_id, corte_desde, corte_hasta)
    SELECT n.id_reclamo, n.id_movimiento, YEAR(n.fecha_reclamo) * 10000 + MONTH(n.fecha_reclamo) * 100 + DAY(n.fecha_reclamo),
           ISNULL(t.tienda_sk, -1), ISNULL(m.marca_sk, -1), ISNULL(p.producto_sk, -1), ISNULL(mo.motivo_sk, -1),
           n.cantidad_devuelta, n.importe_devuelto_pen, n.hash_fila, n.lote_id, @corte_seq, NULL
    FROM #n n
    LEFT JOIN cur.dim_tienda t ON t.tienda = n.tienda AND n.fecha_reclamo >= t.vigente_desde AND n.fecha_reclamo < t.vigente_hasta
    LEFT JOIN cur.dim_marca m ON m.marca = n.marca
    LEFT JOIN cur.dim_producto p ON p.producto = n.producto
    LEFT JOIN cur.dim_motivo mo ON mo.motivo = n.motivo;

    INSERT INTO ctl.periodo_revisado (corte_seq, periodo, hecho, filas)
    SELECT @corte_seq, CONVERT(CHAR(7), n.fecha_reclamo, 126), 'fact_reclamo', COUNT(*)
    FROM #n n
    WHERE @recepcion > DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(n.fecha_reclamo), MONTH(n.fecha_reclamo), 1)))
      AND EXISTS (SELECT 1 FROM cur.fact_despacho f JOIN cur.dim_fecha df ON df.fecha_sk = f.fecha_sk
                  WHERE df.periodo = CONVERT(CHAR(7), n.fecha_reclamo, 126) AND f.corte_desde < @corte_seq)
    GROUP BY CONVERT(CHAR(7), n.fecha_reclamo, 126);

    DELETE FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND objeto = 'fact_reclamo';
    INSERT INTO ctl.corte_objeto (corte_seq, objeto, estado, filas) SELECT @corte_seq, 'fact_reclamo', 'LISTO', COUNT(*) FROM #n;
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_publicar_corte @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF (SELECT COUNT(*) FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND estado = 'LISTO'
      AND objeto IN ('fact_despacho', 'fact_reclamo')) < 2
    THROW 50001, 'Corte incompleto: falta preparar un hecho, no se publica', 1;
  BEGIN TRAN;
    UPDATE ctl.corte SET estado = 'PUBLICADO', publicado_utc = SYSUTCDATETIME() WHERE corte_seq = @corte_seq AND estado = 'CANDIDATO';
    IF @@ROWCOUNT = 0 THROW 50002, 'El corte no estaba en estado CANDIDATO', 1;
    UPDATE ctl.corte_vigente SET corte_seq = @corte_seq WHERE id = 1;
    UPDATE l SET estado = 'PUBLICADO', corte_seq = @corte_seq, fin_utc = SYSUTCDATETIME()
    FROM ctl.lote l JOIN ctl.corte c ON c.lote_id = l.lote_id AND c.intento = l.intento
    WHERE c.corte_seq = @corte_seq AND l.fuente = 'LOTE';
  COMMIT;
END
GO