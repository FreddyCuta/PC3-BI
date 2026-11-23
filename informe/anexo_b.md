# Anexo B — Fichas de KPIs

> Una ficha por KPI. Completar con versión SQL, vista BI y visual.

## K1 — Despacho bruto PEN
- Tipo: Aditiva
- Decisión: D3
- Fórmula: `SUM(importe_pen)` por mes de salida, movimientos vigentes.
- Meta/umbral: PENDIENTE
- Objeto SQL: `bi.v_k1`
- Visual: PENDIENTE
- Linaje: F1 despacho -> stg/trusted/cur.fact_despacho -> bi.v_k1

## K2 — Despacho neto PEN
- Tipo: Integra ambos hechos
- Decisión: D3
- Fórmula: `bruto - devuelto`, agregando cada hecho por mes/tienda antes de combinar.
- Meta/umbral: PENDIENTE
- Objeto SQL: `bi.v_k2`
- Visual: PENDIENTE

## K3 — Tasa de devolución
- Tipo: Razón
- Decisión: D2
- Fórmula: `SUM(devuelto) / NULLIF(SUM(despachado),0)`
- Meta/umbral: PENDIENTE
- Objeto SQL: `bi.v_k3`

## K4 — Variación mensual despacho bruto
- Tipo: Variación
- Decisión: D3
- Fórmula: `(K1_mes - K1_mes_anterior)/NULLIF(K1_mes_anterior,0)`
- Objeto SQL: `bi.v_k4`

## K5 — Cumplimiento de cantidad
- Tipo: Razón
- Decisión: D1
- Fórmula: `SUM(min(despachada, contratada))/SUM(contratada)` por línea contractual.
- Objeto SQL: `bi.v_k5`

## K6 — Reclamos con motivo codificado
- Tipo: Razón
- Decisión: D2
- Fórmula: `SUM(motivo_valido)/NULLIF(COUNT(*),0)`
- Objeto SQL: `bi.v_k6`
