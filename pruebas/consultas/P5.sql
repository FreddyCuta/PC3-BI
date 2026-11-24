-- P5 esquema incompatible LX — Tobotex. Manual §12.6.
-- Usar copia aislada con un corte válido. Ejecutar el LX REAL: su CSV carece de tienda.
-- No simular C1 con una falla artificial.
-- Verificación local del archivo (antes de subir): la cabecera no contiene 'tienda'.
--   python -c "import csv; print(next(csv.reader(open('carga/Carga/datos/tobotex/LX/despacho_LX.csv'))))"
-- Esperado: RECHAZADO_ESQUEMA (o estado equivalente documentado), error de campo faltante,
-- mismo corte publicado, trusted sin datos de LX, hash/RunId conservados.
SELECT lote_id, intento, fuente, estado, filas_leadas, archivo
FROM ctl.lote WHERE lote_id = 'LX' ORDER BY intento, fuente;

SELECT fuente, lote_id, intento, clave, control, motivo
FROM quar.rechazo WHERE lote_id = 'LX' ORDER BY intento;

SELECT * FROM bi.v_corte_publicado;
SELECT corte_seq, corte_id, estado, publicado_utc FROM ctl.corte ORDER BY corte_seq;

-- Ningún movimiento de LX debe estar en trusted.
SELECT COUNT(*) AS filas_lx_en_trusted
FROM trusted.despacho WHERE lote_id = 'LX';

-- La recuperación se documenta en P5_recuperacion.sql con archivo corregido en carpeta nueva.
