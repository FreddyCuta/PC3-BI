# Consultas de verificación P1–P8

Versiones locales de las consultas de los manuales §12 y §8.4. **Ninguna fue ejecutada** contra
Azure SQL en esta preparación: no hay base, credenciales ni resultados observados.

- Ejecutar cada archivo con el usuario indicado en el comentario (`bi_reader` o administrador).
- Sustituir cualquier `1`/`TU_` por el `corte_seq`/nombre real antes de ejecutar; no inventarlos.
- Guardar la salida como `.csv` en `evidencias/Pn/<caso>/<intento>/<RunId>/` con la captura.
- Los valores `esperado` son del manual o del cálculo local previo, nunca un observado.
- Las variantes `_control` usan la base `sqldb-control` con datos adaptados y umbral C8 0.25.

Conciliación común: `00_conciliacion.sql`.
Consultas de seguridad/costo: `P7_A.sql`, `P7_B.sql`, `P7_EXCEPT.sql`, `P7_permisos.sql`.
Recuperación de esquema: `P5_recuperacion.sql`.

## Convención sugerida (de la versión original)

- `P1_conciliacion_tobotex.sql`, `P3_diff_antes_despues.sql`, `P4_scd2_evento_tardio.sql`,
  `P5_esquema_incompatible.sql`, `P6_k2_k3_conciliacion.sql`, `P7_permisos_y_except.sql`,
  `P8_estado_durante_falla.sql`: nombres alternativos si se prefiere agrupar por prueba.
- Incluir parámetros/corte/filtros usados.
- No incluir credenciales.
- Exportar el resultado junto a la consulta en la carpeta de evidencia correspondiente.
