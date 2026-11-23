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
candidatos = [x for x in L0 if x["fecha_salida"] <= "2026-09-20"]
muestra = [x for x in candidatos if random.random() < (0.40 if x["marca"] == "MK TALLAS" else 0.04)]
for m in muestra:
    f = date.fromisoformat(m["fecha_salida"]) + timedelta(days=random.randint(2, 9))
    rec0.append(reclamo(m, f))
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
L1.append(dict(L1[5]))
for m in [x for x in L0 if x["fecha_salida"] >= "2026-09-26"][:2]:
    v = dict(m); v["version"] = 2
    v["cantidad_despachada"] = int(m["cantidad_despachada"]) - 50
    v["importe_pen"] = f"{v['cantidad_despachada'] * PRODUCTOS[m['producto']]:.2f}"
    v["fecha_actualizacion_origen"] = "2026-10-03 09:00:00"; L1.append(v)
inv1 = movimientos(1, date(2026, 10, 2), date(2026, 10, 2))[0]
inv1["cantidad_despachada"] = 0; inv1["importe_pen"] = "0.00"; L1.append(inv1)
inv2 = movimientos(1, date(2026, 10, 2), date(2026, 10, 2))[0]
inv2["tienda"] = "GALERIA X"; L1.append(inv2)
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
rec2 = [reclamo(leo_sep[1], dias2(leo_sep[1]), "COLOR"),
        reclamo(leo_sep2[0], dias2(leo_sep2[0]), "DEFECTO_TEJIDO"),
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
