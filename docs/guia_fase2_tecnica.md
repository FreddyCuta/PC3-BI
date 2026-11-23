# PC3 Tobotex: guía técnica completa (Fase 2 de Rolando y Fase 3 de Edward)

Este archivo reemplaza a la sección técnica del flujo anterior. El contenido del flujo era correcto, pero estaba ordenado por tema y no por momento de ejecución: en la Fase 2 se mezclaban pasos de redacción con pasos de construcción, los scripts aparecían en una sección y los procedimientos en otra, y no quedaba claro qué había que tener listo antes de cada paso. Aquí todo está en el orden en que se hace. Cada paso dice para qué sirve, qué necesitas tener antes, qué haces, qué te queda al final y cómo sabes que salió bien.

La regla de oro de la Fase 2 es simple: **primero se construye y se carga todo, después se escribe**. El Capítulo 2 se redacta al final porque casi todos sus [COMPLETAR] piden números, capturas o identificadores que solo existen cuando la base de datos ya tiene los cortes publicados.

Todo el código que aparece aquí está pensado para copiarse tal cual a los archivos del repositorio. El generador de datos y los cálculos independientes ya se probaron y producen exactamente los valores que se citan en este documento. Los scripts SQL deben ejecutarse en Azure SQL y validarse con las consultas de verificación de cada paso; si algo no cuadra, el valor esperado de este documento es la referencia.

---

## 1. La duda de los 32 GB

Sí, alcanza y sobra. No es "normal", es muchísimo más de lo que necesitamos.

El caso Tobotex completo tiene unas 710 filas de despacho y unas 55 de reclamos sumando todos los lotes. Aunque cada fila pase por cuatro capas (staging, trusted, curated y cuarentena) y le agreguemos índices, bitácoras y la base del Anexo E, todo el proyecto ocupa menos de 50 MB. Los 32 GB de la oferta gratuita son más de 600 veces eso. Ni siquiera haría falta el nivel Basic de 2 GB.

Lo que sí hay que vigilar en la oferta gratuita no es el espacio sino el **cómputo**. Cada base gratuita trae 100 000 segundos de vCore por mes, que equivalen a unas 27 horas de un procesador encendido. La base es serverless: se enciende sola cuando alguien se conecta y se apaga sola después de un rato sin actividad. Cada vez que alguien la despierta consume como mínimo medio vCore durante todo el tiempo que siga encendida, incluido el tiempo de espera antes de apagarse. Si dejan abierto SSMS o Power BI en DirectQuery toda la tarde, la base nunca se apaga. En la sección 8 está cómo configurarla para que esos segundos duren todo el mes.

Tres datos más de la oferta que importan para nosotros:

- Cada suscripción puede tener hasta 10 bases gratuitas. Usaremos tres: `sqldb-tobotex` para el caso propio, `sqldb-control` para el Anexo E y `sqldb-test` para la recuperación de la prueba P5. Las tres son gratis.
- La región que elijan para la primera base gratuita queda fija para las otras nueve. Por eso hay que decidir la región una sola vez y usarla para todo.
- Al crearla aparece la opción "Behavior when free limit reached". Elijan **Auto-pause the database until next month**. La otra opción cobra el exceso al crédito y no se puede revertir.

---

## 2. Cómo funciona la solución, en una página

Antes de tocar Azure conviene que los dos tengan clara la idea, porque todos los scripts giran alrededor de cinco conceptos.

**Lote.** Es un paquete de archivos que llega junto: L0, L1, L2, L3 y el defectuoso LX. Cada lote vive en su carpeta con un `manifiesto.json` que dice qué archivos trae, cuántas filas tiene cada uno, su huella SHA-256 y su fecha de recepción simulada.

**Intento.** Cada vez que se procesa un lote se crea un intento nuevo. Si L1 se procesa dos veces (la prueba de reenvío), habrá L1 intento 1 y L1 intento 2. Los intentos nunca se borran de la bitácora, por eso sirven de evidencia.

**Corte.** Es una versión publicada de los datos. Tiene un identificador `C-AAAAMMDD-NN` y un número de secuencia. Un lote que trae novedades genera un corte candidato; si todo sale bien el candidato pasa a publicado. Un lote sin novedades, como un reenvío idéntico, no genera corte.

**Puntero.** La tabla `ctl.corte_vigente` tiene una sola fila con el número del corte que debe ver Power BI. Publicar es cambiar ese número dentro de una transacción. Mientras el puntero no se mueve, cualquier cosa que se esté preparando es invisible para el tablero. Esto resuelve de un golpe la publicación interrumpida (P8) y la conservación del último corte válido (P5).

**Historia por corte en los hechos.** Cada fila de `cur.fact_despacho` y `cur.fact_reclamo` dice desde qué corte es visible (`corte_desde`) y hasta cuál (`corte_hasta`). Cuando llega una versión nueva de un movimiento, la versión vieja no se borra: se le pone `corte_hasta` igual al corte nuevo y se inserta la versión nueva con `corte_desde` igual al corte nuevo. Así, ver cualquier corte anterior es consultar la misma tabla con otro número, que es justo lo que pide la prueba P4.

El recorrido de un dato es este:

```
PC local (generador) ──► ADLS contenedor raw/<lote>/  (archivo intacto + manifiesto)
                              │
                              ▼  Copy de Data Factory o script Python
                         stg.*  (todo en texto, se vacía en cada intento)
                              │  sp_validar_contrato (C1 esquema)
                              ▼  sp_merge_* (C2 a C8, clasifica cada fila)
                         trusted.*  (filas válidas, todas las versiones)   quar.rechazo (inválidas con motivo)
                              │  sp_abrir_corte  →  corte CANDIDATO
                              ▼  sp_preparar_hecho_despacho  /  sp_preparar_hecho_reclamo
                         cur.fact_* y cur.dim_*  (filas nuevas invisibles hasta publicar)
                              │  sp_publicar_corte  →  mueve el puntero
                              ▼
                         bi.v_*  (solo el corte vigente)  ──►  Power BI con usuario bi_reader
```

Las tres capas que pide el enunciado quedan así: **raw** es el contenedor de ADLS con el archivo tal como llegó; **trusted** es el esquema `trusted` con los datos validados y versionados; **curated** son los esquemas `cur` y `bi` con el modelo dimensional y las vistas de consumo. `stg` es solo una mesa de trabajo de paso y `ctl` y `quar` son de control.

Cada evento tiene tres fechas y no se deben mezclar. La **fecha de negocio** (`fecha_salida` o `fecha_reclamo`) decide a qué mes pertenece el dato. La **fecha de actualización en origen** (`fecha_actualizacion_origen`) dice cuándo se modificó en el sistema de la empresa. La **fecha de ingesta** (`ingesta_utc` en trusted e `inicio_utc` en `ctl.lote`) dice cuándo entró a Azure. Además existe la **fecha de recepción simulada** del lote, que está en el manifiesto y es la que usa la política de cortes para saber si una corrección llegó tarde. La necesitamos porque procesaremos todo en noviembre aunque el caso simule que L1 llegó el 4 de octubre y L2 el 20 de octubre.

---

## 3. Lo que debe existir antes de que Rolando empiece

Rolando no arranca hasta tener esto. Si falta algo, lo resuelve Freddy antes de pasar el relevo.

1. La suscripción **Azure for Students** activa, entrando por el GitHub Student Developer Pack o directamente en azure.microsoft.com/free/students. Trae 100 dólares de crédito para 12 meses y no pide tarjeta. En el portal, en "Suscripciones", debe aparecer con estado "Activa". Captura de esa pantalla y del crédito en "Cost Management".
2. Rolando y Edward invitados a la suscripción con el rol **Colaborador** (Contributor), desde "Suscripciones", "Control de acceso (IAM)", "Agregar asignación de rol". Ellos aceptan la invitación desde el correo y luego en el portal cambian de directorio si hace falta (icono de engranaje, "Directorios y suscripciones").
3. Los proveedores de recursos registrados en "Suscripciones", "Proveedores de recursos": `Microsoft.Sql`, `Microsoft.Storage` y `Microsoft.DataFactory`. Si alguno dice "NotRegistered", se selecciona y se pulsa "Registrar". Tarda uno o dos minutos.
4. La **región elegida** y anotada. Las suscripciones de estudiante suelen tener una política que solo permite unas pocas regiones. La forma de saberlo es empezar a crear un grupo de recursos y mirar la lista. Si aparece **Brazil South** es la más cercana a Lima; si no, **East US 2** o **East US** funcionan bien y suelen estar permitidas. Todo el proyecto va en esa misma región.
5. Un presupuesto en "Cost Management", "Presupuestos", de 20 dólares mensuales con alertas al 50, 80 y 100 por ciento enviadas a los tres correos.
6. El repositorio privado `tobotex-pc3` en GitHub con las carpetas vacías de la sección 4.3 y los dos invitados con permiso de escritura.

---

## 4. Preparación de la computadora y del repositorio

### 4.1 Programas que necesitan Rolando y Edward

Todos son gratuitos y funcionan en Windows.

- **Python 3.11 o 3.12** con `pip install pyodbc pandas openpyxl`. Pandas y openpyxl solo hacen falta para los cálculos independientes en Excel.
- **Microsoft ODBC Driver 18 for SQL Server**, necesario para que `pyodbc` hable con Azure SQL. Se descarga de la página de Microsoft "Download ODBC Driver for SQL Server".
- **SQL Server Management Studio (SSMS) 21** o, si prefieren algo más liviano, **VS Code con la extensión "SQL Server (mssql)"**. Con cualquiera de los dos se ejecutan los scripts y se sacan las capturas del explorador de objetos. No usen Azure Data Studio, Microsoft lo retiró.
- **Azure Storage Explorer**, para subir las carpetas de lotes al contenedor raw arrastrando y soltando. También se puede hacer desde el portal, pero carpeta por carpeta es más lento.
- **Power BI Desktop**, desde la Microsoft Store.
- **Git** para subir los cambios al repositorio.

La autenticación es siempre con usuario y contraseña de SQL. Nadie necesita instalar Azure CLI para este trabajo, aunque Cloud Shell del portal sirve como plan B si la red de la universidad bloquea el puerto 1433.

### 4.2 Nombres que vamos a usar

Usen estos nombres exactos para que los scripts, el README y el informe coincidan. Donde dice `<ini>` van iniciales del grupo en minúsculas, por ejemplo `g11`, porque el nombre del servidor y de la cuenta de almacenamiento deben ser únicos en todo Azure.

| Recurso | Nombre | Configuración clave |
|---|---|---|
| Grupo de recursos | `rg-tobotex-pc3` | En la región elegida |
| Cuenta de almacenamiento | `sttobotexpc3<ini>` | Standard, LRS, **espacio de nombres jerárquico activado** (eso la convierte en ADLS Gen2) |
| Contenedores | `raw`, `evidencias` | Acceso privado |
| Servidor lógico SQL | `sql-tobotex-pc3-<ini>` | Autenticación SQL, administrador `sqladmin` |
| Bases de datos | `sqldb-tobotex`, `sqldb-control`, `sqldb-test` | Oferta gratuita, serverless, auto pausa al agotar el límite |
| Data Factory | `adf-tobotex-pc3-<ini>` | V2, sin integración con Git al crearla |

### 4.3 Estructura del repositorio

```
tobotex-pc3/
  README.md                         prerrequisitos, orden de ejecución, limpieza, estado del relevo
  contratos/                        contrato_despacho_v1.json, contrato_reclamo_v1.json, contrato_tienda_v1.json
                                    contrato_ventas_control_v1.json, contrato_devoluciones_control_v1.json, contrato_sedes_control_v1.json
  datos/
    generador/generar_datos.py      caso propio, semilla 2026
    generador/anexo_e.py            datos del Anexo E y su cálculo independiente
    generador/calculo_independiente_tobotex.py
    tobotex/L0 L1 L2 L3 LX          salida del generador, con manifiesto.json en cada carpeta
    control_anexoE/L0 L1 L2 L3      salida de anexo_e.py
  sql/                              00 al 12, 98 y 99 para el caso propio
  sql/control/                      los mismos scripts adaptados al Anexo E
  carga/cargar_lote.py              carga manual registrada, mismo orden que el pipeline
  adf/                              JSON exportado de pipelines, datasets y servicios vinculados
  powerbi/tobotex_pc3.pbix          y los PDF exportados de cada página
  pruebas/bitacora_pruebas.csv
  evidencias/P1 ... P8, kpis, modelo, costos
```

Nunca se suben contraseñas. La cadena de conexión se guarda en una variable de entorno de cada computadora y en el README solo aparece con `<clave>`.

---

## 5. FASE 2: Rolando

Rolando entrega al final una base de datos con los cuatro cortes del caso propio y los cuatro del Anexo E publicados, las vistas de los seis KPIs, el tablero de dos páginas y el Capítulo 2 completo. La carga la hace con el script Python, que es la "carga manual registrada" que el enunciado admite. Edward después repite todo por Data Factory y debe obtener los mismos números.

El orden tiene cuatro bloques. No se salten ninguno.

```
Bloque A  Infraestructura        R1 recursos  →  R2 conexión
Bloque B  Datos                  R3 generador  →  R4 contratos  →  R5 subir a raw
Bloque C  Base de datos y carga  R6 tablas  →  R7 procedimientos  →  R8 vistas  →  R9 cargar L0..L3  →  R10 verificar  →  R11 Anexo E
Bloque D  Consumo y redacción    R12 Power BI  →  R13 redactar Capítulo 2  →  R14 relevo
```

### Bloque A. Infraestructura

#### R1. Crear los recursos en Azure

**Para qué.** Tener el almacenamiento raw y las bases donde corren las transformaciones.
**Entrada.** Suscripción activa, región elegida, nombres de la sección 4.2.

**Qué hacer.**

1. Portal de Azure, "Grupos de recursos", "Crear". Nombre `rg-tobotex-pc3`, región elegida.
2. "Cuentas de almacenamiento", "Crear". Grupo `rg-tobotex-pc3`, nombre `sttobotexpc3<ini>`, misma región, rendimiento Standard, redundancia **LRS**. En la pestaña "Opciones avanzadas" marcar **Habilitar espacio de nombres jerárquico**. Lo demás por defecto. Crear.
3. Dentro de la cuenta, "Contenedores", crear `raw` y `evidencias` con nivel de acceso privado.
4. "Azure SQL", "Crear", "Bases de datos SQL", "Base de datos única". Arriba debe aparecer el aviso de la oferta gratuita; pulsar **Aplicar oferta** (Apply offer). Grupo `rg-tobotex-pc3`, nombre `sqldb-tobotex`. En "Servidor" pulsar "Crear nuevo": nombre `sql-tobotex-pc3-<ini>`, misma región, método **Usar autenticación de SQL**, administrador `sqladmin` y una contraseña larga que guardan en un gestor de contraseñas o en un mensaje privado del grupo, nunca en el repositorio.
5. En "Comportamiento cuando se alcance el límite gratuito" elegir **Pausar automáticamente la base de datos hasta el próximo mes**. Revisar que la tarjeta de costo diga 0 dólares al mes.
6. Pestaña "Redes": método de conectividad **Punto de conexión público**, activar **Permitir que los servicios y recursos de Azure accedan a este servidor** (Data Factory lo necesita) y **Agregar la dirección IP del cliente actual**.
7. Pestaña "Configuración adicional": origen de datos **Ninguno**. Intercalación por defecto. Crear.
8. Repetir el paso 4 para `sqldb-control` y `sqldb-test`, eligiendo el servidor que ya existe. Cada una con la oferta gratuita aplicada.
9. En cada base, "Proceso y almacenamiento": dejar vCores máximos en 2, mínimos en 0,5 y el **retraso de pausa automática en el mínimo que permita el portal**, normalmente 15 minutos. Esto alarga mucho los segundos gratuitos.
10. Data Factory se deja para Edward. Si Rolando quiere adelantar, solo la crea vacía: "Data factories", "Crear", nombre `adf-tobotex-pc3-<ini>`, misma región, versión V2, en "Configuración de Git" marcar configurar más tarde.

**Salida.** Cinco recursos visibles dentro del grupo. Captura de la vista general del grupo de recursos mostrando nombre, tipo y región de cada uno; esa captura va al Anexo D.

**Cómo saber que salió bien.** En la página de cada base aparece "Oferta gratuita aplicada" y el indicador "Free amount remaining". En la cuenta de almacenamiento, "Configuración", "Data Lake Gen2" debe decir "Habilitado".

#### R2. Probar la conexión

**Entrada.** Nombre del servidor, usuario `sqladmin` y su contraseña.

**Qué hacer.**

1. En SSMS conectar a `sql-tobotex-pc3-<ini>.database.windows.net`, autenticación SQL Server, usuario `sqladmin`. En "Opciones", "Propiedades de conexión" elegir la base `sqldb-tobotex` y subir el tiempo de espera de conexión a 60 segundos.
2. La primera conexión del día puede fallar con un error de tiempo agotado porque la base estaba pausada y está despertando. Se espera medio minuto y se vuelve a intentar. Es normal.
3. Si el error dice que la IP no tiene acceso, se agrega en el portal, servidor SQL, "Redes", "Reglas de firewall", "Agregar la dirección IP del cliente". Cada integrante agrega la suya y hay que repetirlo si cambia de red.
4. Ejecutar `SELECT @@VERSION, DB_NAME(), SYSUTCDATETIME();` para confirmar.

**Salida.** Conexión funcionando. Si la red de la universidad bloquea el puerto 1433, se trabaja desde casa o desde Cloud Shell del portal con `sqlcmd`.

### Bloque B. Datos

#### R3. Generar los datos del caso propio y del Anexo E

**Para qué.** El enunciado pide que, si los datos son simulados, se entregue el generador con su semilla y sus reglas. Con la semilla fija cualquiera que lo ejecute obtiene exactamente los mismos archivos, y eso es lo que permite al docente reproducir los resultados.

**Entrada.** Python instalado. Ninguna otra.

**Reglas de simulación** que implementa el generador y que se copian al informe en 2.1:

- Semilla 2026. Diez marcas tomadas del examen parcial. Cinco productos con precio unitario fijo: DAMASCO 0,12, TAFETAN 0,09, RETEJIDO 0,06, TROQUELADO 0,15 y CINTA 0,08 soles por unidad.
- Cada línea contractual (contrato más detalle) tiene una cantidad contratada entre 500 y 6000 en múltiplos de 100 y un total despachado entre el 90 y el 103 por ciento de lo contratado. El 85 por ciento de las líneas sale en un solo movimiento y el 15 por ciento en dos o tres parciales, con la cantidad contratada repetida en cada movimiento como en el WMS real. El importe es la cantidad despachada por el precio unitario.
- L0 tiene 200 movimientos por mes entre julio y septiembre de 2026. Fecha de recepción simulada 2026-10-01.
- Reclamos de L0: el 4 por ciento de los movimientos, salvo la marca MK TALLAS que tiene el 40 por ciento para simular un problema de calidad real. Cada reclamo devuelve entre el 5 y el 30 por ciento de lo despachado y el 5 por ciento no trae motivo. Un movimiento recibe dos reclamos, para la prueba de granularidad.
- L1, recibido el 2026-10-04 cuando septiembre todavía está abierto: 40 movimientos nuevos de octubre, un duplicado exacto de uno de ellos, dos movimientos de fines de septiembre en versión 2 con 50 unidades menos, uno con cantidad cero y otro con la tienda inexistente "GALERIA X".
- L2, recibido el 2026-10-20, después del cierre de septiembre del día 5: la versión 2 de un movimiento de LEO del 9 de septiembre con 100 unidades más, y tres reclamos de septiembre. Uno es de LEO antes del 15 de septiembre, otro de LEO después del 15 y otro de AMERICA.
- L3, recibido el 2026-10-27: 15 movimientos de octubre y 3 reclamos que apuntan a movimientos del mismo lote.
- LX: el mismo contenido de L1 sin la columna `tienda`.
- Catálogo de tiendas en L0: LEO en "Gamarra Norte" desde 2026-01-01 hasta 2026-09-15 y en "Gamarra Centro" desde 2026-09-15 abierta; AMERICA en "Gamarra Sur" desde 2026-01-01 abierta. La fecha inicial se incluye y la final se excluye.

**Qué hacer.** Guardar los tres scripts que siguen en `datos/generador/` y ejecutarlos desde la raíz del repositorio:

```
python datos/generador/generar_datos.py
python datos/generador/anexo_e.py
python datos/generador/calculo_independiente_tobotex.py
```

`generar_datos.py`:

