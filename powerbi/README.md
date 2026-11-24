# Power BI — Especificación local

> **No se generó `.pbix`, ni capturas, ni publicación en Service.** Ver `ESTADO_LOCAL.md`.
> Los archivos siguientes son el procedimiento del manual §§9–10 pendiente de aplicar en Desktop.

| Archivo | Contenido |
|---|---|
| `medidas.dax` | K1–K6, metadatos, semáforos y medidas de fecha (§10.2–10.6). |
| `conexion_directquery.md` | Ruta principal DirectQuery, alternativa Import e informe previo (§9). |
| `modelo_relaciones.md` | Relaciones y reglas del modelo (§10.1). |
| `paginas.md` | Especificación de las cuatro páginas (§10.7). |
| `conciliacion.sql` | Consultas de conciliación SQL–Power BI tras L2 (§10.8). |
| `ESTADO_LOCAL.md` | Línea de corte y lo que falta para evidencia. |

## Requisitos (pendientes de aplicar)

- Conectar con `bi_reader`, nunca `sqladmin`; usar vistas `bi.*`.
- Crear primero `bi.v_dim_*` con `sql/fase3/20_dimensiones_powerbi.sql` (no ejecutado).
- Mostrar corte publicado, fecha/hora de publicación y períodos revisados.
- Para P6, capturas con filtro, corte y KPI conciliado al centavo.
- DirectQuery es la ruta principal; Import exige actualizar después de cada publicación.

`exportaciones/` queda vacía hasta que existan PDF/capturas reales.
