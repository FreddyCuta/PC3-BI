# Azure Data Factory — Plantillas locales

> **No exportadas desde ADF ni publicadas.** Los JSON de esta carpeta son plantillas versionadas
> del manual §6, con nombres `TU_` y sin secretos. Deben importarse/validarse en ADF Studio y
> reemplazarse por el JSON exportado tras `Publicar todo`. Conservar `pipeline().RunId`.

## Estructura real

- `linked_services/`: `ls_adls.json`, `ls_sql_tobotex.json`, `ls_sql_control.json`, `ls_sql_test.json`.
  Todos usan Managed Identity; sin contraseñas ni cadenas reales.
- `datasets/`: `ds_manifiesto.json`, `ds_csv.json`, `ds_jsonl.json`, `ds_sql_query*.json`,
  `ds_stg_{tienda,despacho,reclamo}{,_control,_test}.json`.
- `pipelines/`: `pl_cargar_lote.json` (Switch por `caso`, concurrencia 1), `pl_tobotex.json`,
  `pl_control.json`, `pl_registrar_falla.json`, `pl_registrar_falla_control.json`.
- `triggers/`: vacío; triggers deshabilitados por defecto si no se usan.

## Convenciones

- Parámetros mínimos: `lote_id`, `caso` (`tobotex|control`), `fecha_recepcion`, `simular_falla`.
- C8: `0.2000` en Tobotex; `0.2500` en control (decisión propuesta, ver `contratos/POLITICAS_CASO.md`).
- `sp_iniciar_lote` limpia staging compartido: ADF y carga manual deben ejecutarse en serie.
- `sp_abrir_corte` devuelve `-1` cuando no hay cambios: es terminación limpia, no error.
- Las ramas de fallo registran el error y terminan en actividad `Fail`; no convierten en éxito.
- `pl_control` apunta a `rawcontrol` y a `ls_sql_control`, con datos `control_adaptado`.

## Checklist de publicación (PENDIENTE en su totalidad)

- [ ] Sustituir nombres `TU_` por reales y validar linked services.
- [ ] Managed Identity ADF con `Storage Blob Data Reader` en `raw` y `rawcontrol`.
- [ ] `etl_loader` con permisos mínimos en cada base (`sql/fase3/03_usuarios_permisos.sql`).
- [ ] Verificar en Debug la forma en que ADF expone `structure` y las propiedades del manifiesto.
- [ ] Publicar todo, ejecutar, conservar RunId y exportar JSON resultante al repo.
- [ ] Confirmar que el JSON exportado no contiene contraseñas.