```python
"""Generador de datos simulados Tobotex PC3. Semilla fija 2026.
Uso: python generar_datos.py  -> crea datos/tobotex/L0..L3, LX con manifiesto.json"""
import csv, json, random, hashlib, os
from datetime import date, timedelta

random.seed(2026)
BASE = os.path.join("datos", "tobotex")
MARCAS = ["YOMAX'S 2021 NUEVO", "MK TALLAS", "OUT PARIS NEGRO TALL", "MADE IN INDONESIA MI",
          "SWEET CANDY NUEVO 2", "REYNITAS CREMA DOBLE", "MAKEYDAN C/TALLA", "JADE RECTA C/TALLA",
          "CATARIS JEANS PRETIN", "CATA 12 BLANCO C/TAL"]
PRODUCTOS = {"DAMASCO": 0.12, "TAFETAN": 0.09, "RETEJIDO": 0.06, "TROQUELADO": 0.15, "CINTA": 0.08}
DETALLES = ["talla S", "talla M", "talla L", "talla XL", "combi 1", "combi 2", "talla 6", "talla 26"]
MOTIVOS = ["DEFECTO_TEJIDO", "COLOR", "MEDIDA", "CANTIDAD"]
TIENDAS = ["LEO", "AMERICA"]
COL_DESP = ["id_movimiento", "version", "fecha_salida", "tienda", "marca", "producto", "contrato",
            "detalle", "cantidad_contratada", "cantidad_despachada", "importe_pen", "fecha_actualizacion_origen"]

seq_mov, seq_rec, seq_con = [0], [0], [50000]

def nuevo_id(seq, pref, ancho=6):
    seq[0] += 1
    return f"{pref}{seq[0]:0{ancho}d}"

def fecha_rand(ini, fin):
    return ini + timedelta(days=random.randint(0, (fin - ini).days))

def movimientos_de_linea(fecha_ini, fecha_fin):
    """Una linea contractual con 1 movimiento (85 %) o 2-3 parciales (15 %)."""
    seq_con[0] += 1
    contrato = f"C-0{seq_con[0]}"
    detalle, marca = random.choice(DETALLES), random.choice(MARCAS)
    producto = random.choice(list(PRODUCTOS))
    tienda = random.choice(TIENDAS)
    contratada = random.randrange(500, 6001, 100)
    total = round(contratada * random.uniform(0.90, 1.03))
    partes = 1 if random.random() < 0.85 else random.choice([2, 3])
    cortes = sorted(random.sample(range(1, total), partes - 1)) if partes > 1 else []
    cantidades = [b - a for a, b in zip([0] + cortes, cortes + [total])]
    f = fecha_rand(fecha_ini, fecha_fin)
    filas = []
    for q in cantidades:
        filas.append({"id_movimiento": nuevo_id(seq_mov, "M"), "version": 1,
                      "fecha_salida": f.isoformat(), "tienda": tienda, "marca": marca,
                      "producto": producto, "contrato": contrato, "detalle": detalle,
                      "cantidad_contratada": contratada, "cantidad_despachada": q,
                      "importe_pen": f"{q * PRODUCTOS[producto]:.2f}",
                      "fecha_actualizacion_origen": f"{f.isoformat()} 18:00:00"})
        f = min(f + timedelta(days=random.randint(1, 4)), fecha_fin)
    return filas

def movimientos(n, ini, fin):
    out = []
    while len(out) < n:
        out += movimientos_de_linea(ini, fin)
    return out

def reclamo(mov, fecha, motivo=None):
    q = max(1, round(int(mov["cantidad_despachada"]) * random.uniform(0.05, 0.30)))
    precio = PRODUCTOS[mov["producto"]]
    if motivo is None:
        motivo = "" if random.random() < 0.05 else random.choice(MOTIVOS)
    return {"id_reclamo": nuevo_id(seq_rec, "R"), "id_movimiento": mov["id_movimiento"],
            "fecha_reclamo": fecha.isoformat(), "cantidad_devuelta": q,
            "importe_devuelto_pen": f"{q * precio:.2f}", "motivo": motivo,
            "fecha_actualizacion_origen": f"{fecha.isoformat()} 10:00:00"}

def escribir_csv(ruta, filas, columnas):
    with open(ruta, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=columnas, quoting=csv.QUOTE_MINIMAL)
        w.writeheader(); w.writerows(filas)

def escribir_jsonl(ruta, filas):
    with open(ruta, "w", encoding="utf-8", newline="\n") as fh:
        for r in filas:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")

def manifiesto(carpeta, fecha_recepcion):
    archivos = []
    for nombre in sorted(os.listdir(carpeta)):
        if nombre == "manifiesto.json":
            continue
        ruta = os.path.join(carpeta, nombre)
        datos = open(ruta, "rb").read()
        lineas = datos.count(b"\n")
        filas = lineas - 1 if nombre.endswith(".csv") else lineas
        archivos.append({"archivo": nombre, "filas": filas, "bytes": len(datos),
                         "sha256": hashlib.sha256(datos).hexdigest()})
    json.dump({"lote": os.path.basename(carpeta), "fecha_recepcion": fecha_recepcion,
               "semilla": 2026, "archivos": archivos},
              open(os.path.join(carpeta, "manifiesto.json"), "w"), indent=2)

def carpeta(lote):
    ruta = os.path.join(BASE, lote); os.makedirs(ruta, exist_ok=True); return ruta

# ---------------- L0: julio a septiembre, recepcion 2026-10-01 ----------------
L0 = []
for ini, fin in [(date(2026, 7, 1), date(2026, 7, 31)), (date(2026, 8, 1), date(2026, 8, 31)),
                 (date(2026, 9, 1), date(2026, 9, 30))]:
    L0 += movimientos(200, ini, fin)
rec0 = []
# la marca MK TALLAS simula un problema de calidad: 40 % de sus movimientos tienen reclamo, el resto 4 %
candidatos = [x for x in L0 if x["fecha_salida"] <= "2026-09-20"]
muestra = [x for x in candidatos if random.random() < (0.40 if x["marca"] == "MK TALLAS" else 0.04)]
for m in muestra:
    f = date.fromisoformat(m["fecha_salida"]) + timedelta(days=random.randint(2, 9))
    rec0.append(reclamo(m, f))
# segundo reclamo sobre el mismo movimiento: sirve para la prueba de granularidad
rec0.append(reclamo(muestra[0], date.fromisoformat(rec0[0]["fecha_reclamo"]) + timedelta(days=1)))
d = carpeta("L0")
escribir_csv(os.path.join(d, "despacho_L0.csv"), L0, COL_DESP)
escribir_jsonl(os.path.join(d, "reclamo_L0.jsonl"), rec0)
escribir_csv(os.path.join(d, "tienda_L0.csv"), [
    {"tienda": "LEO", "zona_comercial": "Gamarra Norte", "vigente_desde": "2026-01-01", "vigente_hasta": "2026-09-15"},
    {"tienda": "LEO", "zona_comercial": "Gamarra Centro", "vigente_desde": "2026-09-15", "vigente_hasta": ""},
    {"tienda": "AMERICA", "zona_comercial": "Gamarra Sur", "vigente_desde": "2026-01-01", "vigente_hasta": ""}],
    ["tienda", "zona_comercial", "vigente_desde", "vigente_hasta"])
manifiesto(d, "2026-10-01")

# ---------------- L1: octubre, recepcion 2026-10-04 (septiembre aun abierto) ----------------
L1 = movimientos(40, date(2026, 10, 1), date(2026, 10, 3))[:40]
L1.append(dict(L1[5]))                                   # duplicado exacto
for m in [x for x in L0 if x["fecha_salida"] >= "2026-09-26"][:2]:   # dos actualizaciones de version
    v = dict(m); v["version"] = 2
    v["cantidad_despachada"] = int(m["cantidad_despachada"]) - 50
    v["importe_pen"] = f"{v['cantidad_despachada'] * PRODUCTOS[m['producto']]:.2f}"
    v["fecha_actualizacion_origen"] = "2026-10-03 09:00:00"; L1.append(v)
inv1 = movimientos(1, date(2026, 10, 2), date(2026, 10, 2))[0]
inv1["cantidad_despachada"] = 0; inv1["importe_pen"] = "0.00"; L1.append(inv1)        # invalido C5
inv2 = movimientos(1, date(2026, 10, 2), date(2026, 10, 2))[0]
inv2["tienda"] = "GALERIA X"; L1.append(inv2)                                        # invalido C6
d = carpeta("L1"); escribir_csv(os.path.join(d, "despacho_L1.csv"), L1, COL_DESP); manifiesto(d, "2026-10-04")

# ---------------- LX: L1 sin la columna tienda ----------------
d = carpeta("LX")
escribir_csv(os.path.join(d, "despacho_LX.csv"), [{k: v for k, v in r.items() if k != "tienda"} for r in L1],
             [c for c in COL_DESP if c != "tienda"]); manifiesto(d, "2026-10-04")

# ---------------- L2: tardio, recepcion 2026-10-20 (septiembre ya cerrado el 05/10) ----------------
leo_sep = [x for x in L0 if x["tienda"] == "LEO" and "2026-09-01" <= x["fecha_salida"] <= "2026-09-10"]
leo_sep2 = [x for x in L0 if x["tienda"] == "LEO" and "2026-09-15" <= x["fecha_salida"] <= "2026-09-25"]
corr = dict(leo_sep[0]); corr["version"] = 2
corr["cantidad_despachada"] = int(corr["cantidad_despachada"]) + 100
corr["importe_pen"] = f"{corr['cantidad_despachada'] * PRODUCTOS[corr['producto']]:.2f}"
corr["fecha_actualizacion_origen"] = "2026-10-18 11:00:00"
dias2 = lambda m: date.fromisoformat(m["fecha_salida"]) + timedelta(days=2)
rec2 = [reclamo(leo_sep[1], dias2(leo_sep[1]), "COLOR"),            # antes del 15/09: Gamarra Norte
        reclamo(leo_sep2[0], dias2(leo_sep2[0]), "DEFECTO_TEJIDO"),  # desde el 15/09: Gamarra Centro
        reclamo(random.choice([x for x in L0 if x["tienda"] == "AMERICA" and x["fecha_salida"] >= "2026-09-01"]),
                date(2026, 9, 28), "MEDIDA")]
d = carpeta("L2"); escribir_csv(os.path.join(d, "despacho_L2.csv"), [corr], COL_DESP)
escribir_jsonl(os.path.join(d, "reclamo_L2.jsonl"), rec2); manifiesto(d, "2026-10-20")

# ---------------- L3: octubre, recepcion 2026-10-27, reclamos del mismo lote ----------------
L3 = movimientos(15, date(2026, 10, 6), date(2026, 10, 25))[:15]
rec3 = [reclamo(m, date.fromisoformat(m["fecha_salida"]) + timedelta(days=1)) for m in L3[:3]]
d = carpeta("L3"); escribir_csv(os.path.join(d, "despacho_L3.csv"), L3, COL_DESP)
escribir_jsonl(os.path.join(d, "reclamo_L3.jsonl"), rec3); manifiesto(d, "2026-10-27")
print("Listo. Revisa datos/tobotex/*/manifiesto.json")
```

`anexo_e.py` escribe los datos de control transcritos del enunciado y calcula K1 y K2 por corte sin usar SQL:

```python
"""Escribe los datos de control del Anexo E por lote y calcula K1 y K2 de forma independiente por corte.
Uso: python anexo_e.py"""
import csv, json, os
from collections import defaultdict
from decimal import Decimal as D

VENTAS = [  # lote, linea, fecha_venta, sede, producto, canal, version, importe
 ("L0","V01","2026-01-10","S1","P1","WEB",1,"100.00"), ("L0","V02","2026-02-10","S1","P1","WEB",1,"120.00"),
 ("L0","V03","2026-03-10","S1","P2","TIENDA",1,"80.00"), ("L0","V04","2026-03-12","S2","P1","WEB",1,"40.00"),
 ("L1","V04","2026-03-12","S2","P1","WEB",2,"50.00"), ("L1","V05","2026-03-20","S1","P2","WEB",1,"30.00"),
 ("L1","V05","2026-03-20","S1","P2","WEB",1,"30.00"), ("L1","V06","2026-03-21","S2","P1","WEB",1,"-5.00"),
 ("L3","V07","2026-03-25","S2","P2","TIENDA",1,"20.00")]
DEVOL = [  # lote, evento, linea, fecha_devolucion, importe
 ("L0","D01","V02","2026-02-15","10.00"), ("L0","D02","V02","2026-02-16","5.00"),
 ("L0","D03","V04","2026-03-15","8.00"), ("L2","D04","V02","2026-02-20","4.00"),
 ("L3","D05","V07","2026-03-26","5.00")]
SEDES = [("L0","S1","Norte","2026-01-01","2026-03-01"), ("L0","S1","Centro","2026-03-01",""),
         ("L0","S2","Sur","2026-01-01","")]

base = os.path.join("datos", "control_anexoE")
for lote in ["L0","L1","L2","L3"]:
    d = os.path.join(base, lote); os.makedirs(d, exist_ok=True)
    v = [r for r in VENTAS if r[0] == lote]
    if v:
        with open(os.path.join(d, f"ventas_{lote}.csv"), "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh); w.writerow(["lote","linea","fecha_venta","sede","producto","canal","version","importe"]); w.writerows(v)
    dv = [r for r in DEVOL if r[0] == lote]
    if dv:
        with open(os.path.join(d, f"devoluciones_{lote}.jsonl"), "w", encoding="utf-8", newline="\n") as fh:
            for r in dv:
                fh.write(json.dumps(dict(zip(["lote","evento","linea","fecha_devolucion","importe"], r))) + "\n")
    s = [r for r in SEDES if r[0] == lote]
    if s:
        with open(os.path.join(d, f"sedes_{lote}.csv"), "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh); w.writerow(["lote","sede","region","vigente_desde","vigente_hasta"]); w.writerows(s)

# ---- calculo independiente: aplica las reglas del protocolo sin SQL ----
def region(sede, fecha):
    for _, s, reg, desde, hasta in SEDES:
        if s == sede and desde <= fecha and (hasta == "" or fecha < hasta):
            return reg

print("corte;mes;bruto_K1;devuelto;neto_K2")
for i, lotes in enumerate([["L0"], ["L0","L1"], ["L0","L1","L2"], ["L0","L1","L2","L3"]]):
    vig = {}
    for lote, lin, f, sede, p, c, ver, imp in [r for r in VENTAS if r[0] in lotes]:
        if D(imp) <= 0:
            continue                                   # cuarentena (V06)
        if lin not in vig or ver > vig[lin][2]:
            vig[lin] = (f, sede, ver, D(imp))          # mayor version valida; duplicado exacto no suma
    bruto, dev = defaultdict(D), defaultdict(D)
    for f, sede, ver, imp in vig.values():
        bruto[f[:7]] += imp
    for lote, ev, lin, f, imp in [r for r in DEVOL if r[0] in lotes]:
        if lin in vig and D(imp) > 0:
            dev[f[:7]] += D(imp)
    for mes in ["2026-01","2026-02","2026-03"]:
        print(f"C{i};{mes};{bruto[mes]:.2f};{dev[mes]:.2f};{bruto[mes]-dev[mes]:.2f}")
print("Region D04 a su fecha:", region("S1", "2026-02-20"))
```

`calculo_independiente_tobotex.py` aplica las mismas reglas que los procedimientos SQL sobre el caso propio. Es el cálculo independiente que piden 2.4 y P6, y además sirve para saber de antemano qué debe dar cada corte:

```python
"""Calculo independiente del caso Tobotex, sin SQL. Reproduce clasificacion por lote y K1, K2, K3 por corte.
Uso: python calculo_independiente_tobotex.py"""
import csv, json, os
from collections import defaultdict
from decimal import Decimal as D

B = os.path.join("datos", "tobotex")
PRODUCTOS = {"DAMASCO", "TAFETAN", "RETEJIDO", "TROQUELADO", "CINTA"}
TIENDAS = {"LEO", "AMERICA"}
CAMPOS = ["id_movimiento","version","fecha_salida","tienda","marca","producto","contrato","detalle",
          "cantidad_contratada","cantidad_despachada","importe_pen"]

def leer(lote):
    d = os.path.join(B, lote)
    desp = list(csv.DictReader(open(os.path.join(d, f"despacho_{lote}.csv"), encoding="utf-8"))) \
        if os.path.exists(os.path.join(d, f"despacho_{lote}.csv")) else []
    rec_p = os.path.join(d, f"reclamo_{lote}.jsonl")
    rec = [json.loads(l) for l in open(rec_p, encoding="utf-8")] if os.path.exists(rec_p) else []
    return desp, rec

trusted_d, trusted_r = {}, {}     # (id, version) -> fila ; id_reclamo -> fila
def huella(r): return "|".join(str(r.get(c, "")) for c in CAMPOS)

for n, lote in enumerate(["L0", "L1", "L2", "L3"]):
    desp, rec = leer(lote)
    cnt = defaultdict(int); vistos = set()
    for r in desp:
        clave = (r["id_movimiento"], int(r["version"]))
        if any(r[c] in ("", None) for c in CAMPOS): cnt["rech"] += 1; continue
        if int(r["cantidad_despachada"]) <= 0 or D(r["importe_pen"]) <= 0 or int(r["cantidad_contratada"]) <= 0 \
           or r["producto"] not in PRODUCTOS: cnt["rech"] += 1; continue
        if r["tienda"] not in TIENDAS: cnt["rech"] += 1; continue
        h = huella(r)
        if (clave, h) in vistos or clave in trusted_d: cnt["omit"] += 1; continue
        vistos.add((clave, h))
        if any(k[0] == clave[0] for k in trusted_d): cnt["upd"] += 1
        else: cnt["ins"] += 1
        trusted_d[clave] = r
    for r in rec:
        if r["id_reclamo"] in trusted_r: cnt["r_omit"] += 1; continue
        if D(r["importe_devuelto_pen"]) <= 0 or not any(k[0] == r["id_movimiento"] for k in trusted_d):
            cnt["r_rech"] += 1; continue
        trusted_r[r["id_reclamo"]] = r; cnt["r_ins"] += 1
    # vigentes: mayor version por movimiento
    vig = {}
    for (i, v), r in trusted_d.items():
        if i not in vig or v > int(vig[i]["version"]): vig[i] = r
    bruto, dev = defaultdict(D), defaultdict(D)
    for r in vig.values(): bruto[r["fecha_salida"][:7]] += D(r["importe_pen"])
    for r in trusted_r.values(): dev[r["fecha_reclamo"][:7]] += D(r["importe_devuelto_pen"])
    print(f"== Lote {lote}: despacho leidas={len(desp)} ins={cnt['ins']} upd={cnt['upd']} omit={cnt['omit']} rech={cnt['rech']}"
          f" | reclamo leidas={len(rec)} ins={cnt['r_ins']} omit={cnt['r_omit']} rech={cnt['r_rech']}")
    for mes in sorted(set(bruto) | set(dev)):
        b, dv = bruto[mes], dev[mes]
        tasa = f"{100*dv/b:.2f}" if b else "sin base"
        print(f"   corte tras {lote} | {mes} | K1 {b:.2f} | devuelto {dv:.2f} | K2 {b-dv:.2f} | K3 {tasa} %")
```

**Salida.** Las carpetas `datos/tobotex/L0` a `L3` y `LX`, y `datos/control_anexoE/L0` a `L3`. Archivos del caso propio:

| Lote | Archivos | Filas |
|---|---|---|
| L0 | `despacho_L0.csv`, `reclamo_L0.jsonl`, `tienda_L0.csv`, `manifiesto.json` | 600, 49, 3 |
| L1 | `despacho_L1.csv`, `manifiesto.json` | 45 |
| L2 | `despacho_L2.csv`, `reclamo_L2.jsonl`, `manifiesto.json` | 1, 3 |
| L3 | `despacho_L3.csv`, `reclamo_L3.jsonl`, `manifiesto.json` | 15, 3 |
| LX | `despacho_LX.csv`, `manifiesto.json` | 45 |

**Cómo saber que salió bien.** `anexo_e.py` imprime la tabla de la sección 7.1 y debe coincidir al centavo. `calculo_independiente_tobotex.py` imprime lo que aparece en la sección 7.2. Si sus números difieren, alguien modificó el generador o se está usando una versión de Python muy distinta; en ese caso se regenera una sola vez, se suben esos archivos y desde ahí manda lo que diga el cálculo independiente de ustedes, no este documento.

#### R4. Escribir los contratos de entrada

**Para qué.** El enunciado pide un contrato versionado por fuente con campos requeridos, tipos, clave de negocio, reglas de versión y cambios de esquema admitidos. Los contratos se guardan como JSON en `contratos/` para el informe, y su lista de campos se carga en la tabla `ctl.contrato_campo`, que es la que usa el procedimiento de validación. Las dos cosas deben decir lo mismo.

**Qué hacer.** Crear los tres archivos del caso propio con esta forma. El de despacho:

