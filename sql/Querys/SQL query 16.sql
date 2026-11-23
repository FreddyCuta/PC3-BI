SELECT lote_id, intento, fuente, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado, corte_seq
FROM ctl.lote
ORDER BY lote_id, intento, fuente;

SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc
FROM ctl.corte
ORDER BY corte_seq;

SELECT fuente, lote_id, intento, clave, control, motivo
FROM quar.rechazo;

SELECT * FROM bi.v_periodo_revisado;

SELECT TOP 10 * FROM bi.v_k2 ORDER BY periodo, tienda;

SELECT * FROM bi.v_k4 ORDER BY periodo;

SELECT TOP 10 * FROM bi.v_k5 WHERE faltante > 0 ORDER BY faltante DESC;