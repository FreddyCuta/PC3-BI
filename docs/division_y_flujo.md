# PC3 Tobotex: división secuencial, flujo por capítulo y guía técnica en Azure

Grupo 11. Orden de trabajo: Freddy, luego Rolando, luego Edward. Nadie empieza hasta recibir el entregable de la persona anterior.

---

## 0. Revisión de la división sugerida

La división por capítulos es correcta en lo temático. Freddy toma Introducción y Capítulo 1, que es el más narrativo. Rolando toma el Capítulo 2, que es el modelo y los KPIs. Edward toma el Capítulo 3 y las Conclusiones, que son arquitectura, calidad, seguridad y pruebas. Los técnicos quedan en las dos últimas posiciones, como corresponde.

Hay cuatro problemas si se aplica tal cual en modo secuencial, y por eso propongo ajustes:

1. **Rolando necesita la nube antes de escribir.** Los puntos 2.2 a 2.5 piden SQL en la nube, datos cargados y un tablero conectado. Si nadie deja la cuenta Azure creada y el repositorio listo, Rolando pierde medio día en preparación. Ajuste: Freddy hace al final de su fase una "Fase 0" corta, sin programación: activar la cuenta, crear el repositorio y compartir accesos.
2. **El Capítulo 3 es la base técnica, pero va al final.** Las vistas de Rolando dependen de la lógica de cortes, que aparece en 3.2. Ajuste: en este documento fijo el diseño de cortes desde ya (sección 6.5). Rolando lo construye en su versión mínima y Edward lo endurece, lo automatiza y lo prueba.
3. **Rolando queda sobrecargado y Freddy subcargado.** Ajuste: Freddy redacta además la estimación de presupuesto de 3.3, que no requiere ejecutar nada. Edward la completa con el costo observado.
4. **Faltaban entregables del enunciado en el reparto:** Anexos A a F, README del paquete reproducible, demostración de ocho minutos y referencias APA. Quedan asignados en cada fase.

Aviso de calidad: en el Parcial hubo contradicciones, por ejemplo el resumen ejecutivo decía que Spark y el dashboard estaban ejecutados y los anexos decían pendiente. En la PC3 la rúbrica pide evidencia verificable por cada punto. Regla del grupo: nada se escribe como ejecutado sin una captura, un identificador de intento y una consulta que lo respalde.

Sobre el plazo: el enunciado está fechado el 23-11-26. Si esa es la fecha de entrega, los bloques de tiempo de abajo son el máximo realista. Confirmen el plazo real con el docente.

---

## 1. Reglas del relevo

| Fase | Persona | Duración estimada | Recibe | Entrega |
|---|---|---|---|---|
| 1 | Freddy | 4 a 5 h | Este documento | Introducción y Capítulo 1 redactados, presupuesto estimado, cuenta Azure y repositorio listos |
| 2 | Rolando | 8 a 10 h | Fase 1 más acceso a Azure | Capítulo 2 completo, datos L0 a L3, modelo, vistas de KPI, tablero, Anexos A, B y E |
| 3 | Edward | 9 a 11 h | Fase 2 más base de datos funcionando | Capítulo 3, pruebas P1 a P8, Anexos C y D, conclusiones, README, demo y PDF final |

Criterio para pasar el relevo. Quien entrega firma una lista corta de lo que dejó listo, lo que no pudo hacer y los problemas que encontró. Se guarda en `README.md` del repositorio, en la sección "Estado del relevo". El siguiente no empieza hasta leerla.

Una pasada final de lectura de una hora, solo para corregir redacción y consistencia de numeración, puede hacerla Freddy después de Edward. No es trabajo nuevo, solo revisión.

---

## 2. Diseño común del caso, que todos deben respetar

Este diseño evita contradicciones entre capítulos. Si hay que cambiarlo, se avisa al que sigue.

### 2.1 Caso

Tobotex S.A.C., fabricante B2B de etiquetas tejidas en La Victoria, Lima. Proceso: despacho de pedidos y atención de reclamos de calidad por devoluciones. Datos simulados con generador de semilla fija, declarado como tal, con nombres de marca tomados de los archivos del Parcial.

### 2.2 Fuentes

| ID | Fuente | Tipo | Formato | Clave de negocio | Fecha de evento | Contenido |
|---|---|---|---|---|---|---|
| F1 | Movimientos de despacho | Eventos | CSV | `id_movimiento` más `version` | `fecha_salida` | Contrato, detalle, marca, tienda, producto, cantidad contratada de referencia, cantidad despachada, importe en PEN |
| F2 | Reclamos de devolución | Eventos | JSON por líneas | `id_reclamo` | `fecha_reclamo` | Movimiento al que se refiere, cantidad y importe devueltos, motivo |
| F3 | Historial de tiendas | Catálogo maestro | CSV cargado a tabla | `tienda` más `vigente_desde` | no aplica | Tienda, zona comercial, vigencias |

Las tres fuentes tienen formatos o mecanismos distintos, como pide el enunciado. Cada una lleva tres fechas distintas: fecha del evento, fecha de actualización en origen y fecha de ingesta.

### 2.3 Lotes

| Lote | Contenido | Para qué sirve |
|---|---|---|
| L0 | Julio, agosto y septiembre de 2026. Unos 600 movimientos y 25 reclamos | Línea base, tres períodos consecutivos |
| L1 | Octubre. 40 movimientos nuevos, 1 duplicado exacto, 2 actualizaciones de versión, 2 inválidos | Incremental y cuarentena |
| L2 | 3 reclamos con fecha de septiembre y 1 corrección de un movimiento de septiembre | Evento tardío y revisión histórica |
| L3 | 15 movimientos de octubre y 3 reclamos que los referencian | Publicación interrumpida |
| LX | Copia de L1 sin el campo `tienda` | Esquema incompatible, P5 |

