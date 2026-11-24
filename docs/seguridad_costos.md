# Seguridad y costos

## 1. Seguridad

### Identidades

| Identidad | Uso | Permisos esperados | Prohibido |
|---|---|---|---|
| `tobotex` | Administración/DDL (admin SQL real del servidor) | Control total en servidor/DB | Uso rutinario en Power BI/ETL |
| `etl_loader` | ADF/carga manual | DML en `stg`, EXEC procedimientos necesarios, lectura control | Acceso amplio innecesario a `bi` como admin |
| `bi_reader` | Power BI/consumo (SQL Auth alternativo) | `SELECT` en esquema `bi` | SELECT en `stg/trusted/quar/cur/ctl`, escritura |
| `edward_oliva2002@outlook.com` | Power BI recomendado (Entra contenido) | `SELECT` en `bi`; `DENY` en `ctl/cur/quar/stg/trusted` | Uso de la cuenta admin para consumo |
| Managed Identity ADF (`fac126e9-2556-4393-90c2-cd3841fe5926`) | Lectura raw | Storage Blob Data Reader en ADLS raw | Escritura fuera de lo requerido. **No se encontró asignada; asignarla antes de ejecutar ADF** |

### Pruebas mínimas

```sql
-- Como bi_reader (debe funcionar)
SELECT TOP (5) * FROM bi.v_k1;

-- Como bi_reader (debe fallar)
SELECT TOP (5) * FROM stg.despacho;
SELECT TOP (5) * FROM cur.fact_despacho;
```

Registrar: usuario, base, consulta, resultado, mensaje de error, captura sin secretos.
Para el usuario de Entra, verificar sus permisos en `sys.database_permissions`; la suplantación
`EXECUTE AS USER` con ese usuario contenido no cambió `USER_NAME()` en la comprobación realizada.

## 2. Costos

### Fuentes

- Presupuesto estimado Freddy: `evidencias/costos/presupuesto_freddy.*`
- Cost Management: export CSV/JSON + captura con filtros, moneda y fecha.

### Tabla Anexo D (plantilla)

| Componente | Servicio Azure | Región | SKU/tier | Rol | Volumen supuesto | Costo estimado | Costo observado | Período | Fuente/evidencia |
|---|---|---|---|---|---|---:|---:|---|---|
| Raw | ADLS Gen2 |  |  | Almacenamiento lotes |  |  |  |  |  |
| Orquestación | Data Factory |  |  | Pipelines/activities |  |  |  |  |  |
| BD Tobotex | Azure SQL DB |  |  | Transformación/publicación |  |  |  |  |  |
| BD Control | Azure SQL DB |  |  | Validación Anexo E |  |  |  |  |  |
| BD Test | Azure SQL DB |  |  | Recuperación P5 |  |  |  |  |  |
| BI | Power BI Desktop | N/A |  | Consumo local/export |  |  |  |  |  |

### Reglas de reporte

- Separar **estimado mensual**, **observado** y **crédito consumido**.
- Si no hay cargos visibles: `sin datos disponibles al consultar`, con fecha/hora.
- Para PEN declarar tipo de cambio, fuente y fecha; no inventar tasa.
- Incluir consultas comparadas P7 y métricas (lecturas lógicas, CPU, duración, filas).
