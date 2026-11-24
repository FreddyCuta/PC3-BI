# Especificación de páginas del informe (manual §10.7)

> Estado local: especificación de construcción. **No hay capturas ni `.pbix`** en el repo.
> Cada página debe guardarse con captura que muestre filtros, corte y fecha/hora, sin secretos.
> Añadir en todas: nota de **datos simulados** y etiqueta de estado textual además del color.

## Página 1 — Resumen ejecutivo

- Segmentador `Fecha[periodo]` con selección única.
- Segmentadores `Tienda[tienda]` y `Marca[marca_codigo]`.
- Tarjetas: `K1 bruto PEN`, `K2 neto PEN`, `K3 tasa devolución`, `K4 variación mensual`.
- Serie mensual con K1 y K2.
- Tarjetas de metadatos: `Corte visible`, `Publicación Lima`, `Estado del período`,
  `Estado de revisión` y texto `Evaluación simulada: 27/10/2026`.
- Usar **Editar interacciones** para que la selección única de mes no reduzca la serie a un
  punto; anotar que la serie muestra evolución completa bajo filtros de tienda/marca.
- Desactivar unidades automáticas K/M en tarjetas; mostrar dos decimales.

## Página 2 — Calidad y diagnóstico

- Tarjetas `K3 tasa devolución` y `K6 motivo codificado`.
- Barras por `Marca[marca_codigo]` con K3.
- Barras por `Reclamo[motivo]` con número de reclamos.
- Tabla de reclamos: id, movimiento, fecha, tienda, motivo e importe.
- Filtrar por dimensiones compartidas.
- No interpretar K3 global con filtro de motivo: el motivo filtra devoluciones, no bruto.
  Si se usa, rotular como *contribución del motivo al bruto total*.

## Página 3 — Cumplimiento y faltantes

- Tarjeta `K5 cumplimiento` y fecha límite elegida.
- Carga adicional `bi.v_k5` como `LineasCorte` (sin filtro temporal).
- Relacionar Tienda y Marca con `LineasCorte`; **no** relacionar Fecha.
- Tabla: contrato, detalle, tienda, marca, contratada, despachada y faltante.
- Filtro `faltante > 0` y Top N = 10 por suma de faltante.
- Título: **Top 10 faltantes al corte completo**.
- Nota: K5 temporal y la tabla pueden tener alcances temporales distintos; para comparabilidad
  usar esta página sin filtro temporal y K5 sobre todo el corte.

## Página 4 — Revisión y trazabilidad

- Matriz de `Comparacion`: filas período; columnas `corte_id`; valores bruto, devuelto y neto.
- Usar filtros de `Comparacion` en esta página: es total empresa, sin tienda/marca.
  No simular que los segmentadores de tienda cambian esa comparación.
- Tabla de `Revisiones`.
- Tabla de despachos: id, versión, contrato, detalle, fecha e importe.
- Guardar capturas de septiembre antes/después de L2 (P4).

## Semáforos

Aplicar color condicional por **Field value / Valor de campo** con `Color K3` y `Color K5`
de `medidas.dax`. Añadir siempre etiqueta de estado: el significado no debe depender sólo del color.
Umbrales: K3 verde ≤ 3 %, ámbar ≤ 5 %, rojo > 5 %; K5 verde ≥ 98 %, ámbar ≥ 95 %, rojo < 95 %;
gris sin base (BLANK).