Política de corte propuesta. Cada publicación genera un corte con identificador `C-AAAAMMDD-NN`. Un mes se considera cerrado el día 5 del mes siguiente. Se aceptan correcciones hasta 90 días después del cierre y los períodos afectados se marcan como revisados.

### 2.4 Modelo

Hecho 1: `fact_despacho`, una fila por movimiento y versión vigente. Hecho 2: `fact_reclamo`, una fila por reclamo. Dimensiones: `dim_fecha` y `dim_tienda` conformadas, más `dim_marca`, `dim_producto` y `dim_motivo`. SCD tipo 2 en `dim_tienda`, atributo `zona_comercial`. Ejemplo de cambio: LEO pasa de "Gamarra Norte" a "Gamarra Centro" con vigencia desde 2026-09-15.

Regla de vigencia, idéntica a la del Anexo E: la fecha inicial se incluye y la final se excluye. El reclamo hereda tienda, marca y producto del movimiento y la zona se determina a la fecha del reclamo.

### 2.5 Seis KPIs

| KPI | Tipo | Fórmula | Decisión |
|---|---|---|---|
| K1 Despacho bruto PEN | Aditiva | Suma de importes de movimientos vigentes por mes de salida | D3 |
| K2 Despacho neto PEN | Integra ambos hechos | K1 menos suma de devoluciones por mes de devolución | D3 |
| K3 Tasa de devolución | Razón, integra ambos hechos | Devoluciones PEN dividido entre despacho bruto PEN | D2 |
| K4 Variación mensual del despacho bruto | Variación | K1 del mes menos K1 del mes anterior, entre K1 anterior | D3 |
| K5 Cumplimiento de cantidad | Razón | Suma de min(despachada, contratada) entre suma de contratada, con la contratada una vez por línea | D1 |
| K6 Reclamos con motivo codificado | Razón | Reclamos con motivo válido entre reclamos totales | D2 |

### 2.6 Tres decisiones

D1 operativa, responsable de despacho, K5. D2 táctica, jefatura de producción y calidad, K3 y K6. D3 estratégica, gerencia general, K1, K2 y K4. El detalle de preguntas, umbrales y acciones está en el borrador de redacción.

---

## 3. FASE 1: Freddy

**Secciones:** Introducción, 1.1, 1.2, 1.3, 1.4. Más: estimación de presupuesto de 3.3, Fase 0 técnica y Anexo A.

**Entregable:** texto de Capítulo 1 en el formato del informe, tabla de presupuesto estimado, repositorio y cuenta Azure listos.

### Flujo de trabajo

**Paso 1. Leer el diseño común (sección 2).** Salida: ningún archivo. Si algo no cuadra con el caso, anotar y avisar a los otros dos.

**Paso 2. Redactar 1.1 Caso y proceso.**
- Qué va: sector textil complementario, modelo B2B, ubicación en La Victoria, cadena de valor adaptada de Porter con apoyo y actividades primarias, y el lugar del proceso de despacho y reclamos dentro de ella.
- Cómo se registra la información hoy: WMS de despacho por tienda exportado a CSV, sistema comercial en hojas de cálculo, y los reclamos que llegan por contacto del cliente sin registro estructurado. En la PC3 los reclamos se modelan como una fuente JSON simulada.
- Quién decide con ella: responsable de despacho, jefatura de producción y calidad, gerencia general.
- Tomar el contexto de PC1 secciones 1.1 y 1.3, resumido en una página. Recordar la distinción entre dato real, comunicado por el contacto y simulado.

**Paso 3. Redactar 1.2 Problemas y decisiones.**
- Presentar el problema central del desafío: los totales cambian al reenviar un archivo y una corrección tardía altera un período ya publicado. Conectarlo con lo que ya se encontró en PC2: filas repetidas por componentes y falta de fechas.
- Tabla de las tres decisiones con pregunta analítica, responsable, KPI, umbral y acción. Ver el borrador de redacción que acompaña este plan.
- Cada acción debe ser concreta y con plazo, por ejemplo "escalar las diez líneas con mayor faltante a producción dentro de 48 horas".

**Paso 4. Redactar 1.3 Alcance y objetivos.**
- Un objetivo general y tres específicos, cada uno con una métrica verificable.
- Período Julio a octubre de 2026. Población: despachos de las tiendas LEO y AMERICA. Frecuencia: carga semanal por lote y cierre mensual. Restricciones de acceso, costo y disponibilidad.

**Paso 5. Redactar 1.4 Modalidad técnica.**
- Azure con la suscripción de estudiantes del GitHub Student Developer Pack. Servicios: ADLS Gen2, Azure SQL Database, Azure Data Factory y Power BI Desktop. Una oración por servicio explicando su rol.
- Declarar la carga inicial manual registrada y las siguientes por pipeline parametrizado por lote.
- Declarar que Azure sustituye a la infraestructura Hortonworks del Parcial y por qué: la máquina de laboratorio no soportaba el clúster, como se documentó.

**Paso 6. Presupuesto estimado (adelanto de 3.3).**
- Usar la calculadora de precios de Azure con estos supuestos: región elegida, un solo mes, 8 cargas, menos de 1 GB de datos, base de datos de nivel básico, Data Factory con unas 100 actividades al mes.
- Tabla de salida: servicio, supuesto, costo estimado en USD, costo en PEN con tipo de cambio declarado y fecha. Dejar la columna "costo observado" vacía para Edward.
- Citar la fuente de cada precio con fecha de consulta.

