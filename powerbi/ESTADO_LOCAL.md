# Estado local de Power BI

- **No se generó ningún `.pbix`.** No se abrió Power BI Service ni se publicó informe/dashboard.
- No hay capturas, PDF ni exportaciones en `powerbi/exportaciones/`.
- SQL sí está preparado: servidor `sql-tobotex-pc3.database.windows.net`, base `sqldb-tobotex`,
  vistas `bi.v_dim_*` creadas y usuario Entra `edward_oliva2002@outlook.com` con acceso de sólo lectura.
- Workspace de Service: PENDIENTE. Publicación del corte observada: `C-20261123-06` (`corte_seq=6`).
- Los archivos `medidas.dax`, `conexion_directquery.md`, `modelo_relaciones.md`, `paginas.md`,
  `conciliacion.sql` y `figuras_evidencia.md` son versiones locales del manual §§9–10,
  **pendientes de aplicar en Desktop**.
- La ruta principal es **DirectQuery**; **Import** es alternativa con actualización manual
  después de publicar (manual §§9.3, 11.3).
- Toda cifra de KPI en estos documentos es referencia de cálculo local previo o valor
  **esperado** del manual. No debe citarse como valor observado en SQL/Power BI.
- Las evidencias P6/P7/P8 requieren captura real con corte, filtros y RunId; se registran
  como `PENDIENTE` en `pruebas/bitacora_pruebas.csv` hasta su ejecución.
