# Estado local de Power BI

- **No se generó ningún `.pbix`.** No hay Power BI Desktop, licencia, credenciales ni base
  publicada en este entorno; no se abrió Power BI Service ni se publicó informe/dashboard.
- No hay capturas, PDF ni exportaciones en `powerbi/exportaciones/`.
- No se registraron nombres reales de servidor, base, workspace ni fechas/hora de publicación.
- Los archivos `medidas.dax`, `conexion_directquery.md`, `modelo_relaciones.md`, `paginas.md`
  y `conciliacion.sql` son versiones locales del manual §§9–10,**pendientes de aplicar**.
- La ruta principal es **DirectQuery**; **Import** es alternativa con actualización manual
  después de publicar (manual §§9.3, 11.3).
- Toda cifra de KPI en estos documentos es referencia de cálculo local previo o valor
  **esperado** del manual. No debe citarse como valor observado en SQL/Power BI.
- Las evidencias P6/P7/P8 requieren captura real con corte, filtros y RunId; se registran
  como `PENDIENTE` en `pruebas/bitacora_pruebas.csv` hasta su ejecución.