**Paso 7. Anexo A.** Tabla ID, decisión, KPI, fórmula y reglas, umbral, responsable, acción. Se llena con las tres decisiones y los seis KPIs del diseño común. Rolando lo completa con reglas detalladas en su fase.

**Paso 8. Introducción.** Media página. Cuenta la continuidad PC1, PC2, Parcial y PC3, el desafío, y la estructura del informe. Menciona qué se hereda y qué es nuevo.

**Paso 9. Fase 0 técnica, 30 a 45 minutos.**
1. Activar Azure for Students desde el GitHub Student Developer Pack (guía en 6.1).
2. Crear el repositorio privado `tobotex-pc3` en GitHub con la estructura de carpetas de 6.3 y un README vacío con la sección "Estado del relevo".
3. Invitar a Rolando y Edward al repositorio.
4. Enviar a Rolando y Edward la invitación al control de acceso de la suscripción, como Contributor, desde el portal en Control de acceso IAM.
5. Crear alertas de presupuesto en Cost Management de 20, 50 y 80 dólares.

**Relevo a Rolando:** capturas de cuenta activa y crédito visible, enlace al repositorio, texto de Capítulo 1 y tabla de presupuesto.

---

## 4. FASE 2: Rolando

**Secciones:** 2.1, 2.2, 2.3, 2.4, 2.5. Más Anexos A (reglas), B y E.

**Entregable:** base de datos funcionando con L0 a L3 cargados, modelo, seis vistas de KPI, tablero con dos páginas, Capítulo 2 redactado, Anexo E con resultados por corte.

### Flujo de trabajo

**Paso 1. Entorno Azure (guía 6.2).** Crear grupo de recursos, cuenta de almacenamiento con tres contenedores, servidor SQL y las dos bases de datos. Salida: recursos visibles en el portal, captura de cada uno con región.

**Paso 2. Generador de datos y contratos (guía 6.4).** Escribir `generar_datos.py` con semilla 2026. Salida: carpetas `L0` a `L3` y `LX`, con manifiesto de filas y hash por archivo. Escribir también los tres contratos JSON de entrada.

**Paso 3. Esquemas y tablas (guía 6.5).** Ejecutar los scripts `00` al `05`. Esto crea los esquemas `stg`, `trusted`, `cur`, `bi`, `ctl`, `quar`, las tablas de control y el modelo dimensional con las columnas de corte. Salida: scripts versionados y captura del explorador de objetos.

**Paso 4. Núcleo de carga mínimo.** Cargar L0 manualmente: subir archivos al contenedor raw, copiar a las tablas de staging con un script de carga simple, ejecutar `sp_transformar` y `sp_publicar_corte`. Edward lo reemplazará por pipeline, pero el procedimiento de publicación queda definitivo. Salida: corte C0 publicado y conciliado.

**Paso 5. Escribir 2.1 Fuentes y cortes.**
- Tabla por fuente con propietario, ubicación en Azure, esquema, volumen, claves candidatas, zona horaria America/Lima, frecuencia y campos sensibles.
- Explicar las tres fechas, la regla de empate de versión y la política de corte de la sección 2.3.
- Incluir las reglas de simulación del generador, como pide el enunciado.

**Paso 6. Escribir 2.2 Modelo dimensional.**
- Declarar el grano de cada hecho antes de hablar de claves.
- Tabla de dimensiones con clave de negocio, clave sustituta y cardinalidad. Identificar las dos conformadas.
- Medidas con su aditividad: importe y cantidad despachada son aditivas, cantidad contratada es no aditiva en el grano del movimiento.
- Demostración de SCD2 con el cambio de zona de LEO y un movimiento de septiembre asignado a la versión vigente en su fecha, incluyendo el evento tardío de L2. Captura de la consulta y de las dos versiones.
- **Prueba de granularidad:** consulta que suma K1 por separado, otra que lo suma tras unir naivemente ambos hechos y se infla, y otra tras alinear por mes y tienda antes de combinar. Mostrar los tres totales. Ver el ejemplo del Anexo E en 6.12.

**Paso 7. Escribir 2.3 Diseño de los indicadores.** Una ficha por KPI con los cuatro bloques del enunciado: decisión, cálculo, tiempo y linaje. Poner el objeto SQL de consumo y el visual. Meta justificada. Este paso completa Anexos A y B.

**Paso 8. Implementar los seis KPIs como vistas versionadas.** Vistas `bi.v_k1` a `bi.v_k6`, con script que lleve fecha y versión en el comentario. Ejecutar cada una con período y filtro, guardar el resultado. Salida: `11_kpis.sql` y capturas.

**Paso 9. Escribir 2.4 Cálculo y conciliación.**
- Elegir K2 y K3 como los dos KPIs críticos, porque integran ambos hechos.
- Para cada uno, armar un subconjunto trazable de unas 20 filas, calcular el valor esperado en una hoja de cálculo o con pandas y contrastarlo con SQL y con el tablero.
- Tolerancia: igualdad exacta en conteos y en importes a dos decimales, y 0,01 puntos porcentuales en razones. Justificarla antes de ejecutar.
- Verificar que el total de K3 sale de sumar numeradores y denominadores y no de promediar tasas.

**Paso 10. Tablero (guía 6.11).** Una página ejecutiva y una de diagnóstico. Filtros por mes y tienda, línea de meta, detalle por marca, y tarjeta con el identificador del último corte publicado y fecha de publicación. Marcar períodos revisados.

**Paso 11. Escribir 2.5 Tablero y conclusiones.** Capturas, descripción de visuales y tres hallazgos cuantificados con su acción. Los números salen del tablero real, no del borrador.

**Paso 12. Anexo E.** Cargar los datos de control en la segunda base de datos con el mismo DDL, ejecutar C0 a C3 y llenar la tabla por corte y mes con bruto, devuelto y neto, más el cálculo independiente. Los valores esperados están en 6.12.

