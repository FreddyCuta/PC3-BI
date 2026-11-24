# Checklist de entrega final

> Estado de la preparación local (antes del manual §2). Marcar `[x]` sólo cuando exista
> evidencia real; los elementos de nube/Power BI quedan `[ ]` a la espera de ejecución.

## Paquete

- [ ] PDF final del informe en `entregables/`.
- [x] Scripts SQL versionados en `sql/fase3/` y orden en `docs/estado_preparacion_fase3.md`.
- [ ] Ejecución de scripts SQL en `sqldb-test`, Tobotex y Control (PENDIENTE).
- [x] Contratos (`contratos/`) y prevalidación (`evidencias/relevo/`).
- [x] Datos y manifiestos originales conservados; adaptación versionada en `datos/control_adaptado/`.
- [x] Plantillas ADF en `adf/` (sin secretos; **no publicadas**).
- [ ] JSON exportado desde ADF después de `Publicar todo` (PENDIENTE).
- [ ] Tablero Power BI y exportación (`powerbi/`): **no hay `.pbix` ni capturas** (PENDIENTE).
- [x] Especificación Power BI: `medidas.dax`, `conexion_directquery.md`, `modelo_relaciones.md`, `paginas.md`, `conciliacion.sql`.
- [x] Bitácora con 14 filas `PENDIENTE` y consultas P1–P8 en `pruebas/consultas/`.
- [ ] Evidencias P1–P8 con RunId, resultados y capturas (PENDIENTE).
- [ ] Capítulo 3, conclusiones y anexos C/D/F completados con resultados observados (PENDIENTE).
- [x] Anexo E: valores esperados y adaptación documentada en `informe/anexo_e.md`, `contratos/POLITICAS_CASO.md`.
- [ ] Anexo E con columnas SQL vs. independente completas (PENDIENTE).
- [x] README reproducible sin secretos (plantillas con `TU_`).
- [ ] Demo ≤ 8 min con P3, P4, P6, P8 (PENDIENTE).

## Calidad

- [x] Ninguna afirmación "ejecutado" sin evidencia: valores de manual/cálculo local marcados como esperados.
- [x] Cortes etiquetados C0–C3 como expectativa, sin `corte_seq` inventado.
- [x] C8: `0.20` Tobotex, `0.25` control como decisión propuesta y documentada.
- [x] `SIN_MOTIVO` con `es_valido = 0` preservado; no se rechazan reclamos sin motivo.
- [ ] Cortes, fechas, unidades y cifras contrastados con resultados reales (PENDIENTE).
- [ ] Capturas sin secretos/IP/credenciales (PENDIENTE de revisión sobre capturas reales).
- [ ] Referencias APA 7 verificadas (PENDIENTE).
- [ ] Recursos Azure inventariados/eliminados tras entrega (PENDIENTE).
