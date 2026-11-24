# Scripts SQL propuestos — Fase 3

> Versiones locales derivadas de `sql/Querys/`. `20_dimensiones_powerbi.sql` **sí fue ejecutado**
> en `sqldb-tobotex` el 23/11/2026 para habilitar Power BI. El resto permanece como propuesta:
> `sqldb-test` no existe y las bases del caso/no se han reemplazado.

| Orden | Archivo | Manual | Uso |
|---:|---|---|---|
| 1 | `00_calendario_2026.sql` | §4.3 | Siembra `cur.dim_fecha` para 2026 (falta en Query 6). |
| 2 | `01_merge_c8_parametrizado.sql` | §4.4, §8.3 | Reemplaza Query 10: C8 con `@umbral_rechazo`, comparación `>` y cuarentena antes del bloqueo. Tobotex `0.2000`, control `0.2500`. |
| 3 | `02_publicacion_reforzada.sql` | §4.5 | Reemplaza `ctl.sp_publicar_corte` de Query 11: bloqueo, estado candidato, objetos listos, lote no bloqueado, reconciliación y rollback. |
| 4 | `03_usuarios_permisos.sql` | §5.1 | GRANT/DENY para `etl_loader` y `bi_reader` en cada base. Sin secretos. |
| 5 | `04_verificacion_despliegue.sql` | §4.6, §12.1 | Comprobaciones de lectura posteriores al despliegue. |
| 6 | `20_dimensiones_powerbi.sql` | §9.1 | Vistas `bi.v_dim_*` para el lector BI. **Ejecutado en Tobotex.** |
| 7 | `21_control_dimensiones.sql` | §8.3 | Productos P1/P2 y motivo CONTROL en `sqldb-control`. |

## Decisiones documentadas

- `SIN_MOTIVO` se conserva con `es_valido = 0`: un reclamo sin motivo **no se rechaza**.
- El umbral `0.25` del control es una adaptación propuesta, no una regla oficial; si se exige
  20 % universal, registrar incompatibilidad y no declarar P2 control aprobada.
- La cuarentena se inserta fuera de la transacción de `trusted` para conservar rechazos de lotes
  bloqueados por C8 (manual §4.4.5).
- No reutilizar credenciales de `sql/Querys/SQL query 7.sql`.

La prevalidación de archivos y contratos está en `carga/Carga/` y `contratos/`.