**Relevo a Edward:** base de datos con C0 a C3 publicados manualmente, scripts `00` a `09` y `11`, tablero, Capítulo 2 redactado, nota de cualquier hallazgo que pueda afectar al pipeline.

---

## 5. FASE 3: Edward

**Secciones:** 3.1, 3.2, 3.3, 3.4, Conclusiones, Referencias. Más Anexos C, D y F, README, demostración y PDF final.

**Entregable:** pipeline parametrizado en Data Factory, controles de calidad, seguridad, costos observados, ocho pruebas ejecutadas y documentadas, paquete reproducible.

### Flujo de trabajo

**Paso 1. Escribir 3.1 Arquitectura y procesamiento.**
- Comparar dos diseños con los mismos criterios de costo, actualización, operación y seguridad. Propuesta: diseño A con ADLS, Data Factory y Azure SQL, y diseño B con ADLS y Synapse serverless sobre Parquet.
- Justificar el diseño A: pequeño volumen, menor costo fijo, SQL conocido por el equipo.
- Diagrama con recursos, región, identidades y flujo hasta el tablero. Distinguir las capas raw en ADLS, trusted y curated en Azure SQL.
- Documentar los tres contratos versionados y qué cambios de esquema admiten.

**Paso 2. Pipeline `pl_cargar_lote` (guía 6.6).** Parametrizar lote, caso y simulación de falla. Salida: JSON exportado del pipeline y captura de una ejecución exitosa con su identificador de ejecución.

**Paso 3. Controles de calidad (guía 6.7).** Implementar los siete controles con umbral y severidad. Tabla de rechazos con motivo por lote. Conciliación por resultado: recibidas igual a insertadas más actualizadas más omitidas más rechazadas.

**Paso 4. Publicación por corte y recuperación (guía 6.5 y 6.8).** Endurecer `sp_publicar_corte`: exige que todos los objetos del corte estén listos. Implementar descarte de candidatos incompletos.

**Paso 5. Seguridad y costos (guías 6.9 y 6.10).** Crear usuarios, probar acceso permitido y denegado, comparar dos consultas equivalentes y consultar el costo observado.

**Paso 6. Pruebas P1 a P8 (guía 6.12).** Ejecutar en el caso propio y en el Anexo E las que pide el enunciado. Llenar la bitácora de pruebas y el Anexo C. Una prueba fallida se conserva con su primer intento.

**Paso 7. Escribir 3.2, 3.3 y 3.4.** 3.3 reutiliza la tabla de presupuesto de Freddy con la columna observada completada. 3.4 es la tabla de pruebas con lote, intento, corte, regla, esperado, observado, estado y evidencia.

**Paso 8. Anexo D.** Componente, servicio, región, rol, volumen, costo, medición y evidencia.

**Paso 9. Conclusiones.** Entre cinco y siete, basadas en resultados medidos: reenvío sin duplicados, efecto de la corrección tardía, cifra utilizable por gerencia, publicación atómica, costo observado, limitaciones. Referencias en APA 7, incluyendo las de Azure que realmente consultaron.

**Paso 10. Paquete final.** README con prerrequisitos, parámetros, orden de ejecución y limpieza. Anexo F con autoevaluación. Demostración de ocho minutos o menos: reenvío P3, revisión histórica P4, conciliación P6, publicación interrumpida P8. PDF del informe. Eliminar o pausar recursos al terminar.

---

## 6. GUÍA TÉCNICA PROFUNDA

### 6.1 Cuenta de Azure con el Student Developer Pack

1. Entrar a `education.github.com/pack` con la cuenta GitHub que ya tiene el beneficio de estudiante activo.
2. Buscar la oferta de Microsoft Azure y abrir "Get access". Redirige a la activación de Azure for Students.
3. Iniciar sesión con una cuenta Microsoft. Conviene usar el correo institucional si lo acepta, pero también puede ser una cuenta personal verificada con GitHub.
4. Completar perfil y número de teléfono. No pide tarjeta de crédito en esta modalidad.
5. Comprobar en el portal, en Cost Management más Billing, que aparece el crédito inicial. El monto y la vigencia son los que muestra la oferta en ese momento, anotarlos.
6. Detalle importante: las suscripciones de estudiantes pueden tener una lista corta de regiones permitidas. Al crear el primer recurso verificar cuáles aparecen. Si Brazil South está permitida, es la más cercana a Lima. Usar **la misma región para todo**.
7. Algunos proveedores de recursos pueden estar sin registrar, por ejemplo Data Factory. En Suscripciones, Proveedores de recursos, registrar `Microsoft.DataFactory`, `Microsoft.Sql` y `Microsoft.Storage` antes de empezar.
8. Presupuesto: en Cost Management crear un presupuesto con alertas al 20, 50 y 80 por ciento del crédito.

Herramientas locales: Azure CLI, `sqlcmd`, Python 3.11 con `pandas` y `pyodbc`, Power BI Desktop en Windows, VS Code con la extensión MSSQL o SSMS. Azure Data Studio fue anunciado para retiro, no conviene basarse en él.

### 6.2 Recursos a crear, con nombres sugeridos

| Recurso | Nombre | Notas |
|---|---|---|
| Grupo de recursos | `rg-tobotex-pc3` | Todo dentro de uno, facilita la limpieza |
| Cuenta de almacenamiento | `sttobotexpc3<iniciales>` | ADLS Gen2, activar espacio de nombres jerárquico, redundancia local |
| Contenedores | `raw`, `rawcontrol`, `quarantine` | Raw conserva el archivo recibido tal cual |
| Servidor SQL | `sql-tobotex-pc3-<iniciales>` | Autenticación SQL con usuario administrador, guardar la clave fuera del repositorio |
| Base de datos del caso | `sqldb-tobotex` | Si aparece "free offer" aplicarla, si no nivel Basic |
| Base de datos de control | `sqldb-control` | Espacio aislado del Anexo E |
| Data Factory | `adf-tobotex-pc3` | Versión 2 |
| Key Vault, opcional | `kv-tobotex-pc3` | Para secretos del pipeline |

