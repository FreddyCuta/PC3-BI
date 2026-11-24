-- Manual §4.5. Propuesta de endurecimiento de ctl.sp_publicar_corte.
-- Sustituye a la definición de "SQL query 11.sql" sólo después de validar en sqldb-test.
-- No publicar desde una rama de fallo: esta versión revierte y relanza el error.

CREATE OR ALTER PROCEDURE ctl.sp_publicar_corte @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  BEGIN TRY
    BEGIN TRAN;

    -- Bloqueo del puntero para evitar dos publicaciones concurrentes.
    DECLARE @vigente INT;
    SELECT @vigente = corte_seq
    FROM ctl.corte_vigente WITH (UPDLOCK, HOLDLOCK)
    WHERE id = 1;
    IF @@ROWCOUNT <> 1
      THROW 50003, 'No existe la fila única id=1 en ctl.corte_vigente', 1;

    IF NOT EXISTS (SELECT 1 FROM ctl.corte WITH (UPDLOCK, HOLDLOCK)
                   WHERE corte_seq = @corte_seq AND estado = 'CANDIDATO')
      THROW 50002, 'El corte no existe o no está en estado CANDIDATO', 1;

    IF (SELECT COUNT(DISTINCT objeto) FROM ctl.corte_objeto
        WHERE corte_seq = @corte_seq AND estado = 'LISTO'
          AND objeto IN ('fact_despacho', 'fact_reclamo')) <> 2
      THROW 50001, 'Corte incompleto: faltan uno o ambos objetos LISTO', 1;

    IF EXISTS (
      SELECT 1
      FROM ctl.lote l
      JOIN ctl.corte c ON c.lote_id = l.lote_id AND c.intento = l.intento
      WHERE c.corte_seq = @corte_seq
        AND l.fuente = 'LOTE'
        AND l.estado IN ('BLOQUEADO_C8', 'FALLIDO', 'RECHAZADO_ESQUEMA')
    )
      THROW 50004, 'El intento está bloqueado, fallido o rechazado por esquema; no se publica', 1;

    IF EXISTS (
      SELECT 1
      FROM ctl.lote l
      JOIN ctl.corte c ON c.lote_id = l.lote_id AND c.intento = l.intento
      WHERE c.corte_seq = @corte_seq
        AND l.fuente IN ('despacho', 'reclamo', 'tienda')
        AND l.filas_leadas IS NOT NULL
        AND l.filas_leadas <> ISNULL(l.filas_ins, 0) + ISNULL(l.filas_upd, 0)
                            + ISNULL(l.filas_omit, 0) + ISNULL(l.filas_rech, 0)
    )
      THROW 50005, 'Conciliación de fuentes inconsistente; no se publica', 1;

    UPDATE ctl.corte
    SET estado = 'PUBLICADO', publicado_utc = SYSUTCDATETIME()
    WHERE corte_seq = @corte_seq AND estado = 'CANDIDATO';
    IF @@ROWCOUNT <> 1
      THROW 50002, 'El corte dejó de ser candidato durante la publicación', 1;

    UPDATE ctl.corte_vigente SET corte_seq = @corte_seq WHERE id = 1;
    IF @@ROWCOUNT <> 1
      THROW 50006, 'No se pudo actualizar el puntero de corte vigente', 1;

    UPDATE l
    SET estado = 'PUBLICADO', corte_seq = @corte_seq, fin_utc = SYSUTCDATETIME()
    FROM ctl.lote l
    JOIN ctl.corte c ON c.lote_id = l.lote_id AND c.intento = l.intento
    WHERE c.corte_seq = @corte_seq AND l.fuente = 'LOTE';

    COMMIT TRAN;
  END TRY
  BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRAN;
    THROW;
  END CATCH
END
GO
