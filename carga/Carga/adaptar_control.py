"""Genera la adaptación reproducible del Anexo E (manual §8.2).

Los originales en datos/control_anexoE no se modifican. La adaptación añade
cantidades artificiales y marca CONTROL para reutilizar los procedimientos de
Tobotex. Las fechas de recepción son supuestos de prueba declarados en cada
manifiesto, no datos originales del caso. No usar K5/K6 de esta adaptación
para análisis de negocio.
"""
from __future__ import annotations

import csv
import hashlib
import json
import shutil
from pathlib import Path

BASE = Path(__file__).resolve().parent
ORIGEN = BASE / "datos" / "control_anexoE"
DESTINO = BASE / "datos" / "control_adaptado"

FECHAS = {
    "L0": "2026-04-01",
    "L1": "2026-04-04",
    "L2": "2026-04-20",
    "L3": "2026-04-27",
}
CAMPOS_D = [
    "id_movimiento", "version", "fecha_salida", "tienda", "marca", "producto",
    "contrato", "detalle", "cantidad_contratada", "cantidad_despachada",
    "importe_pen", "fecha_actualizacion_origen",
]
CAMPOS_T = ["tienda", "zona_comercial", "vigente_desde", "vigente_hasta"]


def leer_csv(ruta: Path) -> list[dict[str, str]]:
    if not ruta.exists():
        return []
    with ruta.open(encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def escribir_csv(ruta: Path, campos: list[str], filas: list[dict[str, str]]) -> None:
    with ruta.open("w", encoding="utf-8", newline="") as fh:
        escritor = csv.DictWriter(fh, fieldnames=campos)
        escritor.writeheader()
        escritor.writerows(filas)


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    for lote, recepcion in FECHAS.items():
        carpeta = DESTINO / lote
        if carpeta.exists():
            shutil.rmtree(carpeta)
        carpeta.mkdir(parents=True)
        archivos: list[tuple[Path, int]] = []

        ventas = leer_csv(ORIGEN / lote / f"ventas_{lote}.csv")
        if ventas:
            filas = [
                dict(zip(CAMPOS_D, [
                    r["linea"], r["version"], r["fecha_venta"], r["sede"], "CONTROL",
                    r["producto"], r["linea"], "1", "1", "1", r["importe"],
                    recepcion + "T00:00:00",
                ]))
                for r in ventas
            ]
            ruta = carpeta / f"despacho_{lote}.csv"
            escribir_csv(ruta, CAMPOS_D, filas)
            archivos.append((ruta, len(filas)))

        sedes = leer_csv(ORIGEN / lote / f"sedes_{lote}.csv")
        if sedes:
            filas = [
                dict(zip(CAMPOS_T, [r["sede"], r["region"], r["vigente_desde"], r["vigente_hasta"]]))
                for r in sedes
            ]
            ruta = carpeta / f"tienda_{lote}.csv"
            escribir_csv(ruta, CAMPOS_T, filas)
            archivos.append((ruta, len(filas)))

        original_jsonl = ORIGEN / lote / f"devoluciones_{lote}.jsonl"
        if original_jsonl.exists():
            objetos = [json.loads(x) for x in original_jsonl.read_text(encoding="utf-8").splitlines() if x.strip()]
            filas = [
                {
                    "id_reclamo": r["evento"],
                    "id_movimiento": r["linea"],
                    "fecha_reclamo": r["fecha_devolucion"],
                    "cantidad_devuelta": 1,
                    "importe_devuelto_pen": r["importe"],
                    "motivo": "CONTROL",
                    "fecha_actualizacion_origen": recepcion + "T00:00:00",
                }
                for r in objetos
            ]
            ruta = carpeta / f"reclamo_{lote}.jsonl"
            ruta.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in filas), encoding="utf-8")
            archivos.append((ruta, len(filas)))

        manifiesto = {
            "lote": lote,
            "fecha_recepcion": recepcion,
            "origen": "control_anexoE",
            "adaptacion": "1.0",
            "fechas_recepcion": "supuestos de prueba, no datos originales",
            "archivos": [],
        }
        for ruta, cantidad in archivos:
            contenido = ruta.read_bytes()
            manifiesto["archivos"].append({
                "archivo": ruta.name,
                "filas": cantidad,
                "bytes": len(contenido),
                "sha256": hashlib.sha256(contenido).hexdigest(),
            })
        (carpeta / "manifiesto.json").write_text(
            json.dumps(manifiesto, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"{lote}: {len(archivos)} archivos, recepcion asumida {recepcion}")


if __name__ == "__main__":
    main()