Firewall del servidor SQL: agregar la IP pública de cada integrante y activar "Allow Azure services" para que Data Factory llegue. Cada recurso se documenta con región, SKU y captura, esto alimenta el Anexo D.

### 6.3 Estructura del repositorio

```
tobotex-pc3/
  README.md
  contratos/
    contrato_despacho_v1.json
    contrato_reclamo_v1.json
    contrato_tienda_v1.json
    contrato_ventas_control_v1.json
    contrato_devoluciones_control_v1.json
    contrato_sedes_control_v1.json
  datos/
    generador/generar_datos.py
    generador/reglas_simulacion.md
    tobotex/L0 L1 L2 L3 LX
    control_anexoE/L0 L1 L2 L3
  sql/
    00_esquemas.sql  01_control.sql  02_stg.sql  03_trusted.sql
    04_curated.sql   05_seed_dims.sql 06_sp_validar.sql
    07_sp_transformar.sql 08_sp_publicar.sql 09_vistas_bi.sql
    10_seguridad.sql 11_kpis.sql 12_costos_consultas.sql 99_limpieza.sql
  adf/
    pipeline_cargar_lote.json  linked_services/
  powerbi/tobotex_pc3.pbix
  pruebas/bitacora_pruebas.csv
  evidencias/P1 ... P8/
  anexo_e/esperados.csv  calculo_independiente.xlsx
```

Cada subcarpeta de datos lleva un `manifiesto.json` con nombre de archivo, filas y SHA-256. Se genera con el generador.

### 6.4 Datos: generador y contratos

**Entrada:** semilla 2026, lista de marcas del Parcial, parámetros de volumen por lote.
**Salida:** los CSV y JSON de cada lote más su manifiesto.

Reglas mínimas de simulación:
- Cada movimiento tiene `id_movimiento` tipo `M000123` y `version` desde 1.
- Alrededor del 15 por ciento de las líneas contrato más detalle tienen entre dos y tres movimientos parciales. La cantidad contratada se repite en cada uno, como en el WMS real.
- Importe del despacho igual a precio unitario simulado por cantidad despachada.
- Reclamos: 3 a 4 por ciento de los movimientos, con motivo del catálogo (`DEFECTO_TEJIDO`, `COLOR`, `MEDIDA`, `CANTIDAD`) y un 5 por ciento sin motivo para alimentar K6.
- L1: copiar una fila exacta (duplicado), subir de versión dos movimientos existentes cambiando cantidad e importe, incluir un movimiento con cantidad cero y otro con tienda inexistente.
- L2: reclamos con `fecha_reclamo` en septiembre, y una versión 2 de un movimiento de septiembre.
- L3: movimientos de octubre y reclamos que los referencian, incluidos los del mismo lote.
- LX: igual a L1 pero sin la columna `tienda`.
- Tiendas: LEO y AMERICA. Historial: LEO "Gamarra Norte" hasta 2026-09-15 y luego "Gamarra Centro".

Ejemplo de contrato:

```json
{
  "fuente": "despacho", "version_contrato": "1.0",
  "clave_negocio": ["id_movimiento"], "regla_version": "mayor version valida prevalece",
  "zona_horaria": "America/Lima",
  "campos": [
    {"nombre":"id_movimiento","tipo":"string","requerido":true},
    {"nombre":"version","tipo":"int","requerido":true},
    {"nombre":"fecha_salida","tipo":"date","requerido":true},
    {"nombre":"tienda","tipo":"string","requerido":true},
    {"nombre":"marca","tipo":"string","requerido":true},
    {"nombre":"producto","tipo":"string","requerido":true},
    {"nombre":"contrato","tipo":"string","requerido":true},
    {"nombre":"detalle","tipo":"string","requerido":true},
    {"nombre":"cantidad_contratada","tipo":"int","requerido":true},
    {"nombre":"cantidad_despachada","tipo":"int","requerido":true},
    {"nombre":"importe_pen","tipo":"decimal(18,2)","requerido":true},
    {"nombre":"fecha_actualizacion_origen","tipo":"datetime","requerido":false}
  ],
  "cambios_admitidos": ["agregar campos opcionales"],
  "campos_sensibles": ["marca"]
}
```

Sensibilidad: la marca puede identificar clientes, se expone al rol BI como un código hash y no como nombre, o se declara que es dato simulado.

### 6.5 Esquemas, tablas y cortes

Cinco esquemas: `stg` para staging crudo en texto, `trusted` para datos validados, `cur` para el modelo, `bi` para vistas de consumo, `ctl` para control y `quar` para rechazos.

**Tablas de control:**

```sql
CREATE TABLE ctl.lote (
  lote_id VARCHAR(10), fuente VARCHAR(20), intento INT, archivo NVARCHAR(200),
  hash_archivo CHAR(64), filas_leidas INT, filas_ins INT, filas_upd INT,
  filas_omit INT, filas_rech INT, estado VARCHAR(20),
  pipeline_run_id VARCHAR(60), inicio_utc DATETIME2, fin_utc DATETIME2,
  PRIMARY KEY (lote_id, fuente, intento));

CREATE TABLE ctl.corte (
  corte_seq INT PRIMARY KEY, corte_id VARCHAR(20), estado VARCHAR(12),
  creado_utc DATETIME2, publicado_utc DATETIME2 NULL, lotes_incluidos VARCHAR(100));

CREATE TABLE ctl.corte_objeto (
  corte_seq INT, objeto VARCHAR(40), estado VARCHAR(12), filas INT,
  PRIMARY KEY (corte_seq, objeto));

CREATE TABLE ctl.corte_vigente (
  id INT PRIMARY KEY CHECK (id = 1), corte_seq INT NOT NULL);
```

