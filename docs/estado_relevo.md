# Estado del relevo — Fase 2 a Fase 3

> Estado de **preparación local**. Los nombres con `TU_` son propuestos por el manual y deben sustituirse por valores reales al crear los recursos. Nada de lo marcado como «planeado» está creado ni verificado en Azure.

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
| Suscripción Azure | PENDIENTE | No creado/no comprobado | No |  | Se necesita permiso para crear recursos y asignar roles |
| Grupo de recursos | `rg-tobotex-pc3` | Planeado | No |  | Región propuesta: Chile Central; confirmar disponibilidad |
| Región | `chilecentral` (propuesta) | Planeada | No |  | Registrar alternativa si no está disponible |
| ADLS Gen2 | `sttobotexpc3TUINICIALES` | Planeado | No |  | HNS activado, Standard LRS, contenedores privados |
| Contenedor caso | `raw` | Planeado | No |  | Ruta `raw/tobotex/<lote>/` |
| Contenedor control | `rawcontrol` | Planeado | No |  | Ruta `rawcontrol/control_original|control_adaptado/<lote>/` |
| SQL Server | `sql-tobotex-pc3-TUINICIALES` | Planeado | No |  | Un servidor lógico, tres bases |
| DB Tobotex | `sqldb-tobotex` | Planeado | No |  | Primera base de despliegue: usar `sqldb-test` |
| DB Control | `sqldb-control` | Planeado | No |  | Umbral C8 documentado 0,25 |
| DB Test | `sqldb-test` | Planeado | No |  | Base vacía para validar scripts antes del caso |
| Data Factory | `adf-tobotex-pc3-TUINICIALES` | Planeado | No |  | Identidad asignada por sistema |
| Identidad ADF | PENDIENTE (object id real) | Planeada | No |  | Rol `Storage Blob Data Reader` en `raw` y `rawcontrol` |
| Usuario ingesta | `etl_loader` | Planeado | No |  | Secreto nuevo, fuera del repositorio |
| Usuario lectura | `bi_reader` | Planeado | No |  | Solo `SELECT` en esquema `bi` |
| Power BI | `powerbi/tobotex_pc3.pbix` | No creado | No |  | DirectQuery principal; Import como alternativa |

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

No ejecutada. Ejecutar en Tobotex y Control cuando existan. Guardar salida en `evidencias/relevo/`.

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
| sqldb-test | No | PENDIENTE |  |
| sqldb-tobotex | No | PENDIENTE |  |
| sqldb-control | No | PENDIENTE |  |

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
