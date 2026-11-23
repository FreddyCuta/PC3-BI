# Plan de pruebas P1–P8

> Plantilla de ejecución. No marcar `APROBADA` sin evidencia, consulta, RunId y resultado observado.

## Preparación común

- Conservar bases recibidas de Fase 2; no destruir evidencia.
- Crear bases/copia de prueba vacías con DDL + procedimientos + dimensiones iniciales.
- Registrar mapeo C0–C3 (etiqueta) vs `corte_seq`/`corte_id` real.
- Guardar por prueba: estado previo, parámetros, RunId, consulta, esperado, observado, veredicto, capturas.
- Bitácora: `pruebas/bitacora_pruebas.csv`.

## Matriz

| Prueba | Casos | Objetivo | Criterio de pase | Evidencia |
|---|---|---|---|---|
| P1 L0 | Tobotex, Control | Carga inicial | Conciliación OK, corte publicado, KPIs esperados | consultas, tablero, RunId |
| P2 L1 | Tobotex, Control | Incremental/versiones | Altas/actualizaciones/omitidas/rechazadas correctas | ctl.lote, quar.rechazo, KPIs |
| P3 L1 reenvío | Tobotex, Control | Idempotencia | Sin cambios en claves/KPIs/corte; nuevo intento | diff antes/después, ctl.lote |
| P4 L2 tardío | Tobotex, Control | Revisión histórica/SCD2 | Período afectado cambia; control no; histórico preservado | comparacion cortes, SCD2 |
| P5 LX | Tobotex | Esquema incompatible | `RECHAZADO_ESQUEMA`, corte intacto, recuperación en copia | error, ctl.lote, copia test |
| P6 K2/K3 | Tobotex | Conciliación BI | Independiente = SQL = tablero dentro de tolerancia | Excel/cálculo, SQL, captura |
| P7 Seguridad/costos/consultas | Tobotex | Acceso y operación | Permisos OK, EXCEPT vacío, costos registrados | SSMS, Cost Management, stats |
| P8 L3 interrupción | Tobotex, Control | Publicación atómica | Falla conserva corte anterior; recuperación publica completo | monitor ADF, ctl.corte, KPIs |

## Valores de control (Anexo E)

| Corte | Mes | Bruto | Devuelto | Neto |
|---|---|---:|---:|---:|
| C0 | Ene | 100.00 | 0.00 | 100.00 |
| C0 | Feb | 120.00 | 15.00 | 105.00 |
| C0 | Mar | 120.00 | 8.00 | 112.00 |
| C1 | Ene | 100.00 | 0.00 | 100.00 |
| C1 | Feb | 120.00 | 15.00 | 105.00 |
| C1 | Mar | 160.00 | 8.00 | 152.00 |
| C2 | Ene | 100.00 | 0.00 | 100.00 |
| C2 | Feb | 120.00 | 19.00 | 101.00 |
| C2 | Mar | 160.00 | 8.00 | 152.00 |
| C3 | Ene | 100.00 | 0.00 | 100.00 |
| C3 | Feb | 120.00 | 19.00 | 101.00 |
| C3 | Mar | 180.00 | 13.00 | 167.00 |

## Checklist de evidencia por prueba

- [ ] Parámetros usados (lote/caso/simular_falla).
- [ ] `pipeline().RunId` / ADF RunId.
- [ ] Consulta SQL ejecutada y resultado exportado.
- [ ] Captura con fecha/hora y contexto visible (sin secretos).
- [ ] Estado previo y posterior.
- [ ] Veredicto y explicación si falla.
