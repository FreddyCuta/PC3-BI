# Plan de proyecto total — PC3 Tobotex

Este documento aterriza `docs/division_y_flujo.md` a la estructura del repositorio. Define **qué artefacto vive dónde** y **quién lo completa**.

## Fases y entregables

| Fase | Responsable | Entregables principales | Rutas en repo |
|---|---|---|---|
| 0 | Freddy | Azure listo, presupuesto estimado, repo/accesos, estado de relevo | `docs/estado_relevo.md`, `evidencias/costos/`, `README.md` |
| 1 | Freddy | Introducción, Capítulo 1, Anexo A inicial | `informe/introduccion.md`, `informe/capitulo_1.md`, `informe/anexo_a.md` |
| 2 | Rolando | Datos, contratos, SQL, modelo, KPIs, tablero, Cap. 2, Anexos A/B/E | `datos/`, `contratos/`, `sql/`, `powerbi/`, `informe/capitulo_2.md`, `informe/anexo_b.md`, `informe/anexo_e.md`, `anexo_e/` |
| 3 | Edward | ADF, seguridad, costos observados, P1–P8, Cap. 3, conclusiones, C/D/F, demo, PDF | `adf/`, `pruebas/`, `evidencias/`, `informe/capitulo_3.md`, `informe/conclusiones.md`, `informe/anexo_c.md`, `informe/anexo_d.md`, `informe/anexo_f.md`, `demo/`, `entregables/` |

## Mapa de documentos del informe

| Documento | Ruta | Estado inicial |
|---|---|---|
| Introducción | `informe/introduccion.md` | Plantilla |
| Capítulo 1 | `informe/capitulo_1.md` | Plantilla |
| Capítulo 2 | `informe/capitulo_2.md` | Plantilla |
| Capítulo 3 | `informe/capitulo_3.md` | Plantilla |
| Conclusiones | `informe/conclusiones.md` | Plantilla |
| Anexo A | `informe/anexo_a.md` | Plantilla |
| Anexo B | `informe/anexo_b.md` | Plantilla |
| Anexo C | `informe/anexo_c.md` | Plantilla |
| Anexo D | `informe/anexo_d.md` | Plantilla |
| Anexo E | `informe/anexo_e.md` | Plantilla |
| Anexo F | `informe/anexo_f.md` | Plantilla |
| Referencias | `informe/referencias.md` | Plantilla |

## Mapa técnico

| Área | Ruta | Contenido esperado |
|---|---|---|
| Contratos | `contratos/` | JSON por fuente, versión y evolución de esquema |
| Datos | `datos/` | generador, tobotex L0-L3/LX, control_anexoE L0-L3, manifiestos |
| SQL | `sql/`, `sql/control/` | DDL, SP, vistas, seguridad, costos, reset |
| Carga | `carga/` | script manual registrado |
| ADF | `adf/` | linked services, datasets, pipelines, triggers exportados |
| Power BI | `powerbi/` | `.pbix` y exportaciones |
| Pruebas | `pruebas/` | bitácora, consultas, notas por prueba |
| Evidencias | `evidencias/` | relevo, P1-P8, kpis, modelo, costos, seguridad |
| Anexo E calc. | `anexo_e/` | esperados, cálculo independiente, comparaciones |
| Demo | `demo/` | guion, grabación/enlace, evidencias usadas |
| Entregables | `entregables/` | PDF final, paquete ZIP, checklist de entrega |

## Regla de evidencia

Nada se marca como ejecutado sin: captura/resultado, consulta, RunId/intento/corte, y ruta en `evidencias/`.