```json
{
  "fuente": "despacho", "version_contrato": "1.0", "formato": "CSV UTF-8 con cabecera, separador coma",
  "propietario": "Area de despacho", "zona_horaria": "America/Lima",
  "clave_negocio": ["id_movimiento"], "version": "campo version, entero desde 1",
  "regla_version": "prevalece la version valida mas alta; misma clave y version con igual contenido se omite; con distinto contenido va a cuarentena (C3)",
  "campos": [
    {"nombre": "id_movimiento", "tipo": "string", "requerido": true},
    {"nombre": "version", "tipo": "int", "requerido": true},
    {"nombre": "fecha_salida", "tipo": "date", "requerido": true, "rol": "fecha de negocio"},
    {"nombre": "tienda", "tipo": "string", "requerido": true},
    {"nombre": "marca", "tipo": "string", "requerido": true, "sensible": true},
    {"nombre": "producto", "tipo": "string", "requerido": true},
    {"nombre": "contrato", "tipo": "string", "requerido": true},
    {"nombre": "detalle", "tipo": "string", "requerido": true},
    {"nombre": "cantidad_contratada", "tipo": "int", "requerido": true},
    {"nombre": "cantidad_despachada", "tipo": "int", "requerido": true},
    {"nombre": "importe_pen", "tipo": "decimal(18,2)", "requerido": true},
    {"nombre": "fecha_actualizacion_origen", "tipo": "datetime", "requerido": false, "rol": "fecha de actualizacion en origen"}
  ],
  "cambios_admitidos": ["agregar campos opcionales al final"],
  "cambios_no_admitidos": ["quitar o renombrar un campo requerido", "cambiar el tipo de un campo requerido"]
}
```

El de reclamo tiene clave `id_reclamo`, formato JSON por líneas, campos requeridos `id_reclamo`, `id_movimiento`, `fecha_reclamo`, `cantidad_devuelta`, `importe_devuelto_pen` y opcionales `motivo` y `fecha_actualizacion_origen`; no tiene versiones, un mismo `id_reclamo` con distinto contenido va a cuarentena. El de tienda tiene clave `tienda` más `vigente_desde`, campos requeridos `tienda`, `zona_comercial`, `vigente_desde` y opcional `vigente_hasta`, donde vacío significa abierta. Los del Anexo E se escriben igual con los nombres de columna del enunciado.

**Salida.** Seis archivos JSON en `contratos/`. La carga de `ctl.contrato_campo` ya viene en el script `05_seed.sql` del paso R6.

#### R5. Subir los lotes a la capa raw

**Para qué.** La capa raw debe conservar el archivo recibido sin modificar. El archivo que está en ADLS es la evidencia de "lo que llegó".

**Qué hacer.** En Azure Storage Explorer iniciar sesión con la cuenta de Azure, abrir la cuenta `sttobotexpc3<ini>`, contenedor `raw`, y crear esta estructura arrastrando las carpetas:

```
raw/
  tobotex/L0/  despacho_L0.csv  reclamo_L0.jsonl  tienda_L0.csv  manifiesto.json
  tobotex/L1/  ...
  tobotex/L2/  tobotex/L3/  tobotex/LX/
  control/L0/  ventas_L0.csv  devoluciones_L0.jsonl  sedes_L0.csv
  control/L1/  control/L2/  control/L3/
```

En la PC3 el enunciado pide distinguir lo recibido; por eso nadie edita un archivo dentro de raw. Si hay que corregir algo, se sube un lote nuevo, como hace LX.

**Salida.** Captura del contenedor con las carpetas y, al abrir `tobotex/L0`, los cuatro archivos con su tamaño. El tamaño debe coincidir con el campo `bytes` del manifiesto.

### Bloque C. Base de datos y carga

#### R6. Crear esquemas, tablas, catálogos y usuarios

**Para qué.** Dejar la estructura completa en la que caen los datos.
**Entrada.** Conexión como `sqladmin` a `sqldb-tobotex`.

**Qué hacer.** Ejecutar en orden, uno por uno, los scripts siguientes. Cada uno se guarda en `sql/` con su número.

`00_esquemas.sql` crea los seis esquemas. Todos pertenecen a `dbo`, y eso es importante para la seguridad del paso E7: como las vistas de `bi` y las tablas de `cur` tienen el mismo dueño, el usuario de Power BI puede leer las vistas sin tener permiso sobre las tablas.

```sql
-- 00_esquemas.sql  v1.0  Ejecutar como administrador del servidor en sqldb-tobotex
CREATE SCHEMA stg     AUTHORIZATION dbo;   -- copia del archivo en texto, se vacia en cada lote
GO
CREATE SCHEMA trusted AUTHORIZATION dbo;   -- filas validadas y tipificadas, todas las versiones
GO
CREATE SCHEMA cur     AUTHORIZATION dbo;   -- modelo dimensional con historia por corte
GO
CREATE SCHEMA bi      AUTHORIZATION dbo;   -- vistas de consumo, lo unico que ve Power BI
GO
CREATE SCHEMA ctl     AUTHORIZATION dbo;   -- bitacora de lotes, cortes, contratos
GO
CREATE SCHEMA quar    AUTHORIZATION dbo;   -- cuarentena de filas rechazadas
GO
```

`01_control.sql` crea la bitácora de lotes, los cortes, el puntero, el contrato y el registro de períodos revisados. En `ctl.lote` cada intento tiene una fila resumen con `fuente = 'LOTE'` y una fila por cada fuente que trajo datos, con las cuatro cifras de la conciliación.

```sql
-- 01_control.sql  v1.0
CREATE TABLE ctl.lote (
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, fuente VARCHAR(20) NOT NULL,   -- fuente 'LOTE' = fila resumen
  fecha_recepcion DATE NOT NULL, archivo NVARCHAR(300) NULL,
  filas_leidas INT NULL, filas_ins INT NULL, filas_upd INT NULL, filas_omit INT NULL, filas_rech INT NULL,
  estado VARCHAR(20) NOT NULL, mensaje NVARCHAR(400) NULL, corte_seq INT NULL, run_id VARCHAR(80) NULL,
  inicio_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(), fin_utc DATETIME2(0) NULL,
  CONSTRAINT pk_lote PRIMARY KEY (lote_id, intento, fuente));

CREATE TABLE ctl.corte (
  corte_seq INT NOT NULL PRIMARY KEY, corte_id VARCHAR(20) NOT NULL UNIQUE,
  estado VARCHAR(12) NOT NULL,          -- CANDIDATO, PUBLICADO, DESCARTADO
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL,
  creado_utc DATETIME2(0) NOT NULL, publicado_utc DATETIME2(0) NULL);

CREATE TABLE ctl.corte_objeto (
  corte_seq INT NOT NULL, objeto VARCHAR(40) NOT NULL, estado VARCHAR(12) NOT NULL, filas INT NOT NULL,
  CONSTRAINT pk_corte_objeto PRIMARY KEY (corte_seq, objeto));

CREATE TABLE ctl.corte_vigente (id INT NOT NULL PRIMARY KEY CHECK (id = 1), corte_seq INT NOT NULL);
INSERT INTO ctl.corte_vigente VALUES (1, 0);          -- 0 = aun no hay nada publicado

CREATE TABLE ctl.contrato_campo (
  fuente VARCHAR(20) NOT NULL, version_contrato VARCHAR(5) NOT NULL, campo SYSNAME NOT NULL,
  tipo VARCHAR(20) NOT NULL, requerido BIT NOT NULL,
  CONSTRAINT pk_contrato_campo PRIMARY KEY (fuente, version_contrato, campo));

CREATE TABLE ctl.periodo_revisado (
  corte_seq INT NOT NULL, periodo CHAR(7) NOT NULL, hecho VARCHAR(20) NOT NULL, filas INT NOT NULL,
  CONSTRAINT pk_periodo_revisado PRIMARY KEY (corte_seq, periodo, hecho));
```

`02_stg.sql` crea staging, todo en texto. Así una fila mal formada nunca rompe la copia; la que decide si sirve o no es la validación del paso siguiente.

```sql
-- 02_stg.sql  v1.0  Todo en texto: staging no rechaza nada, solo recibe
CREATE TABLE stg.despacho (
  id_movimiento NVARCHAR(100), version NVARCHAR(100), fecha_salida NVARCHAR(100), tienda NVARCHAR(100),
  marca NVARCHAR(200), producto NVARCHAR(100), contrato NVARCHAR(100), detalle NVARCHAR(100),
  cantidad_contratada NVARCHAR(100), cantidad_despachada NVARCHAR(100), importe_pen NVARCHAR(100),
  fecha_actualizacion_origen NVARCHAR(100), lote_id VARCHAR(10), archivo NVARCHAR(300));
CREATE TABLE stg.reclamo (
  id_reclamo NVARCHAR(100), id_movimiento NVARCHAR(100), fecha_reclamo NVARCHAR(100),
  cantidad_devuelta NVARCHAR(100), importe_devuelto_pen NVARCHAR(100), motivo NVARCHAR(100),
  fecha_actualizacion_origen NVARCHAR(100), lote_id VARCHAR(10), archivo NVARCHAR(300));
CREATE TABLE stg.tienda (
  tienda NVARCHAR(100), zona_comercial NVARCHAR(100), vigente_desde NVARCHAR(100), vigente_hasta NVARCHAR(100),
  lote_id VARCHAR(10), archivo NVARCHAR(300));
```

`03_trusted.sql` crea la capa validada y la cuarentena. La clave primaria de `trusted.despacho` es `id_movimiento` más `version`, por eso una misma versión no puede entrar dos veces. La restricción única de `quar.rechazo` sobre fuente, lote y huella de fila impide que un reenvío duplique la cuarentena.

```sql
-- 03_trusted.sql  v1.0  Solo inserciones: cada version valida se guarda una vez
CREATE TABLE trusted.despacho (
  id_movimiento VARCHAR(20) NOT NULL, version INT NOT NULL, fecha_salida DATE NOT NULL, tienda VARCHAR(10) NOT NULL,
  marca NVARCHAR(100) NOT NULL, producto VARCHAR(20) NOT NULL, contrato VARCHAR(20) NOT NULL, detalle VARCHAR(20) NOT NULL,
  cantidad_contratada INT NOT NULL, cantidad_despachada INT NOT NULL, importe_pen DECIMAL(18,2) NOT NULL,
  fecha_actualizacion_origen DATETIME2(0) NULL, hash_fila CHAR(64) NOT NULL,
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, ingesta_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT pk_trusted_despacho PRIMARY KEY (id_movimiento, version));
CREATE TABLE trusted.reclamo (
  id_reclamo VARCHAR(20) NOT NULL PRIMARY KEY, id_movimiento VARCHAR(20) NOT NULL, fecha_reclamo DATE NOT NULL,
  cantidad_devuelta INT NOT NULL, importe_devuelto_pen DECIMAL(18,2) NOT NULL, motivo VARCHAR(30) NULL,
  fecha_actualizacion_origen DATETIME2(0) NULL, hash_fila CHAR(64) NOT NULL,
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, ingesta_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME());
CREATE TABLE trusted.tienda (
  tienda VARCHAR(10) NOT NULL, zona_comercial VARCHAR(40) NOT NULL, vigente_desde DATE NOT NULL, vigente_hasta DATE NOT NULL,
  lote_id VARCHAR(10) NOT NULL, CONSTRAINT pk_trusted_tienda PRIMARY KEY (tienda, vigente_desde));
CREATE TABLE quar.rechazo (
  rechazo_id BIGINT IDENTITY PRIMARY KEY, fuente VARCHAR(20) NOT NULL, lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL,
  clave NVARCHAR(100) NULL, control VARCHAR(5) NOT NULL, motivo NVARCHAR(200) NOT NULL, hash_fila CHAR(64) NOT NULL,
  fila_json NVARCHAR(MAX) NULL, registrado_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT uq_rechazo UNIQUE (fuente, lote_id, hash_fila));   -- un reenvio no duplica la cuarentena
```

`04_curated.sql` crea el modelo dimensional. La dimensión de marca guarda el nombre real, que es sensible, y un código derivado con SHA-256 que es lo único que ve el rol BI.

```sql
-- 04_curated.sql  v1.0  Dimensiones y hechos. Miembro desconocido = -1
CREATE TABLE cur.dim_fecha (
  fecha_sk INT NOT NULL PRIMARY KEY, fecha DATE NOT NULL UNIQUE, anio SMALLINT NOT NULL, mes TINYINT NOT NULL,
  periodo CHAR(7) NOT NULL, nombre_mes VARCHAR(12) NOT NULL);
CREATE TABLE cur.dim_tienda (                       -- SCD tipo 2 sobre zona_comercial
  tienda_sk INT IDENTITY PRIMARY KEY, tienda VARCHAR(10) NOT NULL, zona_comercial VARCHAR(40) NOT NULL,
  vigente_desde DATE NOT NULL, vigente_hasta DATE NOT NULL, es_actual BIT NOT NULL,
  CONSTRAINT uq_dim_tienda UNIQUE (tienda, vigente_desde));
CREATE TABLE cur.dim_marca (                        -- tipo 1; el nombre es sensible, BI solo ve el codigo
  marca_sk INT IDENTITY PRIMARY KEY, marca NVARCHAR(100) NOT NULL UNIQUE,
  marca_codigo AS CAST('MK-' + LEFT(CONVERT(CHAR(64), HASHBYTES('SHA2_256', marca), 2), 8) AS VARCHAR(11)) PERSISTED);
CREATE TABLE cur.dim_producto (
  producto_sk INT IDENTITY PRIMARY KEY, producto VARCHAR(20) NOT NULL UNIQUE, familia VARCHAR(30) NOT NULL);
CREATE TABLE cur.dim_motivo (
  motivo_sk INT IDENTITY PRIMARY KEY, motivo VARCHAR(30) NOT NULL UNIQUE, es_valido BIT NOT NULL);

CREATE TABLE cur.fact_despacho (                    -- grano: un movimiento en una version, visible en un rango de cortes
  despacho_sk BIGINT IDENTITY PRIMARY KEY, id_movimiento VARCHAR(20) NOT NULL, version INT NOT NULL,
  fecha_sk INT NOT NULL REFERENCES cur.dim_fecha(fecha_sk), tienda_sk INT NOT NULL REFERENCES cur.dim_tienda(tienda_sk),
  marca_sk INT NOT NULL REFERENCES cur.dim_marca(marca_sk), producto_sk INT NOT NULL REFERENCES cur.dim_producto(producto_sk),
  contrato VARCHAR(20) NOT NULL, detalle VARCHAR(20) NOT NULL,
  cantidad_contratada INT NOT NULL, cantidad_despachada INT NOT NULL, importe_pen DECIMAL(18,2) NOT NULL,
  hash_fila CHAR(64) NOT NULL, lote_id VARCHAR(10) NOT NULL, corte_desde INT NOT NULL, corte_hasta INT NULL);
CREATE TABLE cur.fact_reclamo (                     -- grano: un evento de reclamo
  reclamo_sk BIGINT IDENTITY PRIMARY KEY, id_reclamo VARCHAR(20) NOT NULL, id_movimiento VARCHAR(20) NOT NULL,
  fecha_sk INT NOT NULL REFERENCES cur.dim_fecha(fecha_sk), tienda_sk INT NOT NULL REFERENCES cur.dim_tienda(tienda_sk),
  marca_sk INT NOT NULL REFERENCES cur.dim_marca(marca_sk), producto_sk INT NOT NULL REFERENCES cur.dim_producto(producto_sk),
  motivo_sk INT NOT NULL REFERENCES cur.dim_motivo(motivo_sk),
  cantidad_devuelta INT NOT NULL, importe_devuelto_pen DECIMAL(18,2) NOT NULL,
  hash_fila CHAR(64) NOT NULL, lote_id VARCHAR(10) NOT NULL, corte_desde INT NOT NULL, corte_hasta INT NULL);
CREATE INDEX ix_fd_corte ON cur.fact_despacho (corte_desde, corte_hasta) INCLUDE (id_movimiento);
CREATE INDEX ix_fr_corte ON cur.fact_reclamo  (corte_desde, corte_hasta) INCLUDE (id_reclamo);
```

`05_seed.sql` llena el calendario de 2026, los catálogos de producto y motivo, los miembros desconocidos con clave -1 y los campos de los tres contratos.

```sql
-- 05_seed.sql  v1.0  Calendario, catalogos, miembros desconocidos y contratos
SET LANGUAGE Spanish;
WITH d AS (SELECT CAST('2026-01-01' AS DATE) AS f UNION ALL SELECT DATEADD(day, 1, f) FROM d WHERE f < '2026-12-31')
INSERT INTO cur.dim_fecha (fecha_sk, fecha, anio, mes, periodo, nombre_mes)
SELECT YEAR(f)*10000 + MONTH(f)*100 + DAY(f), f, YEAR(f), MONTH(f), CONVERT(CHAR(7), f, 126), DATENAME(month, f)
FROM d OPTION (MAXRECURSION 400);

SET IDENTITY_INSERT cur.dim_tienda ON;
INSERT INTO cur.dim_tienda (tienda_sk, tienda, zona_comercial, vigente_desde, vigente_hasta, es_actual)
VALUES (-1, 'DESCONOCIDA', 'Desconocida', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT cur.dim_tienda OFF;
SET IDENTITY_INSERT cur.dim_marca ON;
INSERT INTO cur.dim_marca (marca_sk, marca) VALUES (-1, N'DESCONOCIDA');
SET IDENTITY_INSERT cur.dim_marca OFF;
SET IDENTITY_INSERT cur.dim_producto ON;
INSERT INTO cur.dim_producto (producto_sk, producto, familia) VALUES (-1, 'DESCONOCIDO', 'Desconocida');
SET IDENTITY_INSERT cur.dim_producto OFF;
INSERT INTO cur.dim_producto (producto, familia) VALUES
 ('DAMASCO','Etiqueta tejida'), ('TAFETAN','Etiqueta tejida'), ('RETEJIDO','Etiqueta tejida'),
 ('TROQUELADO','Troquelado'), ('CINTA','Cinta continua');
SET IDENTITY_INSERT cur.dim_motivo ON;
INSERT INTO cur.dim_motivo (motivo_sk, motivo, es_valido) VALUES (-1, 'SIN_MOTIVO', 0);
SET IDENTITY_INSERT cur.dim_motivo OFF;
INSERT INTO cur.dim_motivo (motivo, es_valido) VALUES ('DEFECTO_TEJIDO',1), ('COLOR',1), ('MEDIDA',1), ('CANTIDAD',1);

INSERT INTO ctl.contrato_campo (fuente, version_contrato, campo, tipo, requerido) VALUES
 ('despacho','1.0','id_movimiento','string',1), ('despacho','1.0','version','int',1),
 ('despacho','1.0','fecha_salida','date',1), ('despacho','1.0','tienda','string',1),
 ('despacho','1.0','marca','string',1), ('despacho','1.0','producto','string',1),
 ('despacho','1.0','contrato','string',1), ('despacho','1.0','detalle','string',1),
 ('despacho','1.0','cantidad_contratada','int',1), ('despacho','1.0','cantidad_despachada','int',1),
 ('despacho','1.0','importe_pen','decimal(18,2)',1), ('despacho','1.0','fecha_actualizacion_origen','datetime',0),
 ('reclamo','1.0','id_reclamo','string',1), ('reclamo','1.0','id_movimiento','string',1),
 ('reclamo','1.0','fecha_reclamo','date',1), ('reclamo','1.0','cantidad_devuelta','int',1),
 ('reclamo','1.0','importe_devuelto_pen','decimal(18,2)',1), ('reclamo','1.0','motivo','string',0),
 ('reclamo','1.0','fecha_actualizacion_origen','datetime',0),
 ('tienda','1.0','tienda','string',1), ('tienda','1.0','zona_comercial','string',1),
 ('tienda','1.0','vigente_desde','date',1), ('tienda','1.0','vigente_hasta','date',0);
```

`10_seguridad.sql` se ejecuta también ahora, porque el script de carga se conecta como `etl_loader`. Antes de ejecutarlo se reemplazan las dos contraseñas por unas largas y se guardan fuera del repositorio.

```sql
-- 10_seguridad.sql  v1.0  Usuarios contenidos en la base. Las claves NO se suben al repositorio
CREATE USER etl_loader WITH PASSWORD = '<clave_larga_etl>';
CREATE USER bi_reader  WITH PASSWORD = '<clave_larga_bi>';
GRANT SELECT, INSERT, DELETE ON SCHEMA::stg TO etl_loader;          -- Copy de Data Factory y validacion dinamica
GRANT EXECUTE ON SCHEMA::ctl TO etl_loader;
GRANT EXECUTE ON SCHEMA::trusted TO etl_loader;
GRANT EXECUTE ON SCHEMA::cur TO etl_loader;
GRANT SELECT ON ctl.lote TO etl_loader;                             -- para imprimir el resumen del lote
GRANT SELECT ON SCHEMA::bi TO bi_reader;                            -- solo la capa de consumo
DENY SELECT ON SCHEMA::stg TO bi_reader;
DENY SELECT ON SCHEMA::trusted TO bi_reader;
DENY SELECT ON SCHEMA::quar TO bi_reader;
DENY SELECT ON SCHEMA::cur TO bi_reader;                            -- incluye el nombre real de la marca
-- Las vistas de bi leen cur y ctl por encadenamiento de propiedad: todos los esquemas son de dbo,
-- asi que el DENY sobre cur no rompe las vistas, pero si impide leer cur directamente.
```

