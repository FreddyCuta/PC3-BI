-- P5 recuperación — Tobotex. Manual §12.6 pasos 8–10.
-- No sobrescribir LX original. Crear carpeta nueva de corrección reconstruyendo el esquema
-- desde fuente válida; registrar nuevo hash/versión de entrega y reejecutar en la copia.
-- Si los movimientos ya estaban cargados, SIN_CAMBIOS es un resultado correcto.
SELECT lote_id, intento, fuente, estado, filas_leadas, filas_ins, filas_upd,
       filas_omit, filas_rech, corte_seq, archivo
FROM ctl.lote WHERE lote_id = 'LX' ORDER BY intento, fuente;

SELECT * FROM bi.v_corte_publicado;
SELECT corte_seq, corte_id, estado, publicado_utc FROM ctl.corte ORDER BY corte_seq;

-- Confirmar que el corte publicado no cambió respecto del estado previo a la corrección.
SELECT COUNT(*) AS movimientos_lx_trusted FROM trusted.despacho WHERE lote_id = 'LX';
