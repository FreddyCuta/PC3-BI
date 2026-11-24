# Estado del relevo — Fase 2 a Fase 3

> Estado actualizado con **verificación real de Azure (23/11/2026)** mediante Azure MCP y `az CLI` de sólo lectura, más la preparación SQL descrita en `powerbi/conexion_directquery.md`. Sigue sin haber `.pbix`, publicación en Power BI Service ni escrituras en Azure distintas de las indicadas en §7.

## 1. Resumen

| Campo | Valor |
|---|---|
| Fecha de relevo | PENDIENTE de registrar con fecha real |
| Entrega Rolando/Fase 2 | PENDIENTE de confirmar (SQL, datos y cálculo local están en el repo) |
| Recibe Edward/Fase 3 | PENDIENTE de confirmar |
| Repositorio | `git@github.com:FreddyCuta/PC3-BI.git` |
| Estado general | Preparación local completa; ejecución cloud y Power BI **pendientes** |

## 2. Accesos y recursos

| Recurso | Nombre/ID | Estado | Acceso verificado | Evidencia | Observaciones |
|---|---|---|---|---|---|
| Suscripción Azure | `f57db137-2f2a-49e8-83f3-990b2c786c01` (Azure for Students) | Verificada | Sí | `az account show` + MCP | Tenant `dee9f998-d159-442c-a88d-f1171c748fa5` |
| Grupo de recursos | `rg-tobotex-pc3` | Verificado | Sí | `group_list` | También existen `cartrune-rg`, `cartrune-rg-chile`, `NetworkWatcherRG` |
| Región | `chilecentral` | Verificada | Sí | `group_resource_list` | Confirmada en los recursos del caso |
| ADLS Gen2 | `sttobotexpc3` | Verificado | Sí | ARM REST | HNS activado, `Standard_LRS`, `StorageV2` |
| Contenedor caso | `raw` | Verificado | Sí | ARM REST | `publicAccess=None` |
| Contenedor control | `rawcontrol` | Verificado | Sí | ARM REST | `publicAccess=None`; también existe `quarantine` |
| SQL Server | `sql-tobotex-pc3` | Verificado | Sí | `sql_server_get` | `sql-tobotex-pc3.database.windows.net`; admin SQL `tobotex`; admin Entra `edward_oliva2002@outlook.com` |
| DB Tobotex | `sqldb-tobotex` | Verificada | Sí | T-SQL | 20 tablas, 12 procedimientos, 12 vistas; corte publicado 6 (`C-20261123-06`) |
| DB Control | `sqldb-control` | Verificada | Sí | T-SQL | Vacía: 0 tablas, 0 procedimientos, 1 vista; umbral C8 propuesto 0,25 |
| DB Test | `sqldb-test` | **No existe** | No | `sql_db_get` | No se creó; no es necesaria para conectar Power BI a Tobotex |
| Data Factory | `adf-tobotex-pc3` | Verificado | Sí | ARM REST | Pipeline publicado:`pl_ingestar_lote_tobotex` |
| Identidad ADF | `fac126e9-2556-4393-90c2-cd3841fe5926` | Verificada | Sí | ARM REST | No se encontró asignación de `Storage Blob Data Reader` en Storage; otorgarla antes de ejecutar ADF |
| Usuario ingesta | `etl_loader` | Verificado | Sí | T-SQL | Permisos presentes en Tobotex; secreto no versionado |
| Usuario lectura SQL | `bi_reader` | Verificado | Sí | T-SQL | `SELECT` en `bi`; `DENY` en `cur`, `stg`, `trusted`, `quar`, `ctl` |
| Usuario lectura Entra | `edward_oliva2002@outlook.com` | Creado en Tobotex | Sí | T-SQL | Contained user; mismo patrón de permisos que `bi_reader`; sin contraseña nueva |
| Power BI | `powerbi/tobotex_pc3.pbix` | No creado | No |  | SQL listo; falta construir `.pbix` en Desktop con DirectQuery |

## 3. Artefactos recibidos / preparados localmente

| Artefacto | Ruta | Recibido | Preparado en esta revisión | Validado en cloud | Observaciones |
|---|---|---:|---:|---:|---|
| Scripts SQL originales | `sql/Querys/SQL query 1..17.sql` | Sí | No | No | Query 7 contiene secretos literales: no ejecutar tal cual |
| Scripts fase 3 | `sql/fase3/` | No | Sí | No | Calendario, C8, publicación, permisos, dimensiones BI |
| Generador y cálculo | `carga/Carga/datos/generador/` | Sí | No | No | Salida local en `revision_fase3/` (fuera del repo) |
| Lotes Tobotex L0–L3, LX | `carga/Carga/datos/tobotex/` | Sí | No | No | Manifiestos con SHA-256; CSV difieren por LF/CRLF |
| Lotes control L0–L3 | `carga/Carga/datos/control_anexoE/` | Sí | No | No | Formato propio del Anexo E |
| Adaptación control | `carga/Carga/datos/control_adaptado/` | No | Sí | No | Generada por `adaptar_control.py`; no altera originales |
| Contratos | `contratos/*_v1.0.json` | No | Sí | No | Derivados de `ctl.contrato_campo` (Query 6) |
| Cargador manual | `carga/Carga/carga/cargar_lote.py` | Sí | Sí (opción `--umbral`) | No | Respaldo; no sustituye evidencia ADF |
| ADF JSON | `adf/` | No | Sí (plantillas sin secretos) | No | Publicar desde Studio y exportar versión real |
| Power BI | `powerbi/` | No | Sí (DAX, modelo y conexión) | No | Requiere Windows/Desktop para construir `.pbix` |
| Consultas P1–P8 | `pruebas/consultas/` | No | Sí | No | Esperados documentados; observados vacíos |
| Tablero `.pbix` | `powerbi/tobotex_pc3.pbix` | No | No | No | No encontrado en el repositorio |
| Cap. 2 / anexos A, B, E | `informe/` | Sí (borradores) | No | No | Conservar; corregir portada Grupo 11/Grupo 8 |
| Presupuesto | `evidencias/costos/` | No | No | No | Captura pendiente |

