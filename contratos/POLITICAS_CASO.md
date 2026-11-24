# Políticas por caso y decisiones documentadas

Documento de trabajo derivado de `MANUAL_FASE_3_AZURE_POWER_BI.md` §3.2, §4.4 y §8.1. Las decisiones marcadas como **propuesta** requieren confirmación con el enunciado oficial antes de asignar nota.

## 1. Control de rechazos C8

| Caso | Umbral | Comparación | Estado |
|---|---:|---|---|
| Tobotex | 0,20 | `>` | Según código entregado (Query 10) |
| Control Anexo E | 0,25 | `>` | **Propuesta documentada**, no regla del enunciado |

Justificación de la propuesta: L1 de control tiene 4 ventas, 1 inválida (25 %). Con 0,20 el lote se bloquea y no puede producir el corte esperado del Anexo E. Con comparación estricta `>`, exactamente 25 % no bloquea. No se modifican los archivos originales para ocultar el rechazo. Si el docente exige 0,20 universal, se registra incompatibilidad y P2 control queda como `PENDIENTE/NO APROBADA`.

Implementación: parámetro `@umbral_rechazo DECIMAL(5,4) = 0.2000` en `trusted.sp_merge_despacho` y `trusted.sp_merge_reclamo` (`sql/fase3/01_merge_c8_parametrizado.sql`). El cargador manual omite el parámetro por defecto y acepta `--umbral 0.25` para control. ADF envía 0,20 o 0,25 según el caso.

## 2. Motivos de reclamo (K6)

- Los motivos vacíos o fuera de catálogo se conservan como `SIN_MOTIVO` con `es_valido = 0` (`SQL query 6.sql` ya siembra ese miembro).
- K6 mide reclamos válidos con motivo codificado sobre **todos** los reclamos válidos, incluidos los que tienen `SIN_MOTIVO` en el denominador.
- Rechazar esos reclamos elevaría artificialmente K6: **no se hace**.

## 3. Fecha de recepción y ventana C7

| Lote Tobotex | Recepcion simulada |
|---|---|
| L0 | 2026-10-01 |
| L1 | 2026-10-04 |
| L2 | 2026-10-20 |
| L3 | 2026-10-01 (según manifiesto entregado) |

La fecha de negocio no se desplaza por la recepción. L2 modifica septiembre aunque llega en octubre. La ventana de corrección de 90 días se evalúa contra la recepción simulada, nunca contra `GETDATE()`.

Control: las fechas de recepción del adaptador (`2026-04-01`, `04-04`, `04-20`, `04-27`) son **supuestos de prueba** declarados en el manifiesto adaptado, no datos originales.

## 4. Hashes y manifiestos (incidencia B-001)

- Los CSV de Tobotex tienen distinto tamaño y SHA-256 que los manifiestos porque unos usan LF y otros CRLF; el número de filas coincide.
- `carga/Carga/verificar_archivos.py --permitir-crlf` registra la equivalencia y escribe `evidencias/relevo/verificacion_archivos.json`.
- No se reescriben los originales. Si se decide regenerar manifiestos, debe hacerse como nueva versión de entrega con su propio hash y fecha.

## 5. JSONL (C1)

- Prevalidación manual local con `carga/Carga/validar_jsonl.py`; informe en `evidencias/relevo/validacion_jsonl.json`.
- ADF debe inspeccionar cada objeto (Lookup sin `firstRowOnly` + ForEach, o Azure Function). Si el dataset normaliza propiedades ausentes a NULL, `contains` no prueba ausencia en origen: **no marcar C1 como cubierto** sin esa comprobación.

## 6. Otras decisiones que afectan la validación

1. Calendario 2026 completo (365 fechas) antes de preparar hechos.
2. Publicación endurecida propuesta en `sql/fase3/02_publicacion_reforzada.sql`; validar en `sqldb-test`.
3. No usar `periodo_ultimo_despacho` de `bi.v_k5` como cierre histórico.
4. K4 del tablero usa medida DAX sobre calendario continuo, no `LAG` de `bi.v_k4` sobre meses existentes.
5. Un lote **solo de tienda** no está cubierto por el mecanismo actual de publicación: no declararlo validado.
6. La recuperación de P8 se demuestra con L3, que no cambia tiendas.
