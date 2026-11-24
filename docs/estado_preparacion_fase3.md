# Preparación local de fase 3 — estado y línea de corte

Este documento registra **qué se hizo en el repositorio** siguiendo `MANUAL_FASE_3_AZURE_POWER_BI.md` y **dónde se detuvo el trabajo**. No acredita despliegue en Azure ni conexión con Power BI.

## Línea de corte

Se completó todo el trabajo que puede ejecutarse sobre archivos locales. Se detiene **antes del apartado 2 del manual** («Crear recursos en Azure»). Por tanto:

- ✅ §1 Inventario y decisiones previas (parte local).
- ✅ §3 Preparar archivos, contratos y almacenamiento (parte local; no se suben archivos).
- ✅ §4 Despliegue SQL (solo scripts versionados; **no ejecutados**).
- ✅ §5 Usuarios y conexiones (plantillas sin secretos; **no creados**).
- ✅ §6 Pipeline Data Factory (JSON preparados; **no publicados**).
- ✅ §7 Carga manual de respaldo (script ajustado; **no ejecutado**).
- ✅ §8 Adaptación del Anexo E (datos adaptados generados; **no cargados**).
- ✅ §9–10 Power BI (vistas SQL, DAX, modelo y páginas documentadas; **sin `.pbix`**).
- ✅ §12 Consultas P1–P8 y bitácora (esperados; **sin observados**).
- ⛔ §2 Recursos Azure, §5.3 linked services en Studio, §6.8 publicación/RunId, §9.2 conexión en Desktop, §11 Service, §12 ejecución, §13 evidencias y costos: **PENDIENTE**.

## Artefactos generados

| Manual | Artefacto en el repo |
|---|---|
| §1.3, §1.4 | `docs/estado_relevo.md`, `docs/estado_preparacion_fase3.md` |
| §3.1 | `carga/Carga/verificar_archivos.py`, `evidencias/relevo/verificacion_archivos.json` |
| §3.2 | `contratos/despacho_v1.0.json`, `reclamo_v1.0.json`, `tienda_v1.0.json`, `POLITICAS_CASO.md` |
| §3.1/§6.4 | `carga/Carga/validar_jsonl.py` |
| §4.2–4.5 | `sql/fase3/00_calendario_2026.sql`, `01_merge_c8_parametrizado.sql`, `02_publicacion_reforzada.sql`, `04_verificacion_despliegue.sql` |
| §5.1 | `sql/fase3/03_usuarios_permisos.sql` |
| §5.3, §6 | `adf/linked_services/*.json`, `adf/datasets/*.json`, `adf/pipelines/*.json` |
| §7.2 | `carga/Carga/carga/cargar_lote.py` (opción `--umbral`) |
| §8.2 | `carga/Carga/adaptar_control.py`, `carga/Carga/datos/control_adaptado/` |
| §8.3 | `sql/fase3/21_control_dimensiones.sql` |
| §9.1 | `sql/fase3/20_dimensiones_powerbi.sql` |
| §9–10 | `powerbi/medidas.dax`, `powerbi/conexion_directquery.md`, `powerbi/modelo_relaciones.md`, `powerbi/paginas.md`, `powerbi/conciliacion.sql`, `powerbi/ESTADO_LOCAL.md` |
| §12 | `pruebas/consultas/00_conciliacion.sql`, `P1.sql`…`P8.sql`, `P5_recuperacion.sql`, `P7_A.sql`, `P7_B.sql`, `P7_EXCEPT.sql`, `P7_permisos.sql`, variantes `P1_control.sql`, `P2_control.sql`, `P3_control.sql`, `P4_control.sql`, `P8_control.sql`; `pruebas/bitacora_pruebas.csv` (14 filas `PENDIENTE`) |
| Entrega | `README.md`, `docs/checklist_entrega.md`, `informe/capitulo_2.md`, `capitulo_3.md`, `anexo_c.md`, `anexo_e.md`, `conclusiones.md` (texto de estado pendiente) |

## Bloqueos registrados antes de cloud

1. Sustituir todos los marcadores `TU_` por nombres reales y rellenar `docs/estado_relevo.md`.
2. Decidir la política de hashes LF/CRLF (B-001) antes de usar la verificación estricta como compuerta.
3. Aprobar documentalmente el umbral C8 del control (B-002) o registrar incompatibilidad.
4. Cambiar credenciales si las de Query 7 estuvieron activas (B-003).
5. Ejecutar los scripts en `sqldb-test` **antes** de tocar las bases del caso.

## Siguiente acción concreta

Abrir Azure Portal y ejecutar el manual desde **§2.1 Grupo y presupuesto**. Después de crear cada recurso, volver a `docs/estado_relevo.md` y sustituir «Planeado» por el nombre real y la evidencia correspondiente.
