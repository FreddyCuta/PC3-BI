# Capítulo 2 — Fuentes, modelo, KPIs y tablero

> Responsable: Rolando (Fase 2). Completar con evidencia real en Azure/SQL/Power BI.
>
> La especificación local del tablero está en `powerbi/` (`medidas.dax`, `modelo_relaciones.md`,
> `paginas.md`, `conexion_directquery.md`, `conciliacion.sql`). **No se generó `.pbix`**: las
> relaciones, medidas y páginas están pendientes de aplicar y capturar. Cualquier KPI citado en
> este capítulo debe contrastarse con la salida real de `bi.*`.

## 2.1 Fuentes y cortes

- [ ] Tabla de fuentes F1–F3 con propietario, ubicación, esquema, volumen, claves, zona horaria, frecuencia, sensibilidad.
- [ ] Tres fechas por fuente: evento, actualización origen, ingesta.
- [ ] Regla de empate de versión y política de corte `C-AAAAMMDD-NN`.
- [ ] Reglas de simulación y semilla 2026.

## 2.2 Modelo dimensional

- [ ] Declarar grano de `fact_despacho` y `fact_reclamo`.
- [ ] Dimensiones, claves negocio/sustitutas, cardinalidad, conformadas.
- [ ] Aditividad de medidas.
- [ ] Demostración SCD2 tienda LEO y evento tardío L2.
- [ ] Prueba de granularidad: K1 separado, unión ingenua inflada, combinación alineada.

## 2.3 Diseño de indicadores

Completar ficha por K1–K6: decisión, cálculo, tiempo, linaje, objeto SQL, visual, meta.

## 2.4 Cálculo y conciliación

- [ ] KPIs críticos K2 y K3: cálculo independiente, SQL, tablero.
- [ ] Tolerancia declarada antes de ejecutar.
- [ ] Total de razones = suma numeradores / suma denominadores.

## 2.5 Tablero y conclusiones

- [ ] Página ejecutiva y diagnóstico.
- [ ] Filtros mes/tienda, meta, corte visible, períodos revisados.
- [ ] Tres hallazgos cuantificados con acción.