**Salida.** Captura del explorador de objetos de SSMS con los seis esquemas desplegados, que va al informe en 2.2 como evidencia del modelo físico.

**Cómo saber que salió bien.**

```sql
SELECT s.name AS esquema, COUNT(*) AS tablas FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id GROUP BY s.name;
-- cur 7, ctl 6, quar 1, stg 3, trusted 3
SELECT COUNT(*) FROM cur.dim_fecha;          -- 365
SELECT * FROM ctl.contrato_campo;            -- 23 filas
```

#### R7. Crear los procedimientos de carga, clasificación y publicación

**Para qué.** Aquí está toda la lógica del desafío. Son los mismos procedimientos que llamará Data Factory, por eso lo que Rolando pruebe con Python queda probado para Edward.

**Qué hacer.** Ejecutar los tres scripts como `sqladmin`.

`06_sp_control.sql` tiene el inicio de lote, la validación de contrato, el registro de fallas y el descarte de candidatos. Fíjense en que `sp_iniciar_lote` llama primero a `sp_descartar_candidatos`: si el intento anterior quedó a medias, lo limpia antes de empezar. Eso hace que el reintento de P8 parta siempre de un estado limpio sin que nadie tenga que hacer nada a mano.

```sql
-- 06_sp_control.sql  v1.0  Inicio de lote, validacion de contrato, fallas y descarte de candidatos
CREATE OR ALTER PROCEDURE ctl.sp_descartar_candidatos
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  BEGIN TRAN;
    -- 1. quitar las filas que un corte candidato inserto y reabrir las que cerro
    DELETE f FROM cur.fact_despacho f JOIN ctl.corte c ON c.corte_seq = f.corte_desde WHERE c.estado = 'CANDIDATO';
    DELETE f FROM cur.fact_reclamo  f JOIN ctl.corte c ON c.corte_seq = f.corte_desde WHERE c.estado = 'CANDIDATO';
    UPDATE f SET corte_hasta = NULL FROM cur.fact_despacho f JOIN ctl.corte c ON c.corte_seq = f.corte_hasta WHERE c.estado = 'CANDIDATO';
    UPDATE f SET corte_hasta = NULL FROM cur.fact_reclamo  f JOIN ctl.corte c ON c.corte_seq = f.corte_hasta WHERE c.estado = 'CANDIDATO';
    DELETE p FROM ctl.periodo_revisado p JOIN ctl.corte c ON c.corte_seq = p.corte_seq WHERE c.estado = 'CANDIDATO';
    UPDATE ctl.corte SET estado = 'DESCARTADO' WHERE estado = 'CANDIDATO';
    -- 2. un intento que no termino nunca queda como fallido
    UPDATE ctl.lote SET estado = 'FALLIDO', mensaje = ISNULL(mensaje, 'Interrumpido sin cierre'), fin_utc = ISNULL(fin_utc, SYSUTCDATETIME())
    WHERE fuente = 'LOTE' AND estado = 'EN_PROCESO';
    -- 3. las filas trusted de intentos no publicados se borran para que el reintento clasifique desde cero
    DELETE d FROM trusted.despacho d JOIN ctl.lote l ON l.lote_id = d.lote_id AND l.intento = d.intento AND l.fuente = 'LOTE'
    WHERE l.estado NOT IN ('PUBLICADO', 'SIN_CAMBIOS');
    DELETE r FROM trusted.reclamo r JOIN ctl.lote l ON l.lote_id = r.lote_id AND l.intento = r.intento AND l.fuente = 'LOTE'
    WHERE l.estado NOT IN ('PUBLICADO', 'SIN_CAMBIOS');
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_iniciar_lote @lote_id VARCHAR(10), @fecha_recepcion DATE, @run_id VARCHAR(80)
AS
BEGIN
  SET NOCOUNT ON;
  EXEC ctl.sp_descartar_candidatos;           -- deja la base limpia si el intento anterior quedo a medias
  DELETE FROM stg.despacho; DELETE FROM stg.reclamo; DELETE FROM stg.tienda;
  DECLARE @intento INT = (SELECT ISNULL(MAX(intento), 0) + 1 FROM ctl.lote WHERE lote_id = @lote_id);
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, estado, run_id)
  VALUES (@lote_id, @intento, 'LOTE', @fecha_recepcion, 'EN_PROCESO', @run_id);
  SELECT @intento AS intento;                 -- Data Factory lo lee con una actividad Lookup
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_validar_contrato
  @lote_id VARCHAR(10), @intento INT, @fuente VARCHAR(20), @columnas NVARCHAR(MAX) = NULL
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @faltan NVARCHAR(400);
  IF NULLIF(@columnas, '') IS NOT NULL
    -- CSV: se compara la cabecera recibida (JSON [{"name":...}]) con los campos requeridos del contrato
    SELECT @faltan = STRING_AGG(c.campo, ', ')
    FROM ctl.contrato_campo c
    WHERE c.fuente = @fuente AND c.version_contrato = '1.0' AND c.requerido = 1
      AND NOT EXISTS (SELECT 1 FROM OPENJSON(@columnas) WITH (name NVARCHAR(128) '$.name') j
                      WHERE LOWER(LTRIM(RTRIM(j.name))) = c.campo);
  ELSE
  BEGIN
    -- JSON: un campo requerido que no trae ningun valor en todo el lote se considera ausente
    DECLARE @sql NVARCHAR(MAX);
    SELECT @sql = STRING_AGG(CONVERT(NVARCHAR(MAX), CONCAT(N'SELECT ''', campo, N''' AS campo WHERE NOT EXISTS (SELECT 1 FROM stg.',
                  @fuente, N' WHERE lote_id = @l AND ', QUOTENAME(campo), N' IS NOT NULL)')), N' UNION ALL ')
    FROM ctl.contrato_campo WHERE fuente = @fuente AND version_contrato = '1.0' AND requerido = 1;
    CREATE TABLE #faltan (campo SYSNAME);
    INSERT INTO #faltan EXEC sp_executesql @sql, N'@l VARCHAR(10)', @l = @lote_id;
    SELECT @faltan = STRING_AGG(campo, ', ') FROM #faltan;
  END
  IF @faltan IS NOT NULL
  BEGIN
    DECLARE @msg NVARCHAR(400) = CONCAT(N'C1 esquema incompatible en ', @fuente, N': falta ', @faltan);
    UPDATE ctl.lote SET estado = 'RECHAZADO_ESQUEMA', mensaje = @msg, fin_utc = SYSUTCDATETIME()
    WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE';
    THROW 50010, @msg, 1;
  END
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_marcar_falla @lote_id VARCHAR(10), @intento INT, @mensaje NVARCHAR(400)
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE ctl.lote SET estado = 'FALLIDO', mensaje = LEFT(@mensaje, 400), fin_utc = SYSUTCDATETIME()
  WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE' AND estado = 'EN_PROCESO';
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_simular_falla
AS
BEGIN
  THROW 50099, 'Falla simulada despues de preparar fact_despacho (prueba P8)', 1;
END
GO
```

`07_sp_trusted.sql` clasifica cada fila. El orden de los `WHEN` es la prioridad de los controles: primero completitud, luego dominio, integridad referencial, ventana de corrección, conflicto de versión, duplicado dentro del lote, ya cargado (reenvío), versión obsoleta, actualización y alta. Cada fila termina en exactamente una categoría, por eso siempre se cumple que leídas es igual a insertadas más actualizadas más omitidas más rechazadas.

```sql
-- 07_sp_trusted.sql  v1.0  Clasificacion fila por fila: INS, UPD, omitida o rechazada con su control
CREATE OR ALTER PROCEDURE trusted.sp_merge_tienda @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.tienda WHERE lote_id = @lote_id) RETURN;
  INSERT INTO trusted.tienda (tienda, zona_comercial, vigente_desde, vigente_hasta, lote_id)
  SELECT UPPER(TRIM(s.tienda)), TRIM(s.zona_comercial), CAST(s.vigente_desde AS DATE),
         ISNULL(TRY_CAST(NULLIF(TRIM(s.vigente_hasta), '') AS DATE), '9999-12-31'), @lote_id
  FROM stg.tienda s
  WHERE s.lote_id = @lote_id
    AND NOT EXISTS (SELECT 1 FROM trusted.tienda t WHERE t.tienda = UPPER(TRIM(s.tienda)) AND t.vigente_desde = CAST(s.vigente_desde AS DATE));
  DECLARE @ins INT = @@ROWCOUNT;
  -- la dimension SCD2 se arma directamente con las vigencias del catalogo: inicio incluido, fin excluido
  INSERT INTO cur.dim_tienda (tienda, zona_comercial, vigente_desde, vigente_hasta, es_actual)
  SELECT t.tienda, t.zona_comercial, t.vigente_desde, t.vigente_hasta, 0
  FROM trusted.tienda t
  WHERE NOT EXISTS (SELECT 1 FROM cur.dim_tienda d WHERE d.tienda = t.tienda AND d.vigente_desde = t.vigente_desde);
  UPDATE cur.dim_tienda SET es_actual = CASE WHEN vigente_hasta = '9999-12-31' THEN 1 ELSE 0 END WHERE tienda_sk > 0;
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  SELECT @lote_id, @intento, 'tienda', l.fecha_recepcion, (SELECT TOP 1 archivo FROM stg.tienda WHERE lote_id = @lote_id),
         (SELECT COUNT(*) FROM stg.tienda WHERE lote_id = @lote_id), @ins, 0,
         (SELECT COUNT(*) FROM stg.tienda WHERE lote_id = @lote_id) - @ins, 0, 'CLASIFICADO'
  FROM ctl.lote l WHERE l.lote_id = @lote_id AND l.intento = @intento AND l.fuente = 'LOTE';
END
GO
CREATE OR ALTER PROCEDURE trusted.sp_merge_despacho @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.despacho WHERE lote_id = @lote_id) RETURN;
  DECLARE @recepcion DATE = (SELECT fecha_recepcion FROM ctl.lote WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE');

  -- 1. tipificacion. Un texto vacio es nulo y lo que no convierte queda nulo (lo atrapa C4)
  SELECT NULLIF(TRIM(s.id_movimiento), '')                         AS id_movimiento,
         TRY_CAST(NULLIF(TRIM(s.version), '') AS INT)               AS version,
         TRY_CAST(NULLIF(TRIM(s.fecha_salida), '') AS DATE)         AS fecha_salida,
         UPPER(NULLIF(TRIM(s.tienda), ''))                          AS tienda,
         NULLIF(TRIM(s.marca), '')                                  AS marca,
         UPPER(NULLIF(TRIM(s.producto), ''))                        AS producto,
         NULLIF(TRIM(s.contrato), '')                               AS contrato,
         NULLIF(TRIM(s.detalle), '')                                AS detalle,
         TRY_CAST(NULLIF(TRIM(s.cantidad_contratada), '') AS INT)   AS cantidad_contratada,
         TRY_CAST(NULLIF(TRIM(s.cantidad_despachada), '') AS INT)   AS cantidad_despachada,
         TRY_CAST(NULLIF(TRIM(s.importe_pen), '') AS DECIMAL(18,2)) AS importe_pen,
         TRY_CAST(NULLIF(TRIM(s.fecha_actualizacion_origen), '') AS DATETIME2(0)) AS fecha_actualizacion_origen,
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|', s.id_movimiento, s.version, s.fecha_salida, s.tienda, s.marca,
                 s.producto, s.contrato, s.detalle, s.cantidad_contratada, s.cantidad_despachada, s.importe_pen)), 2) AS hash_fila,
         (SELECT s.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS fila_json
  INTO #t FROM stg.despacho s WHERE s.lote_id = @lote_id;

  -- 2. clasificacion. El orden de los WHEN es la prioridad de los controles
  SELECT t.*,
    CASE
      WHEN t.id_movimiento IS NULL OR t.version IS NULL OR t.fecha_salida IS NULL OR t.tienda IS NULL OR t.marca IS NULL
        OR t.producto IS NULL OR t.contrato IS NULL OR t.detalle IS NULL OR t.cantidad_contratada IS NULL
        OR t.cantidad_despachada IS NULL OR t.importe_pen IS NULL                                        THEN 'C4'
      WHEN t.cantidad_contratada <= 0 OR t.cantidad_despachada <= 0 OR t.importe_pen <= 0
        OR NOT EXISTS (SELECT 1 FROM cur.dim_producto p WHERE p.producto = t.producto AND p.producto_sk > 0) THEN 'C5'
      WHEN NOT EXISTS (SELECT 1 FROM trusted.tienda x WHERE x.tienda = t.tienda
                       AND t.fecha_salida >= x.vigente_desde AND t.fecha_salida < x.vigente_hasta)        THEN 'C6'
      WHEN @recepcion > DATEADD(day, 90, DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(t.fecha_salida), MONTH(t.fecha_salida), 1))))
                                                                                                          THEN 'C7'
      WHEN MIN(t.hash_fila) OVER (PARTITION BY t.id_movimiento, t.version)
        <> MAX(t.hash_fila) OVER (PARTITION BY t.id_movimiento, t.version)                                THEN 'C3'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento
                   AND d.version = t.version AND d.hash_fila <> t.hash_fila)                              THEN 'C3'
      WHEN ROW_NUMBER() OVER (PARTITION BY t.id_movimiento, t.version, t.hash_fila ORDER BY (SELECT NULL)) > 1 THEN 'C2'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento AND d.version = t.version) THEN 'C2R'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento AND d.version > t.version)  THEN 'VOBS'
      WHEN EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento)                           THEN 'UPD'
      ELSE 'INS' END AS control,
    ROW_NUMBER() OVER (PARTITION BY t.hash_fila ORDER BY (SELECT NULL)) AS rn_hash
  INTO #c FROM #t t;

  -- 3. conteos y control de volumen C8 antes de escribir nada
  DECLARE @leidas INT, @ins INT, @upd INT, @omit INT, @rech INT;
  SELECT @leidas = COUNT(*), @ins = SUM(IIF(control = 'INS', 1, 0)), @upd = SUM(IIF(control = 'UPD', 1, 0)),
         @omit = SUM(IIF(control IN ('C2', 'C2R', 'VOBS'), 1, 0)), @rech = SUM(IIF(control IN ('C3','C4','C5','C6','C7'), 1, 0))
  FROM #c;
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  VALUES (@lote_id, @intento, 'despacho', @recepcion, (SELECT TOP 1 archivo FROM stg.despacho WHERE lote_id = @lote_id),
          @leidas, @ins, @upd, @omit, @rech, IIF(1.0 * @rech / @leidas > 0.20, 'BLOQUEADO_C8', 'CLASIFICADO'));
  IF 1.0 * @rech / @leidas > 0.20
    THROW 50020, 'C8 los rechazos superan el 20 % del lote: no se publica', 1;

  BEGIN TRAN;
    INSERT INTO trusted.despacho (id_movimiento, version, fecha_salida, tienda, marca, producto, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, fecha_actualizacion_origen, hash_fila, lote_id, intento)
    SELECT id_movimiento, version, fecha_salida, tienda, marca, producto, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, fecha_actualizacion_origen, hash_fila, @lote_id, @intento
    FROM #c WHERE control IN ('INS', 'UPD');

    INSERT INTO quar.rechazo (fuente, lote_id, intento, clave, control, motivo, hash_fila, fila_json)
    SELECT 'despacho', @lote_id, @intento, CONCAT(c.id_movimiento, ' v', c.version), c.control,
           CASE c.control WHEN 'C3' THEN 'Misma clave y version con contenido distinto'
                          WHEN 'C4' THEN 'Campo requerido nulo o con tipo invalido'
                          WHEN 'C5' THEN 'Cantidad o importe no positivo, o producto fuera de catalogo'
                          WHEN 'C6' THEN 'Tienda inexistente o sin vigencia en la fecha de salida'
                          WHEN 'C7' THEN 'Correccion fuera de la ventana de 90 dias posterior al cierre' END,
           c.hash_fila, c.fila_json
    FROM #c c
    WHERE c.control IN ('C3','C4','C5','C6','C7') AND c.rn_hash = 1
      AND NOT EXISTS (SELECT 1 FROM quar.rechazo q WHERE q.fuente = 'despacho' AND q.lote_id = @lote_id AND q.hash_fila = c.hash_fila);
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE trusted.sp_merge_reclamo @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF NOT EXISTS (SELECT 1 FROM stg.reclamo WHERE lote_id = @lote_id) RETURN;
  DECLARE @recepcion DATE = (SELECT fecha_recepcion FROM ctl.lote WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE');

  SELECT NULLIF(TRIM(s.id_reclamo), '')                                   AS id_reclamo,
         NULLIF(TRIM(s.id_movimiento), '')                                AS id_movimiento,
         TRY_CAST(NULLIF(TRIM(s.fecha_reclamo), '') AS DATE)              AS fecha_reclamo,
         TRY_CAST(NULLIF(TRIM(s.cantidad_devuelta), '') AS INT)           AS cantidad_devuelta,
         TRY_CAST(NULLIF(TRIM(s.importe_devuelto_pen), '') AS DECIMAL(18,2)) AS importe_devuelto_pen,
         UPPER(NULLIF(TRIM(s.motivo), ''))                                AS motivo,
         TRY_CAST(NULLIF(TRIM(s.fecha_actualizacion_origen), '') AS DATETIME2(0)) AS fecha_actualizacion_origen,
         CONVERT(CHAR(64), HASHBYTES('SHA2_256', CONCAT_WS('|', s.id_reclamo, s.id_movimiento, s.fecha_reclamo,
                 s.cantidad_devuelta, s.importe_devuelto_pen, s.motivo)), 2) AS hash_fila,
         (SELECT s.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS fila_json
  INTO #t FROM stg.reclamo s WHERE s.lote_id = @lote_id;

  SELECT t.*,
    CASE
      WHEN t.id_reclamo IS NULL OR t.id_movimiento IS NULL OR t.fecha_reclamo IS NULL
        OR t.cantidad_devuelta IS NULL OR t.importe_devuelto_pen IS NULL                              THEN 'C4'
      WHEN t.cantidad_devuelta <= 0 OR t.importe_devuelto_pen <= 0                                    THEN 'C5'
      -- referencia: un movimiento valido en trusted, incluidas las altas de este mismo lote
      WHEN NOT EXISTS (SELECT 1 FROM trusted.despacho d WHERE d.id_movimiento = t.id_movimiento)       THEN 'C6'
      WHEN @recepcion > DATEADD(day, 90, DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(t.fecha_reclamo), MONTH(t.fecha_reclamo), 1))))
                                                                                                      THEN 'C7'
      WHEN MIN(t.hash_fila) OVER (PARTITION BY t.id_reclamo) <> MAX(t.hash_fila) OVER (PARTITION BY t.id_reclamo) THEN 'C3'
      WHEN EXISTS (SELECT 1 FROM trusted.reclamo r WHERE r.id_reclamo = t.id_reclamo AND r.hash_fila <> t.hash_fila) THEN 'C3'
      WHEN ROW_NUMBER() OVER (PARTITION BY t.id_reclamo, t.hash_fila ORDER BY (SELECT NULL)) > 1      THEN 'C2'
      WHEN EXISTS (SELECT 1 FROM trusted.reclamo r WHERE r.id_reclamo = t.id_reclamo)                 THEN 'C2R'
      ELSE 'INS' END AS control,
    ROW_NUMBER() OVER (PARTITION BY t.hash_fila ORDER BY (SELECT NULL)) AS rn_hash
  INTO #c FROM #t t;

  DECLARE @leidas INT, @ins INT, @omit INT, @rech INT;
  SELECT @leidas = COUNT(*), @ins = SUM(IIF(control = 'INS', 1, 0)),
         @omit = SUM(IIF(control IN ('C2', 'C2R'), 1, 0)), @rech = SUM(IIF(control IN ('C3','C4','C5','C6','C7'), 1, 0))
  FROM #c;
  INSERT INTO ctl.lote (lote_id, intento, fuente, fecha_recepcion, archivo, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado)
  VALUES (@lote_id, @intento, 'reclamo', @recepcion, (SELECT TOP 1 archivo FROM stg.reclamo WHERE lote_id = @lote_id),
          @leidas, @ins, 0, @omit, @rech, IIF(1.0 * @rech / @leidas > 0.20, 'BLOQUEADO_C8', 'CLASIFICADO'));
  IF 1.0 * @rech / @leidas > 0.20
    THROW 50021, 'C8 los rechazos de reclamos superan el 20 % del lote: no se publica', 1;

  BEGIN TRAN;
    INSERT INTO trusted.reclamo (id_reclamo, id_movimiento, fecha_reclamo, cantidad_devuelta, importe_devuelto_pen, motivo,
           fecha_actualizacion_origen, hash_fila, lote_id, intento)
    SELECT id_reclamo, id_movimiento, fecha_reclamo, cantidad_devuelta, importe_devuelto_pen, motivo,
           fecha_actualizacion_origen, hash_fila, @lote_id, @intento
    FROM #c WHERE control = 'INS';
    INSERT INTO quar.rechazo (fuente, lote_id, intento, clave, control, motivo, hash_fila, fila_json)
    SELECT 'reclamo', @lote_id, @intento, c.id_reclamo, c.control,
           CASE c.control WHEN 'C3' THEN 'Mismo reclamo con contenido distinto'
                          WHEN 'C4' THEN 'Campo requerido nulo o con tipo invalido'
                          WHEN 'C5' THEN 'Cantidad o importe devuelto no positivo'
                          WHEN 'C6' THEN 'El reclamo no apunta a un movimiento valido'
                          WHEN 'C7' THEN 'Correccion fuera de la ventana de 90 dias posterior al cierre' END,
           c.hash_fila, c.fila_json
    FROM #c c
    WHERE c.control IN ('C3','C4','C5','C6','C7') AND c.rn_hash = 1
      AND NOT EXISTS (SELECT 1 FROM quar.rechazo q WHERE q.fuente = 'reclamo' AND q.lote_id = @lote_id AND q.hash_fila = c.hash_fila);
  COMMIT;
END
GO
```