**Hechos con historia por corte.** Cada fila de hecho guarda desde qué corte es visible y hasta cuál:

```sql
CREATE TABLE cur.fact_despacho (
  despacho_sk BIGINT IDENTITY PRIMARY KEY,
  id_movimiento VARCHAR(20), version INT,
  fecha_sk INT, tienda_sk INT, marca_sk INT, producto_sk INT,
  contrato VARCHAR(20), detalle VARCHAR(20),
  cantidad_contratada INT, cantidad_despachada INT, importe_pen DECIMAL(18,2),
  hash_fila CHAR(64), lote_id VARCHAR(10),
  corte_desde INT NOT NULL, corte_hasta INT NULL);
```

`fact_reclamo` sigue el mismo patrón. Una vista de consumo sólo ve las filas válidas en el corte vigente:

```sql
CREATE VIEW bi.v_despacho AS
SELECT f.* FROM cur.fact_despacho f CROSS JOIN ctl.corte_vigente v
WHERE f.corte_desde <= v.corte_seq
  AND (f.corte_hasta IS NULL OR f.corte_hasta > v.corte_seq);
```

Esto resuelve la mayor parte del desafío. Preparar un corte candidato inserta filas con un `corte_desde` mayor que el vigente y cierra versiones anteriores poniéndoles ese corte en `corte_hasta`. Mientras el puntero no se mueva, nadie ve esos cambios. Comparar dos cortes es consultar la misma tabla con otro valor de corte.

**Dimensión SCD2 y asignación temporal:**

```sql
CREATE TABLE cur.dim_tienda (
  tienda_sk INT IDENTITY PRIMARY KEY, tienda VARCHAR(10), zona_comercial VARCHAR(40),
  vigente_desde DATE, vigente_hasta DATE, es_actual BIT);
-- vigente_hasta abierta se guarda como '9999-12-31'

-- asignación del hecho, inicio incluido y fin excluido
JOIN cur.dim_tienda t ON t.tienda = s.tienda
 AND s.fecha_negocio >= t.vigente_desde AND s.fecha_negocio < t.vigente_hasta
```

Un evento tardío usa esta misma unión con su fecha de negocio, no con la fecha actual, por eso recibe la versión histórica correcta.

**Publicación atómica:**

```sql
CREATE PROCEDURE ctl.sp_publicar_corte @c INT AS
BEGIN
  IF (SELECT COUNT(*) FROM ctl.corte_objeto
      WHERE corte_seq=@c AND estado='LISTO') < 2   -- hecho despacho y hecho reclamo
    THROW 50001, 'Corte incompleto: no se publica', 1;
  BEGIN TRAN;
    UPDATE ctl.corte SET estado='PUBLICADO', publicado_utc=SYSUTCDATETIME() WHERE corte_seq=@c;
    UPDATE ctl.corte_vigente SET corte_seq=@c;
  COMMIT;
END
```

Y un procedimiento de descarte que borra las filas de un corte candidato fallido y restaura el `corte_hasta` que ese candidato modificó, de modo que el reintento parte limpio.

### 6.6 Pipeline en Data Factory

**Servicios vinculados:** ADLS Gen2 con identidad administrada y Azure SQL con la credencial del usuario de carga.

**Pipeline `pl_cargar_lote`**
- Parámetros: `lote_id`, `caso` (tobotex o control), `simular_falla` (vacío, `tras_despacho`, `esquema`).
- Actividades, en orden:
  1. Stored procedure `ctl.sp_iniciar_lote`: registra lote, calcula intento siguiente y guarda `@pipeline().RunId`.
  2. Get Metadata de cada archivo en `raw/<lote_id>/`: valida que existen y su tamaño.
  3. Copy a `stg.despacho`, `stg.reclamo`, `stg.tienda`, con truncado previo y todas las columnas como texto.
  4. Stored procedure `sp_validar_contrato`: compara columnas de staging con el contrato. Si falta un campo requerido, lanza error. La rama de fallo llama `ctl.sp_marcar_falla`.
  5. `sp_trusted_merge`: aplica controles fila por fila, clasifica en insertada, actualizada, omitida o rechazada, y escribe rechazos en `quar.rechazo` con motivo.
  6. `sp_preparar_hecho_despacho`, marca objeto LISTO.
  7. If `simular_falla = tras_despacho`: llama un procedimiento que lanza error. Es la interrupción de P8.
  8. `sp_preparar_hecho_reclamo`, marca LISTO.
  9. `ctl.sp_publicar_corte`.
  10. `ctl.sp_cerrar_lote`: volúmenes y estado final.
- Disparo manual con parámetros. Opcionalmente un trigger semanal.

Si Data Factory no se logra registrar en la suscripción, alternativa válida: un script Python con `pyodbc` ejecutado desde Azure Cloud Shell, con los mismos parámetros, llamando los mismos procedimientos almacenados. Las transformaciones siguen corriendo en la nube porque son T-SQL en Azure SQL.

**Archivos y hash.** Cada lote se sube a `raw/<lote_id>/` con su `manifiesto.json`. El reenvío se detecta por hash de cada fila (`HASHBYTES('SHA2_256', …)`), no solo por hash del archivo, para que un archivo reenviado con otro nombre igual se omita.

### 6.7 Controles de calidad