## 4. Validación inicial (consultas de lectura)

Ejecutada en `sqldb-tobotex` y `sqldb-control` con token de `az CLI`. La salida no se guardó como archivo; los resultados se resumen abajo y las consultas para repetirla están en `pruebas/consultas/00_conciliacion.sql`. No se ejecutó en `sqldb-test` porque no existe.

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
| sqldb-test | No | No existe | `sql_db_get` |
| sqldb-tobotex | Sí | 20 tablas / 12 procs / 12 vistas; `corte_vigente=6`; `fact_despacho=658`, `fact_reclamo=55`, `dim_fecha=365` | consulta T-SQL de relevo |
| sqldb-control | Sí | 0 tablas / 0 procs / 1 vista | consulta T-SQL de relevo |

## 5. Incidencias / bloqueos

| ID | Descripción | Impacto | Responsable | Estado | Evidencia |
|---|---|---|---|---|---|
| B-001 | Los CSV de Tobotex tienen hashes distintos a los manifiestos por conversión LF→CRLF; el conteo de filas coincide | El script estricto de §3.1 bloquea; se documenta política `coincide_al_convertir_lf_a_crlf` | Edward | Abierto, política local registrada | `evidencias/relevo/verificacion_archivos.json` |
| B-002 | C8 del código (0,20 por fuente) bloquea L1 del control (1/4 = 25 %) | P2 control no reproducible sin decisión explícita | Edward / docente | Abierto, propuesta 0,25 documentada | `contratos/POLITICAS_CASO.md` |
| B-003 | Query 7 contiene contraseñas literales | No reutilizar; cambiar credenciales si estuvieron activas | Freddy / Edward | Abierto | No incluir capturas del archivo |
| B-004 | Falta `.pbix` y exportación ADF | Se construyen desde cero siguiendo el manual | Edward | Abierto | `powerbi/`, `adf/` |

## 6. Decisiones y ajustes al recibir

1. **DirectQuery es la ruta principal**; Import se documenta como alternativa con actualización coordinada (§1.4 y §9).
2. **Base de primer despliegue:** `sqldb-test`. Las bases del caso se conservan si llegan con datos.
3. **Calendario 2026** se carga con `sql/fase3/00_calendario_2026.sql` (365 fechas) antes de cualquier preparación de hechos.
4. **C8:** 0,20 Tobotex; 0,25 control con comparación estricta `>`, documentado como decisión de práctica, no regla del enunciado.
5. **K6:** motivos vacíos/desconocidos se conservan como `SIN_MOTIVO` con `es_valido = 0`; no se rechazan los reclamos.
6. **Publicación:** se propone versión endurecida de `ctl.sp_publicar_corte`; validar en `sqldb-test` antes de aplicarla al caso.
7. **JSONL:** prevalidación manual de propiedades requeridas antes de subir; no presentarla como validación automática de ADF sin Azure Function.

## 7. Verificación cloud y preparación Power BI (23/11/2026)

1. Conexión: Azure MCP conectado con `AZURE_TOKEN_CREDENTIALS=AzureCliCredential` y `AZURE_TENANT_ID=dee9f998-…`; `subscription_list` sin tenant devuelve vacía, pero las consultas con `subscription` explícito funcionan.
2. Firewall de `sql-tobotex-pc3`: regla `ClientIPAddress_2026-11-23_19-26-32` para `190.232.218.9`; si Power BI Desktop se ejecuta desde otra red, agregar la IP pública correspondiente.
3. Tobotex ya contiene el modelo y los lotes ejecutados: `ctl.lote` registra L0–L3, LX, reenvíos y fallas simuladas; `ctl.corte_vigente=6` (`C-20261123-06`). Esto es evidencia SQL observada, no una ejecución hecha en esta sesión.
4. Se crearon las vistas de dimensiones de `sql/fase3/20_dimensiones_powerbi.sql` en `sqldb-tobotex`: `bi.v_dim_fecha` (365), `bi.v_dim_tienda_bi` (2), `bi.v_dim_marca_bi` (10), `bi.v_dim_producto_bi` (5). Las comprobaciones de duplicados devolvieron cero filas.
5. Se creó el usuario contenido de Entra `edward_oliva2002@outlook.com` en `sqldb-tobotex` y `sqldb-control`, con `GRANT CONNECT` y sin contraseña nueva. En Tobotex tiene `GRANT SELECT ON SCHEMA::bi` y `DENY SELECT` en `ctl`, `cur`, `quar`, `stg`, `trusted`. En Control sólo está el usuario; no se creó `bi` ni otros esquemas para no romper `SQL query 1.sql`.
6. No se creó `sqldb-test`, no se publicó ADF, no se asignó el rol de Storage a la identidad de ADF, no se generó `.pbix` y no se publicó en Power BI Service. `az consumption budget list` devolvió `[]`: no hay presupuesto configurado.
7. Los pasos para conectarse y el detalle de las figuras F3-01 a F3-10 están en `powerbi/conexion_directquery.md` y `powerbi/figuras_evidencia.md`.