`08_sp_corte.sql` abre el corte candidato, prepara cada hecho y publica. La preparación de cada hecho termina marcando su objeto como LISTO; la publicación exige los dos LISTO, y solo entonces mueve el puntero dentro de una transacción.

```sql
-- 08_sp_corte.sql  v1.0  Corte candidato, preparacion de hechos y publicacion atomica
CREATE OR ALTER PROCEDURE ctl.sp_abrir_corte @lote_id VARCHAR(10), @intento INT
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @cambios INT = (SELECT SUM(ISNULL(filas_ins, 0) + ISNULL(filas_upd, 0)) FROM ctl.lote
                          WHERE lote_id = @lote_id AND intento = @intento AND fuente IN ('despacho', 'reclamo'));
  IF ISNULL(@cambios, 0) = 0
  BEGIN
    -- reenvio o lote sin novedades: no se crea corte y el publicado se conserva
    UPDATE ctl.lote SET estado = 'SIN_CAMBIOS', corte_seq = (SELECT corte_seq FROM ctl.corte_vigente), fin_utc = SYSUTCDATETIME()
    WHERE lote_id = @lote_id AND intento = @intento AND fuente = 'LOTE';
    SELECT -1 AS corte_seq;
    RETURN;
  END
  DECLARE @c INT = (SELECT ISNULL(MAX(corte_seq), 0) + 1 FROM ctl.corte);
  DECLARE @hoy CHAR(8) = CONVERT(CHAR(8), CAST(SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SA Pacific Standard Time' AS DATE), 112);
  DECLARE @n INT = (SELECT COUNT(*) + 1 FROM ctl.corte WHERE corte_id LIKE 'C-' + @hoy + '-%');
  INSERT INTO ctl.corte (corte_seq, corte_id, estado, lote_id, intento, creado_utc)
  VALUES (@c, CONCAT('C-', @hoy, '-', RIGHT(CONCAT('0', @n), 2)), 'CANDIDATO', @lote_id, @intento, SYSUTCDATETIME());
  SELECT @c AS corte_seq;
END
GO
CREATE OR ALTER PROCEDURE cur.sp_preparar_hecho_despacho @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  DECLARE @lote_id VARCHAR(10), @intento INT, @recepcion DATE;
  SELECT @lote_id = c.lote_id, @intento = c.intento, @recepcion = l.fecha_recepcion
  FROM ctl.corte c JOIN ctl.lote l ON l.lote_id = c.lote_id AND l.intento = c.intento AND l.fuente = 'LOTE'
  WHERE c.corte_seq = @corte_seq AND c.estado = 'CANDIDATO';
  IF @lote_id IS NULL THROW 50030, 'El corte no existe o no es candidato', 1;

  -- version mas alta de cada movimiento que trajo este intento
  SELECT d.* INTO #n FROM trusted.despacho d
  WHERE d.lote_id = @lote_id AND d.intento = @intento
    AND d.version = (SELECT MAX(x.version) FROM trusted.despacho x WHERE x.id_movimiento = d.id_movimiento);

  BEGIN TRAN;
    INSERT INTO cur.dim_marca (marca)                                  -- marcas nuevas, tipo 1
    SELECT DISTINCT n.marca FROM #n n WHERE NOT EXISTS (SELECT 1 FROM cur.dim_marca m WHERE m.marca = n.marca);

    UPDATE f SET corte_hasta = @corte_seq                              -- cierra la version visible anterior
    FROM cur.fact_despacho f JOIN #n n ON n.id_movimiento = f.id_movimiento
    WHERE f.corte_hasta IS NULL;

    INSERT INTO cur.fact_despacho (id_movimiento, version, fecha_sk, tienda_sk, marca_sk, producto_sk, contrato, detalle,
           cantidad_contratada, cantidad_despachada, importe_pen, hash_fila, lote_id, corte_desde, corte_hasta)
    SELECT n.id_movimiento, n.version, YEAR(n.fecha_salida) * 10000 + MONTH(n.fecha_salida) * 100 + DAY(n.fecha_salida),
           ISNULL(t.tienda_sk, -1), ISNULL(m.marca_sk, -1), ISNULL(p.producto_sk, -1), n.contrato, n.detalle,
           n.cantidad_contratada, n.cantidad_despachada, n.importe_pen, n.hash_fila, n.lote_id, @corte_seq, NULL
    FROM #n n
    LEFT JOIN cur.dim_tienda t ON t.tienda = n.tienda AND n.fecha_salida >= t.vigente_desde AND n.fecha_salida < t.vigente_hasta
    LEFT JOIN cur.dim_marca m ON m.marca = n.marca
    LEFT JOIN cur.dim_producto p ON p.producto = n.producto;

    -- C7 informativo: el mes ya estaba publicado y cerrado (dia 5 del mes siguiente) cuando llego el lote
    INSERT INTO ctl.periodo_revisado (corte_seq, periodo, hecho, filas)
    SELECT @corte_seq, CONVERT(CHAR(7), n.fecha_salida, 126), 'fact_despacho', COUNT(*)
    FROM #n n
    WHERE @recepcion > DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(n.fecha_salida), MONTH(n.fecha_salida), 1)))
      AND EXISTS (SELECT 1 FROM cur.fact_despacho f JOIN cur.dim_fecha df ON df.fecha_sk = f.fecha_sk   -- el mes ya fue publicado
                  WHERE df.periodo = CONVERT(CHAR(7), n.fecha_salida, 126) AND f.corte_desde < @corte_seq)
    GROUP BY CONVERT(CHAR(7), n.fecha_salida, 126);

    DELETE FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND objeto = 'fact_despacho';
    INSERT INTO ctl.corte_objeto (corte_seq, objeto, estado, filas) SELECT @corte_seq, 'fact_despacho', 'LISTO', COUNT(*) FROM #n;
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE cur.sp_preparar_hecho_reclamo @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  DECLARE @lote_id VARCHAR(10), @intento INT, @recepcion DATE;
  SELECT @lote_id = c.lote_id, @intento = c.intento, @recepcion = l.fecha_recepcion
  FROM ctl.corte c JOIN ctl.lote l ON l.lote_id = c.lote_id AND l.intento = c.intento AND l.fuente = 'LOTE'
  WHERE c.corte_seq = @corte_seq AND c.estado = 'CANDIDATO';
  IF @lote_id IS NULL THROW 50031, 'El corte no existe o no es candidato', 1;

  -- el reclamo hereda tienda, marca y producto del movimiento (su version mas alta); la zona se toma a la fecha del reclamo
  SELECT r.*, d.tienda, d.marca, d.producto INTO #n
  FROM trusted.reclamo r
  JOIN trusted.despacho d ON d.id_movimiento = r.id_movimiento
   AND d.version = (SELECT MAX(x.version) FROM trusted.despacho x WHERE x.id_movimiento = r.id_movimiento)
  WHERE r.lote_id = @lote_id AND r.intento = @intento;

  BEGIN TRAN;
    INSERT INTO cur.fact_reclamo (id_reclamo, id_movimiento, fecha_sk, tienda_sk, marca_sk, producto_sk, motivo_sk,
           cantidad_devuelta, importe_devuelto_pen, hash_fila, lote_id, corte_desde, corte_hasta)
    SELECT n.id_reclamo, n.id_movimiento, YEAR(n.fecha_reclamo) * 10000 + MONTH(n.fecha_reclamo) * 100 + DAY(n.fecha_reclamo),
           ISNULL(t.tienda_sk, -1), ISNULL(m.marca_sk, -1), ISNULL(p.producto_sk, -1), ISNULL(mo.motivo_sk, -1),
           n.cantidad_devuelta, n.importe_devuelto_pen, n.hash_fila, n.lote_id, @corte_seq, NULL
    FROM #n n
    LEFT JOIN cur.dim_tienda t ON t.tienda = n.tienda AND n.fecha_reclamo >= t.vigente_desde AND n.fecha_reclamo < t.vigente_hasta
    LEFT JOIN cur.dim_marca m ON m.marca = n.marca
    LEFT JOIN cur.dim_producto p ON p.producto = n.producto
    LEFT JOIN cur.dim_motivo mo ON mo.motivo = n.motivo;

    INSERT INTO ctl.periodo_revisado (corte_seq, periodo, hecho, filas)
    SELECT @corte_seq, CONVERT(CHAR(7), n.fecha_reclamo, 126), 'fact_reclamo', COUNT(*)
    FROM #n n
    WHERE @recepcion > DATEADD(day, 4, DATEADD(month, 1, DATEFROMPARTS(YEAR(n.fecha_reclamo), MONTH(n.fecha_reclamo), 1)))
      AND EXISTS (SELECT 1 FROM cur.fact_despacho f JOIN cur.dim_fecha df ON df.fecha_sk = f.fecha_sk   -- el mes ya fue publicado
                  WHERE df.periodo = CONVERT(CHAR(7), n.fecha_reclamo, 126) AND f.corte_desde < @corte_seq)
    GROUP BY CONVERT(CHAR(7), n.fecha_reclamo, 126);

    DELETE FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND objeto = 'fact_reclamo';
    INSERT INTO ctl.corte_objeto (corte_seq, objeto, estado, filas) SELECT @corte_seq, 'fact_reclamo', 'LISTO', COUNT(*) FROM #n;
  COMMIT;
END
GO
CREATE OR ALTER PROCEDURE ctl.sp_publicar_corte @corte_seq INT
AS
BEGIN
  SET NOCOUNT, XACT_ABORT ON;
  IF (SELECT COUNT(*) FROM ctl.corte_objeto WHERE corte_seq = @corte_seq AND estado = 'LISTO'
      AND objeto IN ('fact_despacho', 'fact_reclamo')) < 2
    THROW 50001, 'Corte incompleto: falta preparar un hecho, no se publica', 1;
  BEGIN TRAN;
    UPDATE ctl.corte SET estado = 'PUBLICADO', publicado_utc = SYSUTCDATETIME() WHERE corte_seq = @corte_seq AND estado = 'CANDIDATO';
    IF @@ROWCOUNT = 0 THROW 50002, 'El corte no estaba en estado CANDIDATO', 1;
    UPDATE ctl.corte_vigente SET corte_seq = @corte_seq WHERE id = 1;      -- el unico cambio que ve Power BI
    UPDATE l SET estado = 'PUBLICADO', corte_seq = @corte_seq, fin_utc = SYSUTCDATETIME()
    FROM ctl.lote l JOIN ctl.corte c ON c.lote_id = l.lote_id AND c.intento = l.intento
    WHERE c.corte_seq = @corte_seq AND l.fuente = 'LOTE';
  COMMIT;
END
GO
```

**Cómo saber que salió bien.**

```sql
SELECT SCHEMA_NAME(schema_id) AS esquema, name FROM sys.procedures ORDER BY 1, 2;
-- ctl: sp_abrir_corte, sp_descartar_candidatos, sp_iniciar_lote, sp_marcar_falla, sp_publicar_corte, sp_simular_falla, sp_validar_contrato
-- cur: sp_preparar_hecho_despacho, sp_preparar_hecho_reclamo
-- trusted: sp_merge_despacho, sp_merge_reclamo, sp_merge_tienda
```

#### R8. Crear las vistas de consumo y los seis KPIs

**Para qué.** Power BI solo leerá estas vistas. Las funciones `bi.fn_despacho` y `bi.fn_reclamo` reciben un número de corte; las vistas `bi.v_despacho` y `bi.v_reclamo` las llaman con el corte vigente. Gracias a eso la misma lógica sirve para ver lo publicado y para comparar cortes.

**Qué hacer.** Ejecutar `09_vistas_bi.sql` y luego `11_kpis.sql`.

```sql
-- 09_vistas_bi.sql  v1.0  Capa de consumo. Las funciones reciben un corte; las vistas usan el corte vigente
CREATE OR ALTER FUNCTION bi.fn_despacho (@corte INT) RETURNS TABLE AS RETURN
  SELECT f.despacho_sk, f.id_movimiento, f.version, d.fecha, d.periodo, t.tienda, t.zona_comercial, m.marca_codigo,
         p.producto, f.contrato, f.detalle, f.cantidad_contratada, f.cantidad_despachada, f.importe_pen
  FROM cur.fact_despacho f
  JOIN cur.dim_fecha d ON d.fecha_sk = f.fecha_sk
  JOIN cur.dim_tienda t ON t.tienda_sk = f.tienda_sk
  JOIN cur.dim_marca m ON m.marca_sk = f.marca_sk
  JOIN cur.dim_producto p ON p.producto_sk = f.producto_sk
  WHERE f.corte_desde <= @corte AND (f.corte_hasta IS NULL OR f.corte_hasta > @corte);
GO
CREATE OR ALTER FUNCTION bi.fn_reclamo (@corte INT) RETURNS TABLE AS RETURN
  SELECT f.reclamo_sk, f.id_reclamo, f.id_movimiento, d.fecha, d.periodo, t.tienda, t.zona_comercial, m.marca_codigo,
         p.producto, mo.motivo, mo.es_valido AS motivo_valido, f.cantidad_devuelta, f.importe_devuelto_pen
  FROM cur.fact_reclamo f
  JOIN cur.dim_fecha d ON d.fecha_sk = f.fecha_sk
  JOIN cur.dim_tienda t ON t.tienda_sk = f.tienda_sk
  JOIN cur.dim_marca m ON m.marca_sk = f.marca_sk
  JOIN cur.dim_producto p ON p.producto_sk = f.producto_sk
  JOIN cur.dim_motivo mo ON mo.motivo_sk = f.motivo_sk
  WHERE f.corte_desde <= @corte AND (f.corte_hasta IS NULL OR f.corte_hasta > @corte);
GO
CREATE OR ALTER VIEW bi.v_despacho AS
  SELECT f.* FROM ctl.corte_vigente v CROSS APPLY bi.fn_despacho(v.corte_seq) f;
GO
CREATE OR ALTER VIEW bi.v_reclamo AS
  SELECT f.* FROM ctl.corte_vigente v CROSS APPLY bi.fn_reclamo(v.corte_seq) f;
GO
CREATE OR ALTER VIEW bi.v_corte_publicado AS
  SELECT c.corte_seq, c.corte_id, c.lote_id,
         CAST(c.publicado_utc AT TIME ZONE 'UTC' AT TIME ZONE 'SA Pacific Standard Time' AS DATETIME2(0)) AS publicado_lima
  FROM ctl.corte c JOIN ctl.corte_vigente v ON v.corte_seq = c.corte_seq;
GO
CREATE OR ALTER VIEW bi.v_periodo_revisado AS
  SELECT DISTINCT p.periodo, c.corte_id AS revisado_en_corte
  FROM ctl.periodo_revisado p JOIN ctl.corte c ON c.corte_seq = p.corte_seq
  CROSS JOIN ctl.corte_vigente v
  WHERE c.estado = 'PUBLICADO' AND c.corte_seq <= v.corte_seq;
GO
CREATE OR ALTER VIEW bi.v_comparacion_cortes AS        -- bruto, devuelto y neto de cada mes en cada corte publicado
  WITH b AS (SELECT c.corte_seq, c.corte_id, f.periodo, SUM(f.importe_pen) AS bruto
             FROM ctl.corte c CROSS APPLY bi.fn_despacho(c.corte_seq) f WHERE c.estado = 'PUBLICADO'
             GROUP BY c.corte_seq, c.corte_id, f.periodo),
       r AS (SELECT c.corte_seq, f.periodo, SUM(f.importe_devuelto_pen) AS devuelto
             FROM ctl.corte c CROSS APPLY bi.fn_reclamo(c.corte_seq) f WHERE c.estado = 'PUBLICADO'
             GROUP BY c.corte_seq, f.periodo)
  SELECT b.corte_seq, b.corte_id, b.periodo, b.bruto, ISNULL(r.devuelto, 0) AS devuelto, b.bruto - ISNULL(r.devuelto, 0) AS neto
  FROM b LEFT JOIN r ON r.corte_seq = b.corte_seq AND r.periodo = b.periodo;
GO
```

En `11_kpis.sql` cada vista lleva en su comentario la versión y lo que calcula; si un KPI cambia, se sube la versión y se anota en el informe. Las razones K3, K5 y K6 entregan numerador y denominador por separado para que Power BI sume ambos y luego divida, que es lo que exige el enunciado cuando dice que el total de una razón debe salir de numeradores y denominadores y no del promedio de tasas.

```sql
-- 11_kpis.sql  v1.0  Seis KPIs sobre el corte vigente. Las razones exponen numerador y denominador
CREATE OR ALTER VIEW bi.v_k1 AS            -- K1 despacho bruto PEN, aditiva, mes de salida
  SELECT periodo, tienda, SUM(importe_pen) AS k1_bruto_pen, COUNT(*) AS movimientos
  FROM bi.v_despacho GROUP BY periodo, tienda;
GO
CREATE OR ALTER VIEW bi.v_k2 AS            -- K2 neto PEN: cada hecho se agrega a mes y tienda ANTES de combinar
  WITH b AS (SELECT periodo, tienda, SUM(importe_pen) AS bruto FROM bi.v_despacho GROUP BY periodo, tienda),
       r AS (SELECT periodo, tienda, SUM(importe_devuelto_pen) AS devuelto FROM bi.v_reclamo GROUP BY periodo, tienda)
  SELECT COALESCE(b.periodo, r.periodo) AS periodo, COALESCE(b.tienda, r.tienda) AS tienda,
         b.bruto AS bruto_pen, ISNULL(r.devuelto, 0) AS devuelto_pen, b.bruto - ISNULL(r.devuelto, 0) AS k2_neto_pen
  FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda;
GO
CREATE OR ALTER VIEW bi.v_k3 AS            -- K3 tasa de devolucion: numerador y denominador al mismo nivel
  WITH b AS (SELECT periodo, tienda, marca_codigo, SUM(importe_pen) AS despachado FROM bi.v_despacho GROUP BY periodo, tienda, marca_codigo),
       r AS (SELECT periodo, tienda, marca_codigo, SUM(importe_devuelto_pen) AS devuelto FROM bi.v_reclamo GROUP BY periodo, tienda, marca_codigo)
  SELECT COALESCE(b.periodo, r.periodo) AS periodo, COALESCE(b.tienda, r.tienda) AS tienda,
         COALESCE(b.marca_codigo, r.marca_codigo) AS marca_codigo,
         ISNULL(r.devuelto, 0) AS numerador_devuelto, b.despachado AS denominador_despachado,
         CAST(100.0 * ISNULL(r.devuelto, 0) / NULLIF(b.despachado, 0) AS DECIMAL(9, 2)) AS k3_tasa_pct
  FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.tienda = b.tienda AND r.marca_codigo = b.marca_codigo;
GO
CREATE OR ALTER VIEW bi.v_k4 AS            -- K4 variacion mensual del bruto, total empresa
  WITH m AS (SELECT periodo, SUM(importe_pen) AS k1 FROM bi.v_despacho GROUP BY periodo)
  SELECT periodo, k1, LAG(k1) OVER (ORDER BY periodo) AS k1_anterior,
         CAST(100.0 * (k1 - LAG(k1) OVER (ORDER BY periodo)) / NULLIF(LAG(k1) OVER (ORDER BY periodo), 0) AS DECIMAL(9, 2)) AS k4_variacion_pct
  FROM m;
GO
CREATE OR ALTER VIEW bi.v_k5 AS            -- K5 por linea contractual: la contratada cuenta una sola vez
  SELECT contrato, detalle, tienda, marca_codigo, MAX(periodo) AS periodo_ultimo_despacho,
         MAX(cantidad_contratada) AS contratada, SUM(cantidad_despachada) AS despachada,
         IIF(SUM(cantidad_despachada) < MAX(cantidad_contratada), SUM(cantidad_despachada), MAX(cantidad_contratada)) AS cubierta,
         IIF(SUM(cantidad_despachada) < MAX(cantidad_contratada), MAX(cantidad_contratada) - SUM(cantidad_despachada), 0) AS faltante
  FROM bi.v_despacho GROUP BY contrato, detalle, tienda, marca_codigo;
GO
CREATE OR ALTER VIEW bi.v_k6 AS            -- K6 reclamos con motivo valido
  SELECT periodo, marca_codigo, COUNT(*) AS reclamos, SUM(CAST(motivo_valido AS INT)) AS con_motivo,
         CAST(100.0 * SUM(CAST(motivo_valido AS INT)) / NULLIF(COUNT(*), 0) AS DECIMAL(9, 2)) AS k6_pct
  FROM bi.v_reclamo GROUP BY periodo, marca_codigo;
GO
-- Ejecucion registrada de cada KPI (guardar resultado y captura en evidencias/kpis)
-- SELECT * FROM bi.v_corte_publicado;
-- SELECT * FROM bi.v_k1 ORDER BY periodo, tienda;
-- SELECT periodo, SUM(bruto_pen) bruto, SUM(devuelto_pen) devuelto, SUM(k2_neto_pen) neto FROM bi.v_k2 GROUP BY periodo ORDER BY periodo;
-- SELECT periodo, CAST(100.0*SUM(numerador_devuelto)/SUM(denominador_despachado) AS DECIMAL(9,2)) k3 FROM bi.v_k3 GROUP BY periodo;
-- SELECT * FROM bi.v_k4 ORDER BY periodo;
-- SELECT CAST(100.0*SUM(cubierta)/SUM(contratada) AS DECIMAL(9,2)) AS k5_pct FROM bi.v_k5;
-- SELECT periodo, CAST(100.0*SUM(con_motivo)/SUM(reclamos) AS DECIMAL(9,2)) k6 FROM bi.v_k6 GROUP BY periodo;
```

