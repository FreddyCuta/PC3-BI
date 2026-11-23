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

trusted_d, trusted_r = {}, {}
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
