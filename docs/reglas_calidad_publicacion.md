# Reglas de calidad, conciliación y publicación

> Fuente operativa para implementación y Capítulo 3.2. Registrar cualquier desviación respecto a Fase 2.

## 1. Controles C1–C8

| Control | Comprobación | Acción | Severidad | Evidencia esperada |
|---|---|---|---|---|
| C1 | Estructura requerida y compatibilidad de tipos | Bloquea lote incompatible | Bloqueante | `RECHAZADO_ESQUEMA`, mensaje, RunId |
| C2 | Clave, versión y contenido idénticos | Omite duplicado | Aislable | Conteo omitidas, intento registrado |
| C3 | Misma clave y versión, contenido distinto | Cuarentena | Aislable | `quar.rechazo`, hash, fila |
| C4 | Campo requerido nulo/vacío/tipo inválido | Cuarentena | Aislable | Rechazo por campo/control |
| C5 | Cantidad/importe positivos; dominios válidos | Cuarentena; excepción K6 documentada | Aislable | Rechazo + regla documentada |
| C6 | Tienda válida y movimiento del reclamo existente | Cuarentena | Aislable | Rechazo referencial |
| C7 | Evento válido afecta período cerrado | Marca período revisado / cuarentena >90 días | Informativo/Aislable | `ctl.periodo_revisado` o cuarentena |
| C8 | `rechazadas / recibidas > 0,20` | Bloquea publicación | Bloqueante | Conteos por fuente e intento |

## 2. Reglas acordadas / ambigüedades cerradas

- Esquemas: `stg`, `trusted`, `cur`, `bi`, `ctl`, `quar`.
- Fechas de negocio: America/Lima. Auditoría: UTC. No convertir fechas sin hora como instantes UTC.
- Cierre mensual: día 5 siguiente. Correcciones aceptadas hasta 90 días después del cierre.
- Corrección posterior a 90 días: cuarentena y revisión manual (regla adicional acordada).
- Motivo vacío: aceptar como `SIN_CODIFICAR`, fuera del numerador K6. Código no vacío desconocido: cuarentena.
- Versionado: versión superior válida actualiza; inferior se omite; misma versión con contenido distinto se rechaza.
- Reenvío sin cambios válidos: nuevo intento, **sin nuevo corte**.
- Publicación: incluye ambos hechos y dimensiones/agregados cuya interpretación cambie.

## 3. Conciliación

Fórmula por fuente e intento:

```text
recibidas = insertadas + actualizadas + omitidas + rechazadas
```

Consulta base:

```sql
SELECT lote_id, fuente, intento,
       filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech,
       filas_leidas - (filas_ins + filas_upd + filas_omit + filas_rech) AS diferencia
FROM ctl.lote
ORDER BY lote_id, intento, fuente;
```

**Aceptación:** `diferencia = 0` en intentos que terminaron clasificación. Fallas antes de clasificar deben declarar conteos desconocidos.

## 4. Publicación atómica

1. Abrir corte candidato.
2. Preparar hechos con `corte_desde = candidato`.
3. Cerrar versiones anteriores con `corte_hasta = candidato`.
4. Registrar `ctl.corte_objeto` con objetos requeridos y conteos.
5. Marcar `LISTO` solo con validación completa.
6. `ctl.sp_publicar_corte`: transacción única, verifica estado candidato, objetos requeridos exactos, controla aprobado y puntero `id=1`.
7. Commit: actualiza estado corte y `ctl.corte_vigente`. Error: rollback y diagnóstico.

## 5. Recuperación / descarte

- Descarte transaccional solo para candidatos no publicados.
- Eliminar inserciones del candidato, restaurar `corte_hasta` previo exacto.
- Restaurar/aislar cambios en `trusted` y dimensiones afectadas.
- Conservar intento fallido y estado `DESCARTADO`.
- Reintento idempotente desde datos originales.

## 6. Historial y consultas por corte

```sql
DECLARE @corte INT = <corte_seq>;
SELECT *
FROM cur.fact_despacho
WHERE corte_desde <= @corte
  AND (corte_hasta IS NULL OR corte_hasta > @corte);
```

No sobrescribir atributos dimensionales usados por cortes anteriores; usar SCD o versionado según impacto.
