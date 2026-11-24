-- Manual §12.1. Ejecutar con bi_reader o administrador.
-- Diferencia debe ser 0 en filas clasificadas. NULL = no calculado, no cero.
SELECT lote_id, intento, fuente, estado,
       filas_leadas, filas_ins, filas_upd, filas_omit, filas_rech,
       filas_leadas - (filas_ins + filas_upd + filas_omit + filas_rech) AS diferencia
FROM ctl.lote
WHERE fuente <> 'LOTE'
ORDER BY lote_id, intento, fuente;
