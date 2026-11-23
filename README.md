# PC3 Tobotex — Business Intelligence

Repositorio del proyecto **PC3** para el caso Tobotex. Contiene la estructura base, documentación de trabajo y plantillas para ejecutar la **Fase 3** (pipeline parametrizado, publicación segura, pruebas P1–P8, Capítulo 3, conclusiones, anexos y paquete reproducible).

> **Estado:** estructura y documentación inicial creadas. La ejecución real en Azure, las evidencias y los resultados deben completarse durante el desarrollo.

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
  adf/
    linked_services/          # JSON exportado de linked services
    datasets/                 # JSON exportado de datasets
    pipelines/                # JSON exportado de pipelines
    triggers/                 # Triggers programados (si aplica)
  carga/
    cargar_lote.py            # Carga manual registrada / respaldo
  contratos/                  # Contratos versionados por fuente (JSON)
  datos/
    generador/                # Generadores y cálculos independientes
    tobotex/                  # L0-L3, LX + manifiestos
    control_anexoE/           # L0-L3 control + manifiestos
  docs/
    guia_fase2_tecnica.md     # Referencia técnica Fase 2
    guia_fase3_paso_a_paso.md # Guía operativa Fase 3
    arquitectura.md           # Diseño A/B, decisión y diagrama
    reglas_calidad_publicacion.md
    seguridad_costos.md
    pruebas.md                # Plan y criterios P1-P8
    estado_relevo.md          # Plantilla de relevo Fase 2 -> Fase 3
  evidencias/
    relevo/ P1..P8/ kpis/ modelo/ costos/ seguridad/
  informe/
    capitulo_3.md
    conclusiones.md
    anexo_c.md
    anexo_d.md
    anexo_f.md
    referencias.md
  powerbi/
    tobotex_pc3.pbix          # Tablero (cuando esté disponible)
    exportaciones/            # PDF/capturas exportadas
  pruebas/
    bitacora_pruebas.csv      # Bitácora P1-P8
    consultas/                # SQL de verificación por prueba
  sql/
    00..99 scripts Tobotex
    control/                  # Scripts adaptados Anexo E
```

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
