# Anexo D — Inventario técnico y costos

## 1. Inventario técnico

| Componente | Servicio/recurso | Región | SKU/tier | Rol | Configuración relevante | Evidencia |
|---|---|---|---|---|---|---|
| Grupo de recursos | `rg-tobotex-pc3` |  |  | Contenedor |  |  |
| Almacenamiento raw | `sttobotexpc3<ini>` |  | Standard LRS / ADLS Gen2 | Raw | HNS habilitado |  |
| SQL Server | `sql-tobotex-pc3-<ini>` |  |  | Host lógico | Auth SQL, firewall controlado |  |
| DB Tobotex | `sqldb-tobotex` |  | Free/serverless | Caso propio | Auto-pause |  |
| DB Control | `sqldb-control` |  | Free/serverless | Anexo E | Auto-pause |  |
| DB Test | `sqldb-test` |  | Free/serverless | P5 recuperación | Auto-pause |  |
| Data Factory | `adf-tobotex-pc3-<ini>` |  | V2 | Orquestación | Managed Identity |  |
| Power BI | Desktop | N/A |  | Consumo | `bi_reader`, DirectQuery |  |

## 2. Costos

| Componente | Estimado mensual | Observado | Crédito consumido | Período | Medición/filtros | Evidencia |
|---|---:|---:|---:|---|---|---|
| ADLS Gen2 |  |  |  |  |  |  |
| Data Factory |  |  |  |  |  |  |
| Azure SQL |  |  |  |  |  |  |
| Otros |  |  |  |  |  |  |
| **Total** |  |  |  |  |  |  |

## 3. Observaciones

- Si no hay datos: `sin datos disponibles al consultar` + fecha/hora.
- Separar estimado, observado y crédito.
- Declarar tipo de cambio si se reporta en PEN.
