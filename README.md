# PC3 Tobotex — Business Intelligence

Repositorio del proyecto **PC3** para el caso Tobotex. Contiene la estructura base, documentación de trabajo y plantillas para ejecutar la **Fase 3** (pipeline parametrizado, publicación segura, pruebas P1–P8, Capítulo 3, conclusiones, anexos y paquete reproducible).

> **Estado:** preparación local de la Fase 3 completada hasta el inicio del manual §2. Hay scripts SQL versionados, contratos, prevalidaciones, adaptación del Anexo E, plantillas ADF, medidas/DAX y consultas P1–P8. **No se crearon recursos Azure, no se publicó ADF, no se conectó Power BI y no hay resultados observados.** Todo lo pendiente sigue marcado `PENDIENTE`.
>
> Punto de corte detallado: [`docs/estado_preparacion_fase3.md`](docs/estado_preparacion_fase3.md). Inventario y accesos: [`docs/estado_relevo.md`](docs/estado_relevo.md).

## Objetivo

Implementar y evidenciar un flujo de ingesta y publicación controlada en la nube para el caso Tobotex y el Anexo E (control), cumpliendo:

- Pipeline parametrizado por `lote_id`, `caso` y `simular_falla`, con `RunId` conservado.
- Controles de calidad C1–C8 y reglas de conciliación/publicación.
- Pruebas P1–P8 con evidencia localizable.
- Seguridad por roles (`etl_loader`, `bi_reader`) y registro de costos/consultas.
- Paquete reproducible con README, scripts, contratos, datos, manifiestos, pipeline, tablero y evidencias.

## Alcance y supuestos

- **Datos simulados:** el caso usa datos generados con semilla 2026; no representan operación real de Tobotex.
- **Fase 2 esperada como entrada:** scripts SQL, contratos, generador, lotes/manifiestos, tablero `.pbix`, Capítulo 2 y anexos A/B/E.
- **Fase 3:** responsable Edward, según `docs/guia_fase3_paso_a_paso.md`.
- **No se incluyen secretos:** contraseñas, cadenas de conexión reales, llaves o capturas sensibles no deben versionarse.

## Estructura del repositorio

```text
PC3-BI/
  README.md
  .gitignore
  adf/                        # Plantillas LOCALES (no exportadas ni publicadas)
    linked_services/          # ls_adls, ls_sql_{tobotex,control,test}.json (sin secretos)
    datasets/                 # ds_csv, ds_jsonl, ds_manifiesto, ds_sql_query*, ds_stg_* 
    pipelines/                # pl_cargar_lote, pl_tobotex, pl_control, pl_registrar_falla*
    README.md
  carga/Carga/
    carga/cargar_lote.py      # Carga manual registrada; añade --umbral (§8.3)
    verificar_archivos.py     # Prevalidación de manifiestos (§3.1)
    validar_jsonl.py          # Prevalidación estructural JSONL (§3.2)
    adaptar_control.py        # Anexo E adaptado reproducible (§8.2)
    datos/generador/          # Generadores y cálculo independiente
    datos/tobotex/            # L0-L3, LX + manifiestos (originales)
    datos/control_anexoE/     # L0-L3 control originales
    datos/control_adaptado/   # Adaptación versionada (no toca originales)
  contratos/                  # despacho/reclamo/tienda v1.0 + POLITICAS_CASO.md
  docs/
    estado_preparacion_fase3.md
    estado_relevo.md
    guia_fase2_tecnica.md, guia_fase3_paso_a_paso.md
    arquitectura.md, reglas_calidad_publicacion.md, seguridad_costos.md, pruebas.md
    checklist_entrega.md
  evidencias/
    relevo/                   # verificación de archivos y validación JSONL (reales, locales)
    P1..P8/, kpis/, modelo/, costos/, seguridad/   # PENDIENTES
  informe/                    # Capítulos y anexos en plantilla
  powerbi/
    medidas.dax, conexion_directquery.md, modelo_relaciones.md
    paginas.md, conciliacion.sql, ESTADO_LOCAL.md
    exportaciones/            # PENDIENTE: no hay .pbix ni capturas
  pruebas/
    bitacora_pruebas.csv      # 14 filas PENDIENTE
    consultas/                # 00_conciliacion, P1..P8 + variantes control y P7
  sql/
    Querys/                   # SQL original de Fase 2 (no modificado)
    fase3/                    # 00..04, 20, 21: scripts propuestos, no ejecutados
```

## Preparación local lista (pendiente de aplicación en nube)

