"""Escribe los datos de control del Anexo E por lote y calcula K1 y K2 de forma independiente por corte.
Uso: python anexo_e.py"""
import csv, json, os
from collections import defaultdict
from decimal import Decimal as D

VENTAS = [
 ("L0","V01","2026-01-10","S1","P1","WEB",1,"100.00"), ("L0","V02","2026-02-10","S1","P1","WEB",1,"120.00"),
 ("L0","V03","2026-03-10","S1","P2","TIENDA",1,"80.00"), ("L0","V04","2026-03-12","S2","P1","WEB",1,"40.00"),
 ("L1","V04","2026-03-12","S2","P1","WEB",2,"50.00"), ("L1","V05","2026-03-20","S1","P2","WEB",1,"30.00"),
 ("L1","V05","2026-03-20","S1","P2","WEB",1,"30.00"), ("L1","V06","2026-03-21","S2","P1","WEB",1,"-5.00"),
 ("L3","V07","2026-03-25","S2","P2","TIENDA",1,"20.00")]
DEVOL = [
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

def region(sede, fecha):
    for _, s, reg, desde, hasta in SEDES:
        if s == sede and desde <= fecha and (hasta == "" or fecha < hasta):
            return reg

print("corte;mes;bruto_K1;devuelto;neto_K2")
for i, lotes in enumerate([["L0"], ["L0","L1"], ["L0","L1","L2"], ["L0","L1","L2","L3"]]):
    vig = {}
    for lote, lin, f, sede, p, c, ver, imp in [r for r in VENTAS if r[0] in lotes]:
        if D(imp) <= 0:
            continue
        if lin not in vig or ver > vig[lin][2]:
            vig[lin] = (f, sede, ver, D(imp))
    bruto, dev = defaultdict(D), defaultdict(D)
    for f, sede, ver, imp in vig.values():
        bruto[f[:7]] += imp
    for lote, ev, lin, f, imp in [r for r in DEVOL if r[0] in lotes]:
        if lin in vig and D(imp) > 0:
            dev[f[:7]] += D(imp)
    for mes in ["2026-01","2026-02","2026-03"]:
        print(f"C{i};{mes};{bruto[mes]:.2f};{dev[mes]:.2f};{bruto[mes]-dev[mes]:.2f}")
print("Region D04 a su fecha:", region("S1", "2026-02-20"))