| ID | Dimensión | Regla | Umbral | Severidad | Acción |
|---|---|---|---|---|---|
| C1 | Esquema | Campos requeridos y tipos según contrato | 0 faltantes | Bloqueante | Rechaza el lote, conserva último corte |
| C2 | Unicidad | Duplicado exacto por clave y versión | sin tope | Aislable | Se omite y se cuenta |
| C3 | Unicidad | Misma clave y versión con contenido distinto | 0 | Aislable | Cuarentena por conflicto |
| C4 | Completitud | Campos requeridos no nulos | 0 por fila | Aislable | Cuarentena |
| C5 | Dominio | Cantidad e importe mayores que cero, motivo y producto en catálogo | 0 | Aislable | Cuarentena |
| C6 | Integridad referencial | Tienda existe, reclamo apunta a movimiento válido del corte candidato | 0 | Aislable | Cuarentena |
| C7 | Oportunidad | Fecha de negocio en período cerrado | informativo | Informativo | Marca período como revisado |
| C8 | Volumen | Rechazos mayores al 20 por ciento del lote | 20% | Bloqueante | Detiene publicación |

Cada rechazo guarda lote, intento, clave, motivo y fila original. La clave de la tabla de rechazos incluye hash de fila y lote, así un reenvío no duplica la cuarentena y solo registra un nuevo intento en `ctl.lote`.

**Conciliación:** para cada lote, filas recibidas igual a insertadas más actualizadas más omitidas más rechazadas. El crecimiento de filas vigentes es igual a insertadas, porque las actualizaciones reemplazan versión y no suman filas vigentes, aunque sí suman una fila física con su historia.

### 6.8 Fallas y recuperación

- **Esquema (P5):** ejecutar el pipeline con LX. Debe fallar en `sp_validar_contrato`, estado `RECHAZADO_ESQUEMA`, `corte_vigente` sin cambios. Recuperación: crear una copia de la base de datos con `CREATE DATABASE sqldb-test AS COPY OF ...`, subir el archivo corregido y demostrar la carga exitosa allí. Eliminar la copia después.
- **Interrupción (P8):** lote L3 con `simular_falla=tras_despacho`. Después de la falla, consultar `bi.v_despacho` y `bi.v_reclamo` y comprobar que ambos devuelven el corte anterior. Reintentar sin falla: descarta candidato, prepara ambos y publica un solo corte nuevo.

### 6.9 Accesos

```sql
CREATE USER bi_reader WITH PASSWORD = '<secreto>';
CREATE USER etl_loader WITH PASSWORD = '<secreto>';
GRANT SELECT ON SCHEMA::bi TO bi_reader;
DENY SELECT ON SCHEMA::stg TO bi_reader;
DENY SELECT ON SCHEMA::trusted TO bi_reader;
DENY SELECT ON SCHEMA::quar TO bi_reader;
GRANT EXECUTE, SELECT, INSERT, UPDATE, DELETE ON SCHEMA::stg, trusted, cur, ctl, quar TO etl_loader;
```

Pruebas: con `bi_reader`, `SELECT * FROM bi.v_k1` funciona y `SELECT * FROM stg.despacho` debe devolver error de permiso. Capturar ambos con el mensaje. Ocultar contraseñas y direcciones IP en toda captura. Power BI usa solo `bi_reader`.

### 6.10 Costos

- Presupuesto: tomar el de Freddy y revisarlo con el volumen real. Declarar moneda, región, frecuencia y volumen.
- Costo observado: Cost Management, filtrando por el grupo de recursos y el período, con captura. Distinguirlo del estimado y declarar supuestos.
- Comparación de consultas: crear una versión lenta de K2, con subconsultas correlacionadas por mes, y una versión eficiente con agregaciones previas por mes y unión posterior. Ejecutar:

```sql
SET STATISTICS IO ON; SET STATISTICS TIME ON;
```

  Registrar lecturas lógicas y tiempo de CPU de cada una, ejecutándolas alternadas tres veces para condiciones comparables. Comprobar igualdad de resultados con `EXCEPT` en ambas direcciones, debe devolver cero filas. Con un volumen tan pequeño la diferencia de tiempo puede ser mínima, por eso las lecturas lógicas son la métrica más fiable.

### 6.11 Tablero en Power BI

- Conexión: Azure SQL Database, modo DirectQuery, usuario `bi_reader`, solo objetos `bi`.
- Página ejecutiva: seis tarjetas de KPI con meta, evolución mensual de K1 y K2, variación K4, tarjeta "Corte publicado" con `corte_id` y fecha, y un indicador de períodos revisados.
- Página de diagnóstico: detalle por marca y tienda, tasa de devolución por motivo, líneas con faltante, y comparación entre el corte actual y el anterior.
- Filtros: mes y tienda. Mostrar la zona comercial vigente a la fecha de cada evento.
- Medidas simples con suma sobre vistas, y razones calculadas como suma de numeradores entre suma de denominadores.
- Guardar `.pbix` y exportar PDF de las dos páginas. Registrar la captura del tablero antes y después de cada prueba relevante.

### 6.12 Pruebas P1 a P8 y valores esperados del Anexo E

Bitácora `pruebas/bitacora_pruebas.csv` con columnas: id, caso, lote, intento, corte, regla, esperado, observado, estado, evidencia, consulta, fecha.

**Valores esperados del Anexo E, calculados con las reglas del enunciado** (importes en PEN, bruto por mes de venta, devuelto por mes de devolución):