**Salida.** `09_vistas_bi.sql` y `11_kpis.sql` versionados en el repositorio. Las vistas todavía devuelven cero filas porque no hay nada publicado; eso es correcto.

#### R9. Cargar los lotes con el script de carga manual

**Para qué.** Publicar los cortes del caso propio y comprobar que toda la lógica funciona antes de que Edward la orqueste.

**Entrada.** Datos generados en R3, procedimientos de R7, usuario `etl_loader`.

**Qué hacer.** Guardar el script en `carga/cargar_lote.py`. Lee los archivos locales del lote, que son idénticos a los de raw porque el manifiesto lo garantiza con la huella SHA-256, los pone en staging y llama a los procedimientos en el mismo orden que el pipeline.

```python
"""Carga manual registrada de un lote a Azure SQL. Hace lo mismo que el pipeline de Data Factory,
en el mismo orden y llamando a los mismos procedimientos almacenados.

Uso:
  set AZ_SQL_CONN=Driver={ODBC Driver 18 for SQL Server};Server=tcp:<servidor>.database.windows.net,1433;Database=sqldb-tobotex;Uid=etl_loader;Pwd=<clave>;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=90;
  python cargar_lote.py --lote L0
  python cargar_lote.py --lote L3 --falla tras_despacho
"""
import argparse, csv, json, os, sys, time
import pyodbc

FUENTES = [  # (fuente, prefijo de archivo, extension, columnas de staging)
    ("tienda",   "tienda",   "csv",   ["tienda", "zona_comercial", "vigente_desde", "vigente_hasta"]),
    ("despacho", "despacho", "csv",   ["id_movimiento", "version", "fecha_salida", "tienda", "marca", "producto",
                                       "contrato", "detalle", "cantidad_contratada", "cantidad_despachada",
                                       "importe_pen", "fecha_actualizacion_origen"]),
    ("reclamo",  "reclamo",  "jsonl", ["id_reclamo", "id_movimiento", "fecha_reclamo", "cantidad_devuelta",
                                       "importe_devuelto_pen", "motivo", "fecha_actualizacion_origen"]),
]

def conectar():
    cadena = os.environ["AZ_SQL_CONN"]
    for intento in range(4):            # la base serverless puede estar pausada y tarda en despertar
        try:
            return pyodbc.connect(cadena, autocommit=True)
        except pyodbc.Error as e:
            print(f"  conexion fallida ({e.args[0]}), reintento en 20 s"); time.sleep(20)
    sys.exit("No se pudo conectar a Azure SQL")

def uno(cur, sql, *params):
    cur.execute(sql, *params)
    fila = cur.fetchone()
    while cur.nextset():
        pass
    return fila

def leer(ruta, ext):
    if ext == "csv":
        with open(ruta, encoding="utf-8", newline="") as fh:
            lector = csv.DictReader(fh)
            return lector.fieldnames, list(lector)
    filas = [json.loads(l) for l in open(ruta, encoding="utf-8") if l.strip()]
    return None, filas            # en JSON el esquema se valida despues de cargar staging

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lote", required=True)
    ap.add_argument("--carpeta", default=os.path.join("datos", "tobotex"))
    ap.add_argument("--falla", default="no", choices=["no", "tras_despacho"])
    a = ap.parse_args()
    dir_lote = os.path.join(a.carpeta, a.lote)
    manif = json.load(open(os.path.join(dir_lote, "manifiesto.json")))
    run_id = f"manual-{a.lote}-{time.strftime('%Y%m%dT%H%M%S')}"
    cn = conectar(); cur = cn.cursor(); cur.fast_executemany = True

    intento = uno(cur, "EXEC ctl.sp_iniciar_lote ?, ?, ?", a.lote, manif["fecha_recepcion"], run_id)[0]
    print(f"Lote {a.lote} intento {intento} run_id {run_id}")
    try:
        for fuente, pref, ext, cols in FUENTES:
            ruta = os.path.join(dir_lote, f"{pref}_{a.lote}.{ext}")
            if not os.path.exists(ruta):
                continue
            cabecera, filas = leer(ruta, ext)
            if cabecera is not None:   # CSV: se valida el contrato antes de tocar staging
                cur.execute("EXEC ctl.sp_validar_contrato ?, ?, ?, ?", a.lote, intento, fuente,
                            json.dumps([{"name": c} for c in cabecera]))
            datos = [[(None if f.get(c) in (None, "") else str(f.get(c))) for c in cols] + [a.lote, os.path.basename(ruta)]
                     for f in filas]
            if datos:
                cur.executemany(f"INSERT INTO stg.{fuente} ({', '.join(cols)}, lote_id, archivo) "
                                f"VALUES ({', '.join('?' * (len(cols) + 2))})", datos)
            if cabecera is None:       # JSON: se valida sobre lo cargado
                cur.execute("EXEC ctl.sp_validar_contrato ?, ?, ?, NULL", a.lote, intento, fuente)
            print(f"  {fuente}: {len(datos)} filas a staging")
        for sp in ["trusted.sp_merge_tienda", "trusted.sp_merge_despacho", "trusted.sp_merge_reclamo"]:
            cur.execute(f"EXEC {sp} ?, ?", a.lote, intento)
        corte = uno(cur, "EXEC ctl.sp_abrir_corte ?, ?", a.lote, intento)[0]
        if corte < 0:
            print("  sin cambios de negocio: se conserva el corte publicado"); return
        cur.execute("EXEC cur.sp_preparar_hecho_despacho ?", corte)
        if a.falla == "tras_despacho":
            cur.execute("EXEC ctl.sp_simular_falla")
        cur.execute("EXEC cur.sp_preparar_hecho_reclamo ?", corte)
        cur.execute("EXEC ctl.sp_publicar_corte ?", corte)
        print(f"  publicado corte_seq {corte}")
    except pyodbc.Error as e:
        mensaje = str(e)[:390]
        cur.execute("EXEC ctl.sp_marcar_falla ?, ?, ?", a.lote, intento, mensaje)
        print("  FALLA:", mensaje); sys.exit(1)
    finally:
        for f in cur.execute("SELECT fuente, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado "
                             "FROM ctl.lote WHERE lote_id = ? AND intento = ?", a.lote, intento).fetchall():
            print("  ", tuple(f))

if __name__ == "__main__":
    main()
```

En una terminal de Windows desde la raíz del repositorio:

```
set AZ_SQL_CONN=Driver={ODBC Driver 18 for SQL Server};Server=tcp:sql-tobotex-pc3-<ini>.database.windows.net,1433;Database=sqldb-tobotex;Uid=etl_loader;Pwd=<clave>;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=90;
python carga/cargar_lote.py --lote L0
python carga/cargar_lote.py --lote L1
python carga/cargar_lote.py --lote L1
python carga/cargar_lote.py --lote L2
python carga/cargar_lote.py --lote LX
python carga/cargar_lote.py --lote L3 --falla tras_despacho
python carga/cargar_lote.py --lote L3
```

En PowerShell la primera línea es `$env:AZ_SQL_CONN="..."`. Guarden la salida de cada ejecución en `evidencias/` con un nombre como `R9_L0_intento1.txt`.

Lo que debe pasar en cada línea es exactamente lo que después Edward repetirá como pruebas:

1. **L0** publica el primer corte. Despacho 600 leídas y 600 insertadas, reclamo 49 y 49, tienda 3 y 3.
2. **L1** publica el segundo corte. Despacho 45 leídas: 40 insertadas, 2 actualizadas, 1 omitida y 2 rechazadas.
3. **L1 otra vez** es el reenvío. No crea corte, el lote queda en estado `SIN_CAMBIOS` y el corte vigente sigue siendo el segundo. Despacho 45 leídas: 0 insertadas, 0 actualizadas, 43 omitidas y 2 rechazadas, y la cuarentena sigue teniendo 2 filas de L1, no 4.
4. **L2** publica el tercer corte, la revisión de septiembre.
5. **LX** falla con el mensaje "C1 esquema incompatible en despacho: falta tienda" y el lote queda `RECHAZADO_ESQUEMA`. El corte vigente sigue siendo el tercero.
6. **L3 con falla** prepara el despacho y se cae con la falla simulada. Queda un corte candidato sin publicar y el lote en `FALLIDO`. El tablero y las vistas siguen mostrando el tercer corte.
7. **L3 sin falla** descarta el candidato anterior, vuelve a clasificar, prepara los dos hechos y publica el cuarto corte. Como el candidato fallido consumió un número de secuencia, el nuevo corte tendrá secuencia 5; en el informe se le llama C3 porque es el cuarto publicado.

**Salida.** Cuatro cortes publicados, uno descartado, y la bitácora completa en `ctl.lote`.

#### R10. Verificar con consultas lo que acaba de pasar

Estas consultas son las mismas que se usarán como evidencia en 2.4 y en el Capítulo 3. Guarden su resultado.

```sql
-- Bitacora completa: un renglon por lote, intento y fuente
SELECT lote_id, intento, fuente, filas_leidas, filas_ins, filas_upd, filas_omit, filas_rech, estado, corte_seq, mensaje
FROM ctl.lote ORDER BY inicio_utc, lote_id, intento, fuente;

-- Conciliacion: leidas = ins + upd + omit + rech en cada fuente
SELECT lote_id, intento, fuente, filas_leidas,
       filas_ins + filas_upd + filas_omit + filas_rech AS clasificadas,
       IIF(filas_leidas = filas_ins + filas_upd + filas_omit + filas_rech, 'OK', 'DIFERENCIA') AS estado
FROM ctl.lote WHERE fuente <> 'LOTE';

-- Cortes y puntero
SELECT * FROM ctl.corte ORDER BY corte_seq;
SELECT * FROM bi.v_corte_publicado;

-- Cuarentena con motivo
SELECT fuente, lote_id, intento, clave, control, motivo FROM quar.rechazo;

-- Bruto, devuelto y neto por mes en cada corte publicado (debe coincidir con la seccion 7.2)
SELECT * FROM bi.v_comparacion_cortes ORDER BY corte_seq, periodo;
SELECT * FROM bi.v_periodo_revisado;
```

**Demostración de SCD tipo 2.** Va al informe en 2.2 con captura:

```sql
-- Las dos versiones de LEO
SELECT tienda_sk, tienda, zona_comercial, vigente_desde, vigente_hasta, es_actual FROM cur.dim_tienda WHERE tienda = 'LEO';

-- La correccion tardia de L2 (movimiento del 09/09, version 2) quedo en Gamarra Norte aunque llego el 20/10,
-- y los reclamos tardios de LEO toman la zona vigente en su propia fecha
SELECT 'despacho' AS hecho, f.id_movimiento AS id, f.version, d.fecha, t.zona_comercial, f.lote_id
FROM cur.fact_despacho f JOIN cur.dim_fecha d ON d.fecha_sk = f.fecha_sk JOIN cur.dim_tienda t ON t.tienda_sk = f.tienda_sk
WHERE f.lote_id = 'L2'
UNION ALL
SELECT 'reclamo', r.id_reclamo, NULL, d.fecha, t.zona_comercial, r.lote_id
FROM cur.fact_reclamo r JOIN cur.dim_fecha d ON d.fecha_sk = r.fecha_sk JOIN cur.dim_tienda t ON t.tienda_sk = r.tienda_sk
WHERE r.lote_id = 'L2';
-- Esperado: M000413 v2, 2026-09-09, Gamarra Norte. R000050 (LEO, 2026-09-04) Gamarra Norte,
-- R000051 (LEO, 2026-09-22) Gamarra Centro, R000052 (AMERICA, 2026-09-28) Gamarra Sur.
```

Los identificadores exactos de los reclamos dependen del generador; si los suyos difieren, lo que importa es la regla: antes del 15 de septiembre Norte, desde el 15 Centro.

**Prueba de granularidad.** Va al informe en 2.2. Muestra tres totales del despacho bruto de julio:

```sql
-- (a) K1 calculado solo con el hecho de despacho
SELECT SUM(importe_pen) AS k1_julio FROM bi.v_despacho WHERE periodo = '2026-07';

-- (b) union ingenua: se juntan movimientos con reclamos a nivel de fila y luego se suma.
--     Un movimiento con dos reclamos aparece dos veces y su importe se duplica
SELECT SUM(d.importe_pen) AS k1_julio_inflado
FROM bi.v_despacho d LEFT JOIN bi.v_reclamo r ON r.id_movimiento = d.id_movimiento
WHERE d.periodo = '2026-07';

-- (c) cada hecho agregado primero a mes y tienda, despues combinado (es lo que hace bi.v_k2)
SELECT SUM(bruto_pen) AS k1_julio_alineado FROM bi.v_k2 WHERE periodo = '2026-07';
```

Con los datos del generador (a) y (c) dan 49 197,85 y (b) da 49 403,93. La diferencia de 206,08 es exactamente el importe de M000047, el movimiento de julio que tiene dos reclamos y que la unión ingenua cuenta dos veces. Con el Anexo E pasa lo mismo: unir ventas con devoluciones a nivel de línea en C0 da 240 soles de bruto en febrero en lugar de 120.

#### R11. Repetir todo con los datos del Anexo E en `sqldb-control`

**Para qué.** El enunciado pide aplicar las mismas reglas de carga, historia y publicación a los datos comunes en un espacio aislado y comparar con el docente.

**Qué hacer.** Crear la carpeta `sql/control/` con copias de los scripts y adaptarlas con estos cambios. La lógica no cambia; cambian nombres y algunas validaciones.

| Caso propio | Anexo E |
|---|---|
| `despacho`, clave `id_movimiento` más `version`, fecha `fecha_salida` | `venta`, clave `linea` más `version`, fecha `fecha_venta` |
| `reclamo`, clave `id_reclamo`, referencia `id_movimiento`, fecha `fecha_reclamo` | `devolucion`, clave `evento`, referencia `linea`, fecha `fecha_devolucion` |
| `tienda` con `zona_comercial` | `sede` con `region`; "Abierta" o vacío se guarda como 9999-12-31 |
| Medidas `importe_pen`, cantidades | Solo `importe` en ambos hechos |
| `dim_marca`, `dim_producto`, `dim_motivo` | `dim_producto` y `dim_canal`, que se llenan con los códigos que llegan en las ventas |
| C5 exige cantidades e importe mayores que cero | C5 exige importe mayor que cero: así V06 con −5,00 va a cuarentena |
| Columna `lote` no existe | Los archivos traen la columna `lote`; se carga en staging y se ignora en trusted |

Se borra lo que no aplica: `contrato`, `detalle`, cantidades, `motivo`, y la validación de producto contra catálogo, porque en el Anexo E el catálogo de producto y canal sale de las mismas ventas. La regla C7 de ventana de corrección se mantiene pero no se dispara. En `05_seed.sql` el calendario puede quedarse en 2026.

Las vistas del control se reducen a dos KPIs y a la comparación de cortes:

```sql
CREATE OR ALTER VIEW bi.v_k1 AS
  SELECT periodo, sede, SUM(importe) AS k1_bruto FROM bi.v_venta GROUP BY periodo, sede;
GO
CREATE OR ALTER VIEW bi.v_k2 AS
  WITH b AS (SELECT periodo, sede, SUM(importe) AS bruto FROM bi.v_venta GROUP BY periodo, sede),
       r AS (SELECT periodo, sede, SUM(importe) AS devuelto FROM bi.v_devolucion GROUP BY periodo, sede)
  SELECT COALESCE(b.periodo, r.periodo) AS periodo, COALESCE(b.sede, r.sede) AS sede,
         ISNULL(b.bruto, 0) AS bruto, ISNULL(r.devuelto, 0) AS devuelto, ISNULL(b.bruto, 0) - ISNULL(r.devuelto, 0) AS k2_neto
  FROM b FULL OUTER JOIN r ON r.periodo = b.periodo AND r.sede = b.sede;
GO
```

En `cargar_lote.py` basta con cambiar la lista `FUENTES` por `("sede", "sedes", "csv", [...])`, `("venta", "ventas", "csv", [...])` y `("devolucion", "devoluciones", "jsonl", [...])`, cambiar los nombres de procedimiento y pasar `--carpeta datos/control_anexoE`. Las fechas de recepción del manifiesto del control no son necesarias; se pueden poner L0 2026-04-01, L1 2026-04-02, L2 2026-04-10 y L3 2026-04-11.

Orden de ejecución: L0, L1, L1 otra vez, L2, L3 con falla y L3 sin falla. Para la interrupción del Anexo E el enunciado dice "prepare ventas y detenga el flujo antes de completar devoluciones", que es exactamente `--falla tras_despacho` aplicado a la venta.

**Salida y verificación.**

```sql
SELECT corte_id, periodo, bruto, devuelto, neto FROM bi.v_comparacion_cortes ORDER BY corte_seq, periodo;
```

Debe dar al centavo la tabla de la sección 7.1. Además, mientras L3 está fallado, `SELECT * FROM bi.v_k2 WHERE periodo = '2026-03'` debe devolver bruto 160, devuelto 8 y neto 152, no la mezcla 180, 8 y 172. Captura de ese momento: es la evidencia más importante de P8.

### Bloque D. Consumo y redacción

#### R12. Construir el tablero en Power BI

**Para qué.** El enunciado pide conectar el tablero a la capa analítica en la nube, con una vista ejecutiva, una de diagnóstico, filtros por período y por una dimensión del negocio, detalle por segmento, meta o umbral, fecha del último lote publicado e identificación de períodos revisados.

**Conexión.**

1. Power BI Desktop, "Obtener datos", "Azure", "Base de datos de Azure SQL".
2. Servidor `sql-tobotex-pc3-<ini>.database.windows.net`, base `sqldb-tobotex`, modo **DirectQuery**. DirectQuery es lo correcto aquí: cada visual pregunta a la base y siempre ve el corte que marca el puntero. Con importación el tablero mostraría una copia que no cambia al publicar.
3. Credenciales: pestaña "Base de datos", usuario `bi_reader`. Nunca `sqladmin`.
4. Seleccionar solo objetos del esquema `bi`: `v_k1` a `v_k6`, `v_despacho`, `v_reclamo`, `v_corte_publicado`, `v_periodo_revisado`, `v_comparacion_cortes`. Si aparecen tablas de otros esquemas en la lista es que algo falló en la seguridad.

**Medidas DAX.** Las razones se calculan siempre sumando numerador y denominador:

