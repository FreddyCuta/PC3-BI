# Carga manual registrada

Este directorio contiene el respaldo de carga manual (`cargar_lote.py`) que invoca los mismos procedimientos SQL en el mismo orden que ADF.

## Uso esperado

- Configurar conexión por variable de entorno (ej. `AZ_SQL_CONN`), nunca hardcodear secretos.
- Ejecutar por lote y registrar salida en `evidencias/`.
- Mantener paridad con pipeline: iniciar lote, validar contrato, cargar stg, merge trusted, abrir/preparar/publicar corte, marcar fallas.

## Evidencia

Guardar logs con nombre: `evidencias/relevo/` o `evidencias/Px/carga_manual_<lote>_<intento>.txt`.
