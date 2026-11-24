# Capítulo 3 — Procesamiento, calidad, seguridad y costos

> Borrador de estructura. Completar solo con evidencia verificable. No marcar como ejecutado sin RunId/consulta/captura.
>
> Preparación local disponible (sin ejecución en nube): `sql/fase3/` (calendario, C8 parametrizado,
> publicación reforzada, permisos, verificación y vistas de dimensiones), `adf/` (plantillas sin
> secretos), `powerbi/` (DAX, conexión, relaciones, páginas y conciliación) y `pruebas/consultas/`.
> No hay RunId, costos observados, capturas ni `.pbix`: todo lo que requiera ejecución permanece
> `PENDIENTE` y no debe redactarse en pasado. Ver `docs/estado_preparacion_fase3.md`.

## 3.1 Arquitectura y procesamiento

### 3.1.1 Comparación de diseños

| Criterio | Diseño A: ADLS + ADF + Azure SQL + Power BI | Diseño B: ADLS/Parquet + Synapse Serverless + Power BI |
|---|---|---|
| Costo | PENDIENTE (estimar con mismos supuestos) | PENDIENTE |
| Frecuencia/latencia | PENDIENTE | PENDIENTE |
| Operación | PENDIENTE | PENDIENTE |
| Seguridad | PENDIENTE | PENDIENTE |
| Adecuación al caso | PENDIENTE | PENDIENTE |

**Decisión:** PENDIENTE. Justificar con volumen, transacciones/publicación atómica y evidencia de costos.

### 3.1.2 Diagrama

- Insertar diagrama final: `evidencias/modelo/arquitectura_final.*`
- Incluir región, RG, identidades, conexiones y capas raw/stg/trusted/cur/bi/ctl/quar.

### 3.1.3 Flujo del pipeline

- Pipeline: `pl_cargar_lote` (parámetros `lote_id`, `caso`, `simular_falla`).
- Conservar `pipeline().RunId` en `ctl.lote`/bitácora.
- Describir actividades: iniciar, validar contrato, copiar staging, validar/merge, preparar hechos, simular falla, publicar/cerrar.

### 3.1.4 Contratos y evolución de esquema

- Contratos versionados en `contratos/`.
- Aceptar campos opcionales nuevos si mapeo los soporta.
- Rechazar campos requeridos ausentes/cambios incompatibles.

## 3.2 Calidad y publicación

### 3.2.1 Controles C1–C8

| Control | Regla | Umbral | Severidad | Acción | Evidencia |
|---|---|---|---|---|---|
| C1 |  |  |  |  |  |
| C2 |  |  |  |  |  |
| C3 |  |  |  |  |  |
| C4 |  |  |  |  |  |
| C5 |  |  |  |  |  |
| C6 |  |  |  |  |  |
| C7 |  |  |  |  |  |
| C8 | Rechazos por lote sobre el umbral bloquean; comparación estricta `>` | Tobotex `0.2000`; control adaptado `0.2500` (decisión propuesta, no regla oficial) | Bloqueo del lote con cuarentena conservada | `sql/fase3/01_merge_c8_parametrizado.sql`, `contratos/POLITICAS_CASO.md` | PENDIENTE (sin ejecución) |

### 3.2.2 Conciliación y versionado

- Fórmula: `recibidas = insertadas + actualizadas + omitidas + rechazadas`.
- Reenvío sin cambios: nuevo intento, sin nuevo corte.
- Versiones: superior actualiza; inferior omitida; misma versión contenido distinto a cuarentena.

### 3.2.3 Publicación atómica y recuperación

- Corte candidato, objetos `LISTO`, `sp_publicar_corte` transaccional, puntero `ctl.corte_vigente`.
- P5: esquema incompatible conserva corte anterior.
- P8: interrupción no publica mezcla; descarte restaura candidato; reintento publica corte completo.

## 3.3 Seguridad y costos

### 3.3.1 Identidades y permisos

| Identidad | Permisos | Prueba permitida | Prueba denegada | Evidencia |
|---|---|---|---|---|
| bi_reader |  |  |  |  |
| etl_loader |  |  |  |  |

### 3.3.2 Costos

| Componente | Estimado | Observado | Período | Evidencia |
|---|---:|---:|---|---|
| ADLS Gen2 |  |  |  |  |
| Data Factory |  |  |  |  |
| Azure SQL |  |  |  |  |
| Total |  |  |  |  |

### 3.3.3 Consultas equivalentes

| Consulta | Lecturas lógicas | CPU ms | Duración ms | Filas | Observación |
|---|---:|---:|---:|---:|---|
| A |  |  |  |  |  |
| B |  |  |  |  |  |

## 3.4 Pruebas

| ID | Caso | Lote | Intento | Corte | Regla | Esperado | Observado | Estado | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| P1 |  | L0 |  |  |  |  |  | PENDIENTE |  |
| P2 |  | L1 |  |  |  |  |  | PENDIENTE |  |
| P3 |  | L1 |  |  |  |  |  | PENDIENTE |  |
| P4 |  | L2 |  |  |  |  |  | PENDIENTE |  |
| P5 | Tobotex | LX |  |  |  |  |  | PENDIENTE |  |
| P6 | Tobotex | - |  |  |  |  |  | PENDIENTE |  |
| P7 | Tobotex | - |  |  |  |  |  | PENDIENTE |  |
| P8 |  | L3 |  |  |  |  |  | PENDIENTE |  |