| Corte | Mes | Bruto K1 | Devuelto | Neto K2 |
|---|---|---|---|---|
| C0 | Enero | 100,00 | 0,00 | 100,00 |
| C0 | Febrero | 120,00 | 15,00 | 105,00 |
| C0 | Marzo | 120,00 | 8,00 | 112,00 |
| C1 | Enero | 100,00 | 0,00 | 100,00 |
| C1 | Febrero | 120,00 | 15,00 | 105,00 |
| C1 | Marzo | 160,00 | 8,00 | 152,00 |
| C2 | Enero | 100,00 | 0,00 | 100,00 |
| C2 | Febrero | 120,00 | 19,00 | 101,00 |
| C2 | Marzo | 160,00 | 8,00 | 152,00 |
| C3 | Enero | 100,00 | 0,00 | 100,00 |
| C3 | Febrero | 120,00 | 19,00 | 101,00 |
| C3 | Marzo | 180,00 | 13,00 | 167,00 |

Verificación y explicaciones que el informe debe mostrar:
- **C1 marzo:** sube 40. La versión 2 de V04 reemplaza 40 por 50 y suma 10. V05 entra una vez y suma 30. V06 va a cuarentena y su importe queda fuera.
- **Conciliación de L1:** cuatro filas de venta recibidas: una insertada (V05), una actualizada (V04), una omitida (duplicado exacto de V05) y una rechazada (V06).
- **Reenvío de L1 (P3):** todas las claves ya existen con el mismo contenido. Resultado esperado: cero insertadas, cero actualizadas, tres omitidas, una rechazada que no duplica la cuarentena. K1, K2 y el corte no cambian, solo se registra un nuevo intento.
- **C2 febrero:** D04 agrega 4 de devolución a febrero, K2 pasa de 105 a 101. Enero no cambia. D04 se refiere a V02, tienda S1, y a su fecha 2026-02-20 S1 era Norte, porque la vigencia de Centro empieza el 2026-03-01.
- **Prueba de granularidad:** unir ventas con devoluciones por línea antes de agregar multiplica V02 por sus eventos de devolución. En C0, febrero daría 240 en lugar de 120.
- **L3 e interrupción:** si se prepara ventas y se detiene antes de devoluciones, el tablero debe seguir mostrando C2: marzo bruto 160 y neto 152. Publicar solo ventas daría una mezcla incorrecta de bruto 180 con devuelto 8. Tras el reintento se publica un corte nuevo con marzo bruto 180, devuelto 13 y neto 167.
- Regiones: V01 y V02 Norte, V03 Centro. En devoluciones: D01, D02 y D04 Norte, D03 y D05 Sur.

**Resumen de cada prueba**

| Prueba | Caso propio | Anexo E |
|---|---|---|
| P1 | Cargar L0, conciliar, publicar C0, verificar seis KPIs | C0 y K1, K2 |
| P2 | Cargar L1, verificar actualización única y cuarentena | C1 |
| P3 | Reenviar L1 sin cambios, comparar claves, valores, KPIs, corte | Igual |
| P4 | Cargar L2, comparar corte previo y revisado, período de control sin cambios, versión SCD del evento tardío | C2, enero sin cambio, región D04 |
| P5 | Cargar LX, rechazo, motivo, corte intacto, recuperación en copia | No aplica |
| P6 | K2 y K3: independiente, SQL y tablero | No aplica |
| P7 | Acceso permitido y denegado, comparación de consultas, presupuesto | No aplica |
| P8 | L3 con falla simulada, reintento, un solo corte nuevo | Interrupción y C3 |

Una prueba fallida se marca como fallida con la evidencia del primer intento, y el segundo intento se registra aparte con lo que cambió.

### 6.13 Anexo E en la base de control

- Misma estructura de esquemas y mismos procedimientos. Cambian los nombres de columna: `linea`, `sede`, `canal`, `importe` en ventas, `evento` en devoluciones. Mantener los nombres del enunciado en `stg` y mapear en `trusted`.
- Los lotes L0 a L3 se transcriben a CSV desde las tablas de las páginas 7 y 8 del enunciado, incluyendo el campo `lote`.
- Región histórica: la tabla de sedes entra en L0 con las tres filas de vigencia.
- Para cada corte guardar la salida de la consulta con dos decimales y compararla con el cálculo independiente en hoja de cálculo.

### 6.14 Limpieza

Al terminar, exportar evidencias y ejecutar `99_limpieza.sql`, o eliminar el grupo de recursos desde el portal. Verificar en Cost Management que no queden recursos facturando.

### 6.15 Problemas frecuentes

- No se conecta a SQL desde casa: falta la regla de firewall con la IP vigente.
- Data Factory no copia: revisar rol "Storage Blob Data Reader" de la identidad administrada sobre la cuenta de almacenamiento.
- Fechas desplazadas un día: Azure guarda UTC, convertir con `AT TIME ZONE 'SA Pacific Standard Time'`.
- Proveedor de recursos no registrado: registrarlo en la suscripción.
- Región bloqueada por la política de la suscripción: elegir otra de la lista permitida y usarla para todo.

---

## 7. Lista final contra la rúbrica de 20 puntos

| Criterio | Puntos | Quién | Evidencia mínima |
|---|---|---|---|
| Negocio y alcance | 2 | Freddy | 1.2 y 1.3 |
| Fuentes y modelo | 4 | Rolando | Contratos, grano de ambos hechos, dimensiones, prueba de granularidad, SCD2 |
| Cargas y publicación | 5 | Edward | P1 a P5 y P8, con caso propio y Anexo E donde se exige |
| KPIs y tablero | 4 | Rolando | Seis fichas, SQL, P6, dos vistas con corte visible, tres hallazgos |
| Arquitectura y operación | 3 | Edward | Dos diseños, P7, presupuesto y consultas equivalentes |
| Reproducibilidad | 2 | Edward | README, paquete, demostración, resultados del Anexo E |
