CREATE OR ALTER PROCEDURE ctl.sp_descartar_candidatos
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  BEGIN TRAN;
    DELETE f FROM cur.fact_despacho f JOIN ctl.corte c ON c.corte_seq = f.corte_desde WHERE c.estado = 'CANDIDATO';
    DELETE f FROM cur.fact_reclamo  f JOIN ctl.corte c ON c.corte_seq = f.corte_desde WHERE c.estado = 'CANDIDATO';
    UPDATE f SET corte_hasta = NULL FROM cur.fact_despacho f JOIN ctl.corte c ON c.corte_seq = f.corte_hasta WHERE c.estado = 'CANDIDATO';
    UPDATE f SET corte_hasta = NULL FROM cur.fact_reclamo  f JOIN ctl.corte c ON c.corte_seq = f.corte_hasta WHERE c.estado = 'CANDIDATO';
    DELETE p FROM ctl.periodo_revisado p JOIN ctl.corte c ON c.corte_seq = p.corte_seq WHERE c.estado = 'CANDIDATO';
    UPDATE ctl.corte SET estado = 'DESCARTADO' WHERE estado = 'CANDIDATO';
    UPDATE ctl.lote SET estado = 'FALLIDO', mensaje = ISNULL(mensaje, 'Interrumpido sin cierre'), fin_utc = ISNULL(fin_utc, SYSUTCDATETIME())
    WHERE fuente = 'LOTE' AND estado = 'EN_PROCESO';
    DELETE d FROM trusted.despacho d JOIN ctl.lote l ON l.lote_id = d.lote_id AND l.intento = d.intento AND l.fuente = 'LOTE'
    WHERE l.estado NOT IN ('PUBLICADO', 'SIN_CAMBIOS');
    DELETE r FROM trusted.reclamo r JOIN ctl.lote l ON l.lote_id = r.lote_id AND l.intento = r.intento AND l.fuente = 'LOTE'
    WHERE l.estado NOT IN ('PUBLICADO', 'SIN_CAMBIOS');
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_iniciar_lote @lote_id VARCHAR(10), @fecha_recepcion DATE, @run_id VARCHAR(80)
AS
BEGIN
  SET NOCOUNT ON;
  EXEC ctl.sp_descartar_candidatos;
  DELETE FROM stg.despacho; DELETE FROM stg.reclamo; DELETE FROM stg.tienda;
  DECLARE @intento INT = (SELECT ISNULL(MAX(intento), 0) + 1 FROM ctl.lote WHERE lote_id = @lote_id);
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, estado, run_id)
  VALUES (@lote_id, @intento, 'LOTE', @fecha_recepcion, 'EN_PROCESO', @run_id);
  SELECT @intento AS intento;
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_validar_contrato
  @lote_id VARCHAR(10), @intento INT, @fuente VARCHAR(20), @columnas NVARCHAR(MAX) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @faltan NVARCHAR(400);
  IF NULLIF(@columnas, '') IS NOT NULL
    SELECT @faltan = STRING_AGG(c.campo, ', ')
    FROM ctl.contrato_campo c
    WHERE c.fuente = @fuente AND c.version_contrato = '1.0' AND c.requerido = 1
      AND NOT EXISTS (SELECT 1 FROM OPENJSON(@columnas) WITH (name NVARCHAR(128) '$.name') j
                      WHERE LOWER(LTRIM(RTRIM(j.name))) = c.campo);
  ELSE
  BEGIN
    DECLARE @sql NVARCHAR(MAX);
    SELECT @sql = STRING_AGG(CONVERT(NVARCHAR(MAX), CONCAT(N'SELECT ''', campo, N''' AS campo WHERE NOT EXISTS (SELECT 1 FROM stg.',
                  @fuente, N' WHERE lote_id = @l AND ', QUOTENAME(campo), N' IS NOT NULL)')), N' UNION ALL ')
    FROM ctl.contrato_campo WHERE fuente = @fuente AND version_contrato = '1.0' AND requerido = 1;
    CREATE TABLE #faltan (campo SYSNAME);
    INSERT INTO #faltan EXEC sp_executesql @sql, N'@l VARCHAR(10)', @l = @lote_id;
    SELECT @faltan = STRING_AGG(campo, ', ') FROM #faltan;
  END
  IF @faltan IS NOT NULL
  BEGIN
    DECLARE @msg NVARCHAR(400) = CONCAT(N'C1 esquema incompatible en ', @fuente, N': falta ', @faltan);
    UPDATE ctl.lote SET estado = 'RECHAZADO_ESQUEMA', mensaje = @msg, fin_utc = SYSUTCDATETIME()
    WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE';
    THROW 50010, @msg, 1;
  END
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_marcar_falla @lote_id VARCHAR(10), @intento INT, @mensaje NVARCHAR(400)
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE ctl.lote SET estado = 'FALLIDO', mensaje = LEFT(@mensaje, 400), fin_utc = SYSUTCDATETIME()
  WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE' AND estado = 'EN_PROCESO';
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_simular_falla
AS
BEGIN
  THROW 50099, 'Falla simulada despues de preparar fact_despacho (prueba P8)', 1;
END
GO