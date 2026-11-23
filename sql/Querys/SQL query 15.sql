-- 1. Bitácora de lotes ejecutados y cortes publicados
SELECT lote_id, intento, fuente, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado, corte_seq
FROM ctl.lote
ORDER BY lote_id, intento, fuente;

SELECT corte_seq, corte_id, lote_id, intento, estado, publicado_utc
FROM ctl.corte
ORDER BY corte_seq;

-- 2. Períodos revisados y registros en cuarentena
SELECT * FROM bi.v_periodo_revisado;
SELECT fuente, lote_id, clave, control, motivo FROM quar.rechazo;

-- 3. Vista previa de KPIs (K1, K2, K4 y K6)
SELECT * FROM bi.v_k1 ORDER BY periodo, tienda;
SELECT * FROM bi.v_k4 ORDER BY periodo;
SELECT * FROM bi.v_k6 ORDER BY periodo, marca_codigo;