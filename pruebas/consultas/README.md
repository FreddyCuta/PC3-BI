# Consultas de verificación P1–P8

Versiones locales de las consultas de los manuales §12 y §8.4. La verificación inicial de relevo
sí se ejecutó en `sqldb-tobotex` y `sqldb-control` el 23/11/2026; el corte publicado real es
`corte_seq=6` / `C-20261123-06` y la base Control está vacía.

- Ejecutar cada archivo con el usuario indicado en el comentario (`bi_reader`, el usuario Entra de Power BI o administrador).
- Sustituir cualquier `1`/`TU_` por el `corte_seq`/nombre real antes de ejecutar; no inventarlos.
- Guardar la salida como `.csv` en `evidencias/Pn/<caso>/<intento>/<RunId>/` con la captura.
- Los valores `esperado` son del manual o del cálculo local previo, nunca un observado.
- Las variantes `_control` usan la base `sqldb-control` con datos adaptados y umbral C8 0.25.

Conciliación común: `00_conciliacion.sql`.
Consultas de seguridad/costo: `P7_A.sql`, `P7_B.sql`, `P7_EXCEPT.sql`, `P7_permisos.sql`.
Versiones ya parametrizadas con el corte real 6 (`C-20261123-06`), creadas el 23/11/2026:
`P7_A_corte6.sql`, `P7_B_corte6.sql`, `P7_EXCEPT_corte6.sql`. Úsalas para F3-09 sin editar el
placeholder `1`. Verificación realizada: A y B devuelven 8 filas idénticas; ambos `EXCEPT`
devuelven 0 filas y `filas_a = filas_b = 8`.

Variantes **`*_literal.sql`** (`P7_A_corte6_literal.sql`, `P7_B_corte6_literal.sql`,
`P7_EXCEPT_corte6_literal.sql`): misma lógica pero sin `DECLARE @corte`, con el `6` escrito en las
llamadas a `bi.fn_despacho`/`bi.fn_reclamo`. Se crearon porque DBeaver separa los statements por
`;` y pierde el ámbito de `@corte` (*Must declare the scalar variable*). Usa estas variantes en
DBeaver; en SSMS/Azure Data Studio sirve cualquiera.
Recuperación de esquema: `P5_recuperacion.sql`.

## Convención sugerida (de la versión original)

- `P1_conciliacion_tobotex.sql`, `P3_diff_antes_despues.sql`, `P4_scd2_evento_tardio.sql`,
  `P5_esquema_incompatible.sql`, `P6_k2_k3_conciliacion.sql`, `P7_permisos_y_except.sql`,
  `P8_estado_durante_falla.sql`: nombres alternativos si se prefiere agrupar por prueba.
- Incluir parámetros/corte/filtros usados.
- No incluir credenciales.
- Exportar el resultado junto a la consulta en la carpeta de evidencia correspondiente.