```
K1 Bruto = SUM(v_k2[bruto_pen])
K2 Neto = SUM(v_k2[k2_neto_pen])
K3 Tasa devolucion % = DIVIDE(SUM(v_k3[numerador_devuelto]), SUM(v_k3[denominador_despachado])) * 100
K5 Cumplimiento % = DIVIDE(SUM(v_k5[cubierta]), SUM(v_k5[contratada])) * 100
K6 Con motivo % = DIVIDE(SUM(v_k6[con_motivo]), SUM(v_k6[reclamos])) * 100
K4 Variacion % = MAX(v_k4[k4_variacion_pct])
Color K3 = SWITCH(TRUE(), [K3 Tasa devolucion %] <= 3, "#2E7D32", [K3 Tasa devolucion %] <= 5, "#F9A825", "#C62828")
Color K5 = SWITCH(TRUE(), [K5 Cumplimiento %] >= 98, "#2E7D32", [K5 Cumplimiento %] >= 95, "#F9A825", "#C62828")
Corte visible = "Corte " & SELECTEDVALUE(v_corte_publicado[corte_id]) & " publicado " & FORMAT(SELECTEDVALUE(v_corte_publicado[publicado_lima]), "dd/mm/yyyy hh:nn")
```

Para que el filtro de mes funcione en todas las visuales, creen una tabla de períodos con `Periodos = DISTINCT(UNION(VALUES(v_k1[periodo]), VALUES(v_k6[periodo])))` y relaciónenla de uno a varios con la columna `periodo` de cada vista. Lo mismo con una tabla de tiendas para el filtro de tienda. Así las dos vistas de hechos se alinean por dimensiones comunes, que es la versión visual de la prueba de granularidad.

**Página ejecutiva.** Tarjeta grande con la medida "Corte visible" arriba a la derecha. Seis tarjetas de KPI con su meta escrita debajo. Gráfico de líneas mensual de bruto y neto. Tarjeta de K4 con flecha. Tabla pequeña con `v_periodo_revisado` titulada "Períodos revisados". Segmentadores de período y tienda.

**Página de diagnóstico.** Barras de K3 por marca con color condicional usando "Color K3" y una línea constante en 5 por ciento. Tabla de `v_k5` ordenada por faltante con las diez primeras líneas. Barras de reclamos por motivo. Matriz de `v_comparacion_cortes` con cortes en columnas y meses en filas, que muestra de un vistazo que septiembre cambió entre el segundo y el tercer corte y que julio y agosto no.

**Salida.** `powerbi/tobotex_pc3.pbix` y la exportación a PDF de ambas páginas, desde "Archivo", "Exportar", "Exportar a PDF". El tablero no necesita publicarse en Power BI Service; publicar requiere licencia Pro y el enunciado acepta una exportación con filtros y corte visibles.

**Cómo saber que salió bien.** Con todos los filtros limpios, K1 de julio en el tablero es 49 197,85. Si da otra cifra, la relación de la tabla de períodos está duplicando filas.

#### R13. Redactar el Capítulo 2

Ahora sí. El borrador ya tiene el texto de 2.1 a 2.3; falta reemplazar cada [COMPLETAR] por evidencia real.

- **2.1.** Completar la tabla de fuentes con el esquema, que es la lista de campos del contrato, el volumen por lote de la tabla de R3, el tamaño en bytes del manifiesto y la versión 1.0 de cada contrato. Agregar la ubicación exacta en raw, por ejemplo `raw/tobotex/L0/despacho_L0.csv`. Copiar las reglas de simulación de R3 y la explicación de la fecha de recepción simulada.
- **2.2.** Pegar la captura de las dos versiones de LEO y de la consulta de asignación del evento tardío de R10. Pegar los tres totales de la prueba de granularidad. Agregar un párrafo sobre la historia por corte en los hechos, que ya está, con una captura de `SELECT id_movimiento, version, corte_desde, corte_hasta FROM cur.fact_despacho WHERE id_movimiento = 'M000413'` que muestre la versión 1 cerrada y la 2 abierta.
- **2.3.** En la última línea de cada ficha poner "Contrato despacho v1.0" o el que corresponda, y el nombre de la visual, por ejemplo "Página ejecutiva, tarjeta K1".
- **2.4.** Tabla con KPI, corte, período, filtro, resultado y archivo de evidencia, usando las consultas comentadas al final de `11_kpis.sql`. Para la conciliación de K2 y K3: elegir julio y la tienda LEO, exportar a Excel las filas de `bi.v_despacho` y `bi.v_reclamo` de ese segmento, sumar a mano en la hoja y comparar con `bi.v_k2` y con el tablero filtrado. Si se pide un subconjunto de unas veinte filas, usen el filtro adicional de una marca. Para K3 mostrar en la hoja que sumar numeradores y denominadores de todas las marcas da el total del tablero y que promediar las tasas de las marcas da otra cifra.
- **2.5.** Capturas de las dos páginas y tres hallazgos con números del tablero. Con los datos del generador deberían salir estos tres, pero confírmenlos en su tablero: la marca MK TALLAS tiene una tasa de devolución cercana al 7 por ciento en la base de julio a septiembre, sobre el umbral rojo de 5; septiembre pasó de un neto de 47 170,72 a 46 973,08 soles entre el segundo y el tercer corte por la corrección y los reclamos tardíos de L2, mientras julio y agosto no cambiaron; y el cumplimiento de cantidad K5 del corte final es 95,96 por ciento, en ámbar bajo la meta de 98, con 409 de 533 líneas con algún faltante y las diez mayores listadas en la vista de diagnóstico.
- **Anexo E.** Tabla con una fila por corte y mes, con bruto, devuelto y neto en la columna SQL y en la columna del cálculo independiente de `anexo_e.py`, y una columna de coincidencia. Debajo, la explicación de cada diferencia que está en la sección 7.1 y la región histórica de D04.

#### R14. Relevo a Edward

Escribir en el README, sección "Estado del relevo", qué quedó listo, qué falló y cómo se resolvió, y cualquier ajuste hecho a los scripts respecto de este documento. Subir al repositorio scripts, datos, contratos, el `.pbix`, las evidencias y la bitácora. Entregar a Edward las credenciales por un canal privado.

---

## 6. FASE 3: Edward

Edward recibe una base que ya funciona. Su trabajo es orquestarla con Data Factory, ejecutar las ocho pruebas de forma formal con evidencia, probar la seguridad y los costos, y cerrar el paquete reproducible. Las pruebas se ejecutan por el pipeline y no por el script, porque el enunciado pide que las actualizaciones posteriores a la carga inicial corran con un procedimiento parametrizado en la nube y que cada evidencia quede asociada a un intento.

```
E1 revisar relevo y reiniciar datos  →  E2 Data Factory: conexiones  →  E3 pipeline
→  E4 cargas y pruebas P1 a P4 y P8 (caso propio y Anexo E)  →  E5 prueba P5  →  E6 prueba P6
→  E7 accesos  →  E8 costos y consultas equivalentes  →  E9 bitácora  →  E10 redactar Capítulo 3  →  E11 paquete, demo y limpieza
```

#### E1. Revisar el relevo y reiniciar los datos

Leer el estado del relevo. Conectarse a las dos bases y confirmar con las consultas de R10 que los números coinciden con la sección 7. Guardar esas salidas como "resultado de la carga manual". Después ejecutar `98_reset_datos.sql` en `sqldb-tobotex` y su versión adaptada en `sqldb-control`. Este script vacía datos y bitácoras y deja intactas tablas, procedimientos, vistas, catálogos y usuarios.

```sql
-- 98_reset_datos.sql  Vacia datos y bitacoras pero conserva tablas, procedimientos, vistas, catalogos y usuarios
DELETE FROM cur.fact_reclamo; DELETE FROM cur.fact_despacho;
DELETE FROM cur.dim_marca WHERE marca_sk > 0; DELETE FROM cur.dim_tienda WHERE tienda_sk > 0;
DELETE FROM trusted.reclamo; DELETE FROM trusted.despacho; DELETE FROM trusted.tienda;
DELETE FROM quar.rechazo; DELETE FROM stg.despacho; DELETE FROM stg.reclamo; DELETE FROM stg.tienda;
DELETE FROM ctl.periodo_revisado; DELETE FROM ctl.corte_objeto; DELETE FROM ctl.corte; DELETE FROM ctl.lote;
UPDATE ctl.corte_vigente SET corte_seq = 0;
```

La carga inicial L0 del caso propio se puede volver a hacer con el script Python y declararla como carga manual registrada, o hacerla también por el pipeline. Lo más ordenado es hacer todo por el pipeline y mencionar en el informe que el script existe como respaldo y como evidencia de que la lógica no depende de Data Factory.

#### E2. Data Factory: identidad y conexiones

1. Si no existe, crear `adf-tobotex-pc3-<ini>` como en R1 paso 10 y abrir **Azure Data Factory Studio** desde su página.
2. Dar permiso a la identidad administrada de Data Factory sobre el almacenamiento: en la cuenta `sttobotexpc3<ini>`, "Control de acceso (IAM)", "Agregar asignación de rol", rol **Lector de datos de Storage Blob** (Storage Blob Data Reader), "Asignar acceso a" identidad administrada, elegir la Data Factory. Sin esto la copia falla con un error 403.
3. En Studio, "Administrar", "Servicios vinculados", crear tres:
   - `ls_adls`: tipo Azure Data Lake Storage Gen2, autenticación **Identidad administrada asignada por el sistema**, elegir la cuenta. Probar conexión.
   - `ls_sql`: tipo Azure SQL Database, con un **parámetro** `nombre_bd` de tipo cadena. En el campo de base de datos poner contenido dinámico `@{linkedService().nombre_bd}`. Autenticación SQL, usuario `etl_loader` y su contraseña. Al probar conexión pide un valor para el parámetro; usar `sqldb-tobotex`. Si tienen Key Vault, la contraseña va allí; si no, se guarda como cadena segura en el propio servicio vinculado y se declara en el informe.
4. Crear tres conjuntos de datos, todos con parámetros para que sirvan a cualquier lote:
   - `ds_csv`: Delimited text sobre `ls_adls`, parámetros `carpeta` y `archivo`. Ruta: contenedor `raw`, directorio `@dataset().carpeta`, archivo `@dataset().archivo`. Primera fila como encabezado, delimitador coma, codificación UTF-8, carácter de comillas comilla doble. Esquema: ninguno.
   - `ds_jsonl`: JSON sobre `ls_adls`, mismos parámetros. Esquema: ninguno.
   - `ds_sql`: Azure SQL Database sobre `ls_sql`, parámetros `nombre_bd`, `esquema` y `tabla`, pasando `nombre_bd` al servicio vinculado.

#### E3. Construir el pipeline

Se usan dos pipelines, uno padre y uno hijo. El hijo hace el trabajo. El padre inicia el lote, llama al hijo y, si el hijo falla, registra la falla en la base. Este diseño existe porque en Data Factory no hay un bloque "try catch": la forma limpia de capturar la falla de cualquier paso es capturar la falla de la actividad que ejecuta el hijo.

**Pipeline padre `pl_cargar_lote`.**

Parámetros: `lote_id` (cadena), `fecha_recepcion` (cadena con formato aaaa-mm-dd), `simular_falla` (cadena, valor por defecto `no`), `nombre_bd` (cadena, por defecto `sqldb-tobotex`), `carpeta_raw` (cadena, por defecto `tobotex`).

Actividades:

1. `LK_iniciar`, tipo **Lookup** sobre `ds_sql` con "Usar consulta: Consulta" y el texto
   `EXEC ctl.sp_iniciar_lote '@{pipeline().parameters.lote_id}', '@{pipeline().parameters.fecha_recepcion}', '@{pipeline().RunId}'`.
   Marcar "Solo la primera fila". Devuelve el intento. El `RunId` del pipeline queda guardado en `ctl.lote` y une la bitácora de la base con el monitor de Data Factory, que es lo que el enunciado llama identificador del intento.
2. `EP_cuerpo`, tipo **Execute Pipeline**, llama a `pl_cuerpo_lote`, con "Esperar a la finalización" activado. Le pasa `lote_id`, `intento` = `@string(activity('LK_iniciar').output.firstRow.intento)`, `simular_falla`, `nombre_bd` y `carpeta_raw`.
3. Conectada a `EP_cuerpo` por la salida **Al producirse un error** (flecha roja): `SP_marcar_falla`, tipo **Stored procedure**, procedimiento `ctl.sp_marcar_falla` con `lote_id`, `intento` y `mensaje` = `@{substring(activity('EP_cuerpo').error.message, 0, min(390, length(activity('EP_cuerpo').error.message)))}`.
4. Después de `SP_marcar_falla`, una actividad **Fail** con mensaje "Lote fallido, ver ctl.lote". Así el monitor muestra la ejecución en rojo y no en verde, lo que importa para la evidencia de P5 y P8.

**Pipeline hijo `pl_cuerpo_lote`.**

Mismos parámetros más `intento`. Los nombres de archivo siguen la regla `fuente_lote.extensión`, por ejemplo `despacho_L1.csv`. Actividades en este orden, cada una conectada a la anterior por la salida de éxito:

1. **Tienda.** `GM_tienda_existe`, Get Metadata sobre `ds_csv` con carpeta `@{pipeline().parameters.carpeta_raw}/@{pipeline().parameters.lote_id}` y archivo `tienda_@{pipeline().parameters.lote_id}.csv`, lista de campos **Exists**. Luego `IF_tienda`, If Condition con expresión `@activity('GM_tienda_existe').output.exists`. En la rama verdadera tres actividades:
   - `GM_tienda_estructura`, Get Metadata del mismo archivo con el campo **Structure**.
   - `SP_validar_tienda`, procedimiento `ctl.sp_validar_contrato` con `lote_id`, `intento`, `fuente` = `tienda` y `columnas` = `@{string(activity('GM_tienda_estructura').output.structure)}`.
   - `CP_tienda`, Copy de `ds_csv` a `ds_sql` con esquema `stg` y tabla `tienda`. En el origen, "Columnas adicionales": `lote_id` con valor `@pipeline().parameters.lote_id` y `archivo` con valor `$$FILEPATH`. En "Asignación" pulsar "Importar esquemas"; las columnas se mapean por nombre.
2. **Despacho.** Igual que tienda con `despacho_<lote>.csv`, `fuente` = `despacho` y tabla `stg.despacho`.
3. **Reclamo.** `GM_reclamo_existe` sobre `ds_jsonl`, `IF_reclamo`, y en la rama verdadera primero `CP_reclamo` con origen `ds_jsonl`, en la configuración del origen "Formato de documento" **Documento por línea**, mismas columnas adicionales y tabla `stg.reclamo`; después `SP_validar_reclamo` con `columnas` vacío. En JSON Get Metadata no entrega la estructura, por eso la validación se hace sobre lo que llegó a staging, como explica el procedimiento.
4. `SP_merge_tienda`, `SP_merge_despacho`, `SP_merge_reclamo`: tres actividades Stored procedure con `lote_id` e `intento`.
5. `LK_abrir_corte`, Lookup con `EXEC ctl.sp_abrir_corte '@{pipeline().parameters.lote_id}', @{pipeline().parameters.intento}`.
6. `IF_hay_corte`, If Condition con `@greater(int(activity('LK_abrir_corte').output.firstRow.corte_seq), 0)`. Si es falsa no hace nada: es el reenvío sin cambios y el pipeline termina en verde. En la rama verdadera:
   - `SP_preparar_despacho` con `corte_seq` = `@{activity('LK_abrir_corte').output.firstRow.corte_seq}`.
   - `IF_falla`, If Condition con `@equals(pipeline().parameters.simular_falla, 'tras_despacho')`, y en su rama verdadera `SP_simular_falla` que ejecuta `ctl.sp_simular_falla`.
   - `SP_preparar_reclamo` y `SP_publicar` con el mismo `corte_seq`.

Data Factory no permite un If dentro de otro If. Si el editor no deja poner `IF_falla` dentro de `IF_hay_corte`, se resuelve así: `IF_hay_corte` contiene solo `SP_preparar_despacho`, y después de `IF_hay_corte` van `IF_falla` y un segundo If `IF_publicar` con la misma condición de corte, que contiene `SP_preparar_reclamo` y `SP_publicar`. El resultado es idéntico.

Para el Anexo E se clona el par de pipelines como `pl_cargar_lote_control` y `pl_cuerpo_lote_control`, cambiando los nombres de archivo, tablas y procedimientos, con `nombre_bd` por defecto `sqldb-control` y `carpeta_raw` `control`.

Cuando todo esté probado: "Publicar todo", y exportar cada pipeline desde su menú de tres puntos con "Descargar plantilla de soporte" o copiando el código JSON del botón `{}`, y guardarlo en `adf/`.

**Ejecución.** Cada lote se lanza con "Agregar desencadenador", "Desencadenar ahora", llenando los parámetros. Los valores de `fecha_recepcion` son los del manifiesto: L0 2026-10-01, L1 y LX 2026-10-04, L2 2026-10-20, L3 2026-10-27. Opcionalmente se crea un desencadenador programado semanal para mostrar que la carga puede automatizarse, pero se deja deshabilitado para no gastar.

#### E4. Ejecutar las cargas como pruebas formales

Para cada prueba se guarda: el `RunId` de Data Factory que aparece en "Supervisar", la captura del monitor con las actividades en verde o rojo, la salida de las consultas de R10 y la captura del tablero cuando corresponde. En la sección 7 están los valores esperados.

- **P1 Línea base.** Lanzar L0. Conciliar con la consulta de conciliación de R10. Verificar los seis KPIs con las consultas comentadas de `11_kpis.sql` y con el tablero. En el Anexo E, lanzar L0 en el pipeline de control y verificar K1 y K2 de enero, febrero y marzo.
- **P2 Incremental.** Lanzar L1. Comprobar 40 insertadas, 2 actualizadas, 1 omitida y 2 rechazadas, que cada movimiento actualizado aparece una sola vez en `bi.v_despacho` con su versión 2, y que los dos inválidos están en `quar.rechazo` con su motivo. Anexo E: L1 con una insertada (V05), una actualizada (V04), una omitida (la copia de V05) y una rechazada (V06), y marzo pasa de 120 a 160.
- **P3 Reenvío.** Antes de lanzar, guardar el resultado de `SELECT * FROM bi.v_corte_publicado` y de `SELECT id_movimiento, version, importe_pen FROM bi.v_despacho ORDER BY 1` exportado a un archivo. Lanzar L1 otra vez sin tocar nada. Después repetir las dos consultas y compararlas; deben ser idénticas. El lote queda en `SIN_CAMBIOS` con un intento nuevo y su propio `RunId`. En el Anexo E, lo mismo: cero insertadas, cero actualizadas, tres omitidas, una rechazada, cuarentena sin duplicar.
- **P4 Revisión histórica.** Lanzar L2. Comparar `bi.v_comparacion_cortes` entre el segundo y el tercer corte: septiembre cambia, julio y agosto no. Julio es el período de control. Mostrar `bi.v_periodo_revisado` con septiembre. Ejecutar la consulta SCD de R10 para mostrar qué versión de tienda recibió cada evento tardío. Anexo E: febrero neto pasa de 105 a 101, enero sigue en 100 y D04 queda en la región Norte.
- **P8 Publicación interrumpida.** Lanzar L3 con `simular_falla` = `tras_despacho`. El monitor muestra `SP_simular_falla` en rojo y `SP_marcar_falla` en verde. En ese momento consultar `bi.v_corte_publicado`, `bi.v_k1` y `bi.v_k2` y tomar captura del tablero actualizado: todo debe seguir mostrando el tercer corte. Consultar `SELECT * FROM ctl.corte` para mostrar el candidato que quedó sin publicar y `ctl.corte_objeto` con un solo objeto LISTO. Luego relanzar L3 con `simular_falla` = `no`: el candidato pasa a `DESCARTADO`, se publica un corte nuevo, y en `cur.fact_despacho` cada movimiento de L3 aparece una sola vez. Anexo E: durante la falla marzo sigue en 160, 8 y 152; después del reintento queda en 180, 13 y 167.

Si alguna prueba falla en el primer intento, no se borra nada. Se marca como fallida en la bitácora con su `RunId`, se corrige el defecto, se relanza y se registra el segundo intento explicando qué cambió y qué control demuestra la corrección. Eso es lo que el enunciado llama registrar una prueba fallida, y bien documentado suma en vez de restar.

#### E5. P5 Esquema incompatible y recuperación

1. En `sqldb-tobotex` lanzar `pl_cargar_lote` con `lote_id` = `LX`. Falla en `SP_validar_despacho` con el mensaje "C1 esquema incompatible en despacho: falta tienda". Verificar en `ctl.lote` el estado `RECHAZADO_ESQUEMA` y en `bi.v_corte_publicado` que el corte no cambió.
2. Recuperación en entorno de prueba: en `sqldb-test` ejecutar los scripts 00 a 11, cargar L0 con el pipeline usando `nombre_bd` = `sqldb-test`, lanzar LX y ver el rechazo. Corregir el archivo, es decir generar `LX` con la columna `tienda` restituida, subirlo a raw como un lote nuevo `LXC` con su manifiesto, y lanzarlo. Debe publicar un corte nuevo con los mismos resultados que tuvo L1. Así se demuestra la recuperación sin tocar la base del caso.
3. Al terminar, `sqldb-test` puede borrarse o quedarse pausada. Pausada no consume.