| Bloque | Artefacto | Estado |
|---|---|---|
| §3 Relevo y archivos | `docs/estado_relevo.md`, `docs/estado_preparacion_fase3.md`, `evidencias/relevo/*.json`, `contratos/` | Listo (9/9 archivos aceptados con `--permitir-crlf`; JSONL 0 problemas) |
| §4 Scripts SQL | `sql/fase3/00_calendario_2026.sql` … `21_control_dimensiones.sql` | Listos para validar en `sqldb-test`; **no ejecutados** |
| §5 Usuarios | `sql/fase3/03_usuarios_permisos.sql` | Permisos versionados; secretos y usuarios reales **PENDIENTE** |
| §6 ADF | `adf/**` | Plantillas locales; **no importadas, publicadas ni ejecutadas** |
| §7 Carga manual | `carga/Carga/carga/cargar_lote.py` (`--umbral`) | Adaptación lista; conexión y ejecución **PENDIENTE** |
| §8 Control | `carga/Carga/adaptar_control.py`, `datos/control_adaptado/`, `sql/fase3/21_control_dimensiones.sql` | Adaptación generada con hashes propios; umbral `0.25` requiere aprobación documental |
| §§9–10 Power BI | `powerbi/medidas.dax`, `conexion_directquery.md`, `modelo_relaciones.md`, `paginas.md`, `conciliacion.sql` | Especificación local; **sin `.pbix` ni capturas** |
| §12 Pruebas | `pruebas/bitacora_pruebas.csv`, `pruebas/consultas/*.sql` | 14 filas `PENDIENTE`; consultas sin ejecutar |

**Fuera de alcance de esta preparación:** crear recursos Azure, desplegar/publicar ADF, ejecutar SQL en la nube, conectar o publicar Power BI, inventar RunIds/costos/evidencias. No reutilizar secretos de `sql/Querys/SQL query 7.sql`.

## Guías base

- `docs/guia_fase2_tecnica.md`: construcción técnica, modelo, scripts, generador, valores esperados.
- `docs/guia_fase3_paso_a_paso.md`: ejecución Fase 3, pruebas, seguridad, costos, informe y cierre.

## Flujo de trabajo recomendado (Fase 3)

1. **Relevo:** validar acceso a Azure/ADF/ADLS/SQL/Power BI y recibir artefactos de Fase 2. Registrar en `docs/estado_relevo.md`.
2. **Estructura y control:** confirmar contratos, esquemas, controles C1–C8 y reglas ambiguas documentadas.
3. **Pipeline:** construir/publicar `pl_cargar_lote` (y cuerpo) parametrizado; conservar `RunId`.
4. **Seguridad:** validar `bi_reader`/`etl_loader`, accesos permitidos/denegados.
5. **Pruebas:** ejecutar P1–P8, registrar bitácora y evidencias por caso/intento.
6. **Costos:** capturar presupuesto vs. observado en Cost Management.
7. **Informe:** completar Capítulo 3, conclusiones y anexos C/D/F.
8. **Cierre:** revisar PDF, demo ≤ 8 min, limpieza de recursos y exclusión de secretos.

## Convenciones

- **Cortes:** C0–C3 son etiquetas de prueba; registrar mapeo a `corte_seq` y `corte_id` real (`C-AAAAMMDD-NN`).
- **Evidencias:** toda cifra del informe debe apuntar a evidencia localizable.
- **Bitácora:** `pruebas/bitacora_pruebas.csv` es la fuente base del Anexo C.
- **Fallos:** no sobrescribir evidencia de intentos fallidos; registrar primer intento y corrección.
- **Secretos:** usar variables de entorno, Key Vault o placeholders `<clave>`.

## Prerrequisitos (a completar con valores reales)

| Componente | Valor | Estado |
|---|---|---|
| Suscripción Azure | `<suscripcion>` | PENDIENTE |
| Grupo de recursos | `rg-tobotex-pc3` | PENDIENTE |
| Región | `<region>` | PENDIENTE |
| ADLS Gen2 | `sttobotexpc3<ini>` | PENDIENTE |
| SQL Server | `sql-tobotex-pc3-<ini>` | PENDIENTE |
| DB Tobotex | `sqldb-tobotex` | PENDIENTE |
| DB Control | `sqldb-control` | PENDIENTE |
| DB Test | `sqldb-test` | PENDIENTE |
| Data Factory | `adf-tobotex-pc3-<ini>` | PENDIENTE |
| Power BI | Desktop / exportación PDF | PENDIENTE |

## Limpieza

Después de entregar y preservar evidencias:

1. Exportar bitácora, capturas, JSON de ADF, tablero y costos.
2. Eliminar recursos de prueba no necesarios.
3. Eliminar grupo de recursos si ya no se requiere.
4. Verificar en Cost Management que no queden cargos posteriores.

## Referencias rápidas

- [Guía Fase 3](docs/guia_fase3_paso_a_paso.md)
- [Guía Fase 2](docs/guia_fase2_tecnica.md)
- [Plan de pruebas](docs/pruebas.md)
- [Bitácora de pruebas](pruebas/bitacora_pruebas.csv)
