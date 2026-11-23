# Azure Data Factory — Artefactos

Colocar aquí los JSON exportados de ADF. No incluir secretos en linked services.

## Estructura

- `linked_services/`: `ls_adls.json`, `ls_sql.json` (placeholders, Key Vault o referencias seguras).
- `datasets/`: `ds_csv.json`, `ds_jsonl.json`, `ds_sql.json`.
- `pipelines/`: `pl_cargar_lote.json`, `pl_cuerpo_lote.json` (y variantes control si aplica).
- `triggers/`: triggers programados; deshabilitados por defecto si no se usan.

## Convenciones

- Pipeline principal: `pl_cargar_lote`.
- Parámetros mínimos: `lote_id`, `caso` (`tobotex|control`), `simular_falla` (``, `tras_despacho`, `esquema`).
- Conservar `pipeline().RunId` y registrarlo en `ctl.lote`/bitácora.
- Concurrencia recomendada: 1.
- Exportar después de `Publicar todo` y validar JSON en repo.

## Checklist de publicación

- [ ] Linked services prueban conexión.
- [ ] Managed Identity ADF tiene `Storage Blob Data Reader` en ADLS.
- [ ] `etl_loader` tiene permisos mínimos en SQL.
- [ ] Fallos terminan en actividad `Fail` tras registrar error.
- [ ] JSON exportado sin contraseñas.
