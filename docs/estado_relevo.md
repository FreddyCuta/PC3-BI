# Estado del relevo — Fase 2 a Fase 3

> Completar al recibir la Fase 2. No marcar como recibido/validado sin evidencia.

## 1. Resumen

| Campo | Valor |
|---|---|
| Fecha de relevo | PENDIENTE |
| Entrega Rolando/Fase 2 | PENDIENTE |
| Recibe Edward/Fase 3 | PENDIENTE |
| Repositorio | `git@github.com:FreddyCuta/PC3-BI.git` |
| Estado general | PENDIENTE |

## 2. Accesos y recursos

| Recurso | Nombre/ID | Acceso verificado | Evidencia | Observaciones |
|---|---|---|---|---|
| Suscripción Azure | PENDIENTE | No |  |  |
| Grupo de recursos | `rg-tobotex-pc3` | No |  |  |
| Región | PENDIENTE | No |  |  |
| ADLS Gen2 | `sttobotexpc3<ini>` | No |  |  |
| Contenedor raw | `raw` | No |  |  |
| SQL Server | `sql-tobotex-pc3-<ini>` | No |  |  |
| DB Tobotex | `sqldb-tobotex` | No |  |  |
| DB Control | `sqldb-control` | No |  |  |
| DB Test | `sqldb-test` | No |  |  |
| Data Factory | `adf-tobotex-pc3-<ini>` | No |  |  |
| Power BI | `.pbix` / Desktop | No |  |  |

## 3. Artefactos recibidos

| Artefacto | Ruta esperada | Recibido | Validado | Observaciones |
|---|---|---:|---:|---|
| Scripts SQL 00–09,11 | `sql/` | No | No |  |
| Scripts SQL control | `sql/control/` | No | No |  |
| Contratos | `contratos/` | No | No |  |
| Generadores semilla 2026 | `datos/generador/` | No | No |  |
| Lotes Tobotex L0-L3,LX | `datos/tobotex/` | No | No |  |
| Lotes control L0-L3 | `datos/control_anexoE/` | No | No |  |
| Manifiestos + SHA-256 | `datos/**/manifiesto.json` | No | No |  |
| Tablero Power BI | `powerbi/tobotex_pc3.pbix` | No | No |  |
| Capítulo 2 / anexos A,B,E | `informe/` o entrega externa | No | No |  |
| Presupuesto Freddy | `evidencias/costos/` | No | No |  |

## 4. Validación inicial (consultas de lectura)

Ejecutar en Tobotex y Control cuando aplique. Guardar salida en `evidencias/relevo/`.

```sql
SELECT DB_NAME() AS base_actual;
SELECT * FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM ctl.corte_vigente;
SELECT * FROM ctl.corte_objeto ORDER BY corte_seq, objeto;
SELECT * FROM bi.v_k1;
SELECT * FROM bi.v_k2;
SELECT * FROM bi.v_k3;
```

| Base | Ejecutado | Resultado | Evidencia |
|---|---:|---|---|
| sqldb-tobotex | No | PENDIENTE |  |
| sqldb-control | No | PENDIENTE |  |

## 5. Incidencias / bloqueos

| ID | Descripción | Impacto | Responsable | Estado | Evidencia |
|---|---|---|---|---|---|
| B-001 |  |  |  | Abierto/Cerrado |  |

## 6. Decisiones y ajustes al recibir

- PENDIENTE.