Usar `sqldb-test` como otra base gratuita es más simple que `CREATE DATABASE ... AS COPY OF`, porque la copia de una base gratuita no hereda la oferta y empezaría a cobrar.

#### E6. P6 Conciliación BI de dos KPIs

Se repite la conciliación que Rolando dejó en 2.4, ahora formal: para K2 y K3, con el corte final, el mismo período y los mismos filtros, se anotan tres valores en una tabla: el cálculo independiente de `calculo_independiente_tobotex.py` o de la hoja de Excel, el resultado SQL de `bi.v_k2` o `bi.v_k3`, y el valor que muestra el tablero filtrado. Tolerancias fijadas antes de ejecutar: igualdad exacta en conteos, igualdad al centavo en importes porque se guardan con dos decimales exactos, y 0,01 puntos porcentuales en tasas por el redondeo de presentación. Captura del tablero con los filtros visibles.

#### E7. P7 Accesos

1. Conectarse en SSMS como `bi_reader`.
2. Acceso permitido: `SELECT TOP 5 * FROM bi.v_k1;` devuelve filas. Captura.
3. Acceso denegado a datos crudos: `SELECT TOP 5 * FROM stg.despacho;` debe dar el error 229 "The SELECT permission was denied on the object". Captura.
4. Acceso denegado a datos sensibles: `SELECT marca FROM cur.dim_marca;` también debe dar error 229, mientras que `SELECT DISTINCT marca_codigo FROM bi.v_despacho;` funciona y solo muestra códigos.
5. Separación de funciones: `etl_loader` puede ejecutar procedimientos pero no tiene `SELECT` sobre `bi` ni sobre `cur`, y `bi_reader` no puede ejecutar procedimientos: `EXEC ctl.sp_publicar_corte 1;` como `bi_reader` debe dar error de permiso EXECUTE.
6. En todas las capturas tapar la contraseña, la IP y cualquier identificador de suscripción.

Agregar al informe la tabla de identidades: `sqladmin` administra y ejecuta DDL, `etl_loader` lo usan Data Factory y el script de carga, `bi_reader` lo usa Power BI, y la identidad administrada de Data Factory solo lee el contenedor raw.

#### E8. P7 Costos y consultas equivalentes

**Comparación de consultas.** Dos versiones de K2 por mes con el mismo resultado. La versión A usa subconsultas correlacionadas, que recorren los hechos una vez por cada mes:

```sql
SET STATISTICS IO ON; SET STATISTICS TIME ON;
-- Version A
SELECT p.periodo,
       (SELECT SUM(importe_pen) FROM bi.v_despacho d WHERE d.periodo = p.periodo)
     - ISNULL((SELECT SUM(importe_devuelto_pen) FROM bi.v_reclamo r WHERE r.periodo = p.periodo), 0) AS neto
FROM (SELECT DISTINCT periodo FROM bi.v_despacho) p;
-- Version B
WITH b AS (SELECT periodo, SUM(importe_pen) AS bruto FROM bi.v_despacho GROUP BY periodo),
     r AS (SELECT periodo, SUM(importe_devuelto_pen) AS dev FROM bi.v_reclamo GROUP BY periodo)
SELECT b.periodo, b.bruto - ISNULL(r.dev, 0) AS neto FROM b LEFT JOIN r ON r.periodo = b.periodo;
```

Se ejecuta cada una una vez para calentar la caché y luego tres veces alternadas A, B, A, B, A, B. En la pestaña "Mensajes" de SSMS se anotan las **lecturas lógicas** de cada tabla y el **tiempo de CPU**. Las lecturas lógicas no dependen de la caché, por eso son la métrica principal; el tiempo, con tan pocos datos, puede ser casi igual y se reporta como secundario. Igualdad de resultados:

```sql
-- debe devolver cero filas en ambas direcciones (meter A y B en dos CTE y hacer EXCEPT en cada sentido)
```

Guarden ambas consultas en `12_costos_consultas.sql`.

**Costo observado.** En "Cost Management", "Análisis de costos", filtrar por el grupo `rg-tobotex-pc3` y el mes, agrupar por servicio. Captura. Los costos tardan entre 8 y 24 horas en aparecer, así que conviene mirar al día siguiente de las cargas. Complementar con la métrica "Free amount consumed" de cada base, que muestra cuántos segundos de vCore se gastaron: es el costo observado de cómputo aunque la factura diga cero.

**Presupuesto.** Tomar la tabla que estimó Freddy y agregar la columna del costo observado. La sección 8 tiene los supuestos y una estimación de referencia.

#### E9. Bitácora de pruebas y Anexo C

`pruebas/bitacora_pruebas.csv` con una fila por prueba y por intento. Columnas: `id`, `caso` (tobotex o control), `lote`, `intento`, `run_id`, `corte`, `regla`, `esperado`, `observado`, `estado`, `consulta`, `evidencia`, `fecha`. El Anexo C del informe es esta misma tabla. Ejemplo de dos filas:

```
P3,tobotex,L1,2,<RunId>,C-20261125-02,Reenvio identico no crea corte,"0 ins 0 upd 43 omit 2 rech; corte sin cambio",<lo observado>,Aprobada,R10 conciliacion + v_corte_publicado,evidencias/P3/,2026-11-25
P8,control,L3,1,<RunId>,C-20261125-03 (sigue vigente),Interrupcion conserva corte,"marzo 160 / 8 / 152",<lo observado>,Aprobada,bi.v_k2,evidencias/P8/,2026-11-25
```

#### E10. Redactar el Capítulo 3

- **3.1.** El texto y la tabla de comparación ya están en el borrador. Falta el diagrama y los `RunId`. El diagrama muestra, dentro del grupo `rg-tobotex-pc3` y con la región escrita, la cuenta ADLS con su contenedor raw, Data Factory con su identidad administrada, el servidor SQL con las tres bases y sus seis esquemas, y Power BI Desktop fuera de Azure conectado con `bi_reader`. Cada flecha lleva la identidad que la usa. Se puede dibujar en draw.io o en una Whiteboard. Agregar el flujo del pipeline padre e hijo con los nombres de las actividades de E3, y el párrafo de contratos versionados.
- **3.2.** Tabla de controles C1 a C8 con regla, umbral, severidad, acción y evidencia. La severidad y la acción están en la sección 9.4 de este documento. Párrafo sobre qué bloquea la publicación, que son C1, C8 y cualquier error de preparación, y qué se aísla sin bloquear, que son C2 a C7. Tabla de conciliación por resultado de cada lote. Explicación de la recuperación ante la falla de esquema y ante la interrupción, con referencia a P5 y P8, y del puntero de corte como mecanismo de publicación atómica.
- **3.3.** Tabla de identidades y permisos, resultado de las pruebas de acceso, presupuesto con estimado y observado, y la comparación de consultas con sus métricas.
- **3.4.** La bitácora de pruebas resumida, una fila por prueba con su estado final, y la nota de cualquier prueba que haya fallado en el primer intento.
- **Conclusiones**, entre cinco y siete, cada una con un número medido.

#### E11. Paquete, demostración y limpieza

**README** con prerrequisitos de la sección 4.1, recursos de la sección 4.2, orden de ejecución completo (generador, scripts 00 a 11, subir raw, pipeline por lote con sus parámetros, Power BI), parámetros de cada pipeline, la forma de reiniciar con `98_reset_datos.sql`, y la limpieza.

**Demostración de ocho minutos**, que se puede grabar con las ejecuciones ya registradas: un minuto de contexto con el tablero y el corte visible; P3 con el reenvío en el monitor de Data Factory y el corte que no cambia; P4 con la matriz de comparación de cortes donde solo cambia septiembre y la consulta de SCD; P6 con los tres valores lado a lado; P8 con la falla en rojo, el tablero que sigue en el corte anterior y luego el reintento con el corte nuevo. Cerrar con el Anexo E.

**Limpieza.** Al entregar y una vez calificado, eliminar el grupo de recursos completo desde el portal. Antes de eso, pausar Data Factory no hace falta porque sin desencadenadores activos no cobra, y las bases gratuitas en pausa tampoco cobran. Verificar en "Cost Management" días después que no quede nada facturando.

---

## 7. Valores esperados

### 7.1 Anexo E, por corte y mes

Importes en soles. Bruto por mes de venta, devuelto por mes de devolución. Verificado con `anexo_e.py`.

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

Qué explica cada cambio. En C1 marzo sube 40: la versión 2 de V04 reemplaza 40 por 50 y suma 10, V05 entra una sola vez y suma 30, y V06 con −5,00 va a cuarentena. En C2 febrero baja su neto en 4 por D04, una devolución tardía de V02 del 20 de febrero; enero no cambia y es el período de control; D04 toma la región Norte porque S1 fue Norte hasta el 1 de marzo, con la fecha final excluida. En C3 entra V07 con 20 de venta y D05 con 5 de devolución en el mismo lote. Si se publicara solo la venta de L3 el tablero mostraría marzo con bruto 180 y devuelto 8, una mezcla de dos cortes que no corresponde a ninguno.

### 7.2 Caso propio, por corte y mes

Valores de `calculo_independiente_tobotex.py` con el generador de este documento. Son la referencia de P1 a P4 y P8.

| Corte | Lote | Conciliación de despacho | Conciliación de reclamo |
|---|---|---|---|
| C0 | L0 | 600 leídas, 600 insertadas | 49 leídas, 49 insertadas |
| C1 | L1 | 45 leídas: 40 ins, 2 upd, 1 omit, 2 rech | no trae |
| sin corte | L1 reenvío | 45 leídas: 0 ins, 0 upd, 43 omit, 2 rech | no trae |
| C2 | L2 | 1 leída, 1 actualizada | 3 leídas, 3 insertadas |
| sin corte | LX | rechazo de esquema, nada clasificado | no trae |
| C3 | L3 | 15 leídas, 15 insertadas | 3 leídas, 3 insertadas |

| Mes | Corte | Bruto K1 | Devuelto | Neto K2 | K3 |
|---|---|---|---|---|---|
| Julio | C0 a C3 | 49 197,85 | 1 283,63 | 47 914,22 | 2,61 % |
| Agosto | C0 a C3 | 55 318,59 | 908,81 | 54 409,78 | 1,64 % |
| Septiembre | C0 | 47 590,98 | 411,26 | 47 179,72 | 0,86 % |
| Septiembre | C1 | 47 581,98 | 411,26 | 47 170,72 | 0,86 % |
| Septiembre | C2 y C3 | 47 593,98 | 620,90 | 46 973,08 | 1,30 % |
| Octubre | C1 y C2 | 10 354,79 | 0,00 | 10 354,79 | 0,00 % |
| Octubre | C3 | 14 104,14 | 140,81 | 13 963,33 | 1,00 % |

Lectura. En C1 septiembre baja 9,00 porque dos movimientos pasaron a versión 2 con 50 unidades menos; no se marca como revisado porque L1 llegó el 4 de octubre, antes del cierre del día 5. En C2 septiembre sube 12,00 por la corrección de M000413 y su devuelto sube 209,64 por los tres reclamos tardíos; este sí se marca como revisado. Julio y agosto no cambian en ningún corte y sirven de período de control. Durante la falla de L3 octubre debe seguir en 10 354,79.

---

## 8. Costos y cómo cuidar el crédito

**Estimación de referencia** para un mes con unas 20 ejecuciones de pipeline, región Brazil South o East US, menos de 1 GB y moneda dólar. Freddy debe confirmarla con la calculadora de precios de Azure y anotar la fecha de consulta.

- Azure SQL Database, tres bases con la oferta gratuita: 0 dólares mientras no se agoten los 100 000 segundos de vCore de cada una.
- ADLS Gen2, Standard LRS, nivel Hot, menos de 10 MB: centavos.
- Data Factory: se cobra 1 dólar por cada 1 000 ejecuciones de actividad, 0,25 dólares por hora de DIU en las copias y 0,005 dólares por hora en las actividades de pipeline. Cada ejecución del pipeline tiene unas 20 actividades y hasta tres copias; cada copia se cobra como mínimo un minuto con 4 DIU. Veinte ejecuciones dan unas 400 actividades, 0,40 dólares, más unas 60 copias, alrededor de 1 dólar. Total cercano a 1,50 dólares.
- Power BI Desktop: gratis. No se usa Power BI Service.
- Total estimado: entre 1 y 3 dólares al mes, muy por debajo del crédito de 100 dólares y del presupuesto de 20.

**Cómo no quemar los segundos gratuitos de SQL.**

- Retraso de pausa automática en el mínimo, como en R1.
- Cerrar SSMS y Power BI cuando no se usan. Power BI en DirectQuery consulta la base cada vez que alguien mueve un filtro y la mantiene despierta.
- No crear desencadenadores programados activos.
- Revisar cada día la métrica "Free amount remaining" en la página de cada base. Si baja mucho, la base se pausará sola hasta el mes siguiente y no cobrará, pero tampoco se podrá usar, y eso sería un problema la semana de la entrega. En ese caso se puede crear una base gratuita nueva y volver a ejecutar los scripts, que para eso están versionados.

---

## 9. Dudas frecuentes y problemas que van a aparecer

### 9.1 Sobre la base de datos

**¿Por qué Azure SQL y no Synapse o Databricks?** Por volumen y por la publicación atómica. Con menos de mil filas, Synapse o Databricks agregan costo fijo y piezas sin ningún beneficio. Y mover el puntero dentro de una transacción garantiza que los dos hechos cambian de versión a la vez, cosa que sobre archivos Parquet requeriría un diseño adicional. Esta comparación es la que va en 3.1.

**¿Se cumple que las transformaciones corren en la nube?** Sí. Toda la tipificación, validación, versiones, SCD2 y publicación son procedimientos T-SQL que se ejecutan dentro de Azure SQL. El script Python y Data Factory solo trasladan archivos y llaman a los procedimientos.

**¿Por qué staging en texto?** Porque si una columna llega mal formada, una tabla tipificada rechazaría la copia completa y no sabríamos qué fila falló. En texto todo entra y la validación decide fila por fila.

**¿Por qué el hash se calcula por fila y no solo por archivo?** Porque el reenvío puede llegar con otro nombre de archivo o mezclado con filas nuevas. La huella de cada fila detecta cada repetición por separado. La huella del archivo, que está en el manifiesto, sirve para probar que lo que está en raw es lo que se recibió.

**¿Qué pasa si cargo un lote dos veces por error en medio de las pruebas?** Nada malo, ese es justamente el caso de P3. Se omite todo y no se crea corte. Si se cargan lotes en desorden, por ejemplo L2 antes de L1, los números de los cortes intermedios no coincidirán con la sección 7; en ese caso se ejecuta `98_reset_datos.sql` y se empieza de nuevo.

**¿Y si el pipeline se cae en un punto distinto al simulado?** Igual se recupera. Cualquier intento que no llegó a publicar queda con estado distinto de `PUBLICADO`, y el siguiente `sp_iniciar_lote` descarta su corte candidato y borra sus filas de trusted. Por eso relanzar el mismo lote siempre es seguro.

**¿Por qué el corte final tiene secuencia 5 si es el cuarto publicado?** Porque el candidato de L3 que falló consumió el número 4 y quedó como `DESCARTADO`. Es intencional: los números nunca se reutilizan y la bitácora muestra el intento fallido. En el informe se llaman C0 a C3 por orden de publicación y se aclara la secuencia interna.

### 9.2 Sobre Azure y Data Factory

**Error 40615 o "Cannot open server ... requested by the login. Client with IP address ... is not allowed".** Falta la regla de firewall de esa IP.

**Error de tiempo de espera la primera vez del día.** La base serverless estaba pausada. Reintentar a los 30 segundos. El script Python ya reintenta solo.

**Copy de Data Factory falla con 403 o "AuthorizationPermissionMismatch".** Falta el rol Lector de datos de Storage Blob de la identidad de Data Factory sobre la cuenta, o se asignó hace menos de cinco minutos.

**Copy falla con "Cannot connect to SQL Database".** Falta activar "Permitir que los servicios y recursos de Azure accedan a este servidor".

**El Lookup dice que la consulta no devolvió resultados.** El procedimiento debe terminar con un `SELECT` y empezar con `SET NOCOUNT ON`, si no Data Factory lee el mensaje de filas afectadas en lugar del resultado. Ya está así en los scripts.

**Get Metadata con "Structure" falla en el JSON.** Es esperable, ese campo no está disponible para JSON. Por eso los reclamos se validan después de copiarlos a staging.

**Región no permitida al crear un recurso.** Es la política de la suscripción de estudiante. Elegir otra de la lista y usarla para todo; si las bases ya están creadas en otra región, todo lo demás va a la región de las bases.

**Fechas corridas un día en el tablero.** Azure trabaja en UTC. Las fechas de negocio son `DATE` y no se convierten; las marcas de tiempo de publicación se convierten con `AT TIME ZONE 'SA Pacific Standard Time'`, que es la zona de Lima, como en `bi.v_corte_publicado`.

**"The SELECT permission was denied" al abrir Power BI.** Se está conectando con un usuario sin permiso, o se seleccionó una tabla fuera de `bi`. Con `bi_reader` y solo vistas de `bi` no debe pasar.

### 9.3 Sobre lo que pide el enunciado

**¿Hace falta HDFS o Hive?** No. La PC3 pide una plataforma cloud equivalente con almacenamiento, transformaciones y consultas en la nube. ADLS cumple el papel de raw y Azure SQL el de trusted y curated.

**¿Hace falta un volumen grande?** No. El enunciado de la PC3 no pide un mínimo de filas, a diferencia del parcial. Lo que evalúa es el comportamiento ante reenvíos, correcciones e interrupciones.

**¿Basta con el script Python o es obligatorio Data Factory?** El enunciado pide un procedimiento reproducible y parametrizado por lote; el script lo es y llama a procedimientos que corren en la nube. Pero la rúbrica acredita la ejecución en la nube relacionando cada evidencia con el servicio y el intento, y Data Factory da un `RunId` y un monitor que el script no da. Por eso las pruebas formales van por Data Factory y el script queda como respaldo declarado.

### 9.4 Controles de calidad implementados

| Control | Dimensión | Regla | Umbral | Severidad | Acción |
|---|---|---|---|---|---|
| C1 | Esquema | Todos los campos requeridos del contrato presentes | 0 faltantes | Bloqueante | Rechaza el lote, el corte vigente no cambia |
| C2 | Unicidad | Duplicado exacto dentro del lote o ya cargado | Sin tope | Aislable | Se omite y se cuenta |
| C3 | Unicidad | Misma clave y versión con contenido distinto | 0 | Aislable | Cuarentena |
| C4 | Completitud | Campo requerido nulo o con tipo inválido | 0 por fila | Aislable | Cuarentena |
| C5 | Dominio | Cantidades e importes mayores que cero, producto en catálogo | 0 por fila | Aislable | Cuarentena |
| C6 | Integridad referencial | Tienda vigente en la fecha; reclamo apunta a movimiento válido | 0 por fila | Aislable | Cuarentena |
| C7 | Oportunidad | Evento de un mes publicado y cerrado se marca revisado; más de 90 días tras el cierre se rechaza | 90 días | Informativo o aislable | Marca el período o cuarentena |
| C8 | Volumen | Rechazos de una fuente sobre el 20 por ciento de sus filas | 20 % | Bloqueante | Detiene la publicación |

Las versiones obsoletas, es decir una versión menor que la que ya existe, se cuentan como omitidas porque no son un error de datos sino información ya superada.

---

## 10. Detalles para corregir en el borrador actual

Mientras revisaba el avance encontré cosas que conviene arreglar antes de entregar, aunque no son técnicas:

- La portada dice **Grupo 8** y la fecha **7 de junio del 2026**. En los trabajos anteriores el grupo es el 11 y la PC3 es de noviembre.
- En 1.2 dice que los valores de corte de K5 "se heredan de la práctica 3"; debe decir de la práctica 2 o de la PC2.
- En el índice y en el cuerpo aparecen dos secciones numeradas **3.3**; la de pruebas es la 3.4.
- En 1.1 el primer párrafo empieza cortado ("que otras empresas de confección incorporan...").
- En 2.2 se habla de cinco dimensiones y la tabla las tiene; conviene decir explícitamente que fecha y tienda son las dos conformadas porque la rúbrica lo revisa por separado.
- En 2.1 la fuente F3 dice "CSV cargado a tabla"; con este diseño es CSV en raw cargado a `trusted.tienda` y convertido a `cur.dim_tienda`, y vale la pena escribirlo así porque es el tercer mecanismo de extracción que pide el enunciado.
- La referencia de Armbrust sobre lakehouse no corresponde al diseño elegido. Sirven más Kimball (2007) y Ramasamy y Chowdhury (2020), que cita el enunciado, la página de la oferta gratuita de Azure SQL y la documentación de Data Factory sobre la actividad Copy y Get Metadata.
