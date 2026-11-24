"""Verificación local de manifiestos Tobotex (manual §3.1).

No modifica originales. Compara tamaño, SHA-256 y número de filas.
Los CSV entregados usan LF mientras que los manifiestos registran CRLF;
la opción --permitir-crlf acepta esa equivalencia y la deja documentada.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATOS = BASE / "datos" / "tobotex"
EVIDENCIA = BASE.parent.parent / "evidencias" / "relevo" / "verificacion_archivos.json"

CAMPOS_REQUERIDOS = {
    "despacho": [
        "id_movimiento", "version", "fecha_salida", "tienda", "marca", "producto",
        "contrato", "detalle", "cantidad_contratada", "cantidad_despachada", "importe_pen",
    ],
    "reclamo": [
        "id_reclamo", "id_movimiento", "fecha_reclamo", "cantidad_devuelta", "importe_devuelto_pen",
    ],
    "tienda": ["tienda", "zona_comercial", "vigente_desde"],
}


def sha256(contenido: bytes) -> str:
    return hashlib.sha256(contenido).hexdigest()


def contar_filas(ruta: Path, contenido: bytes) -> int:
    if ruta.suffix == ".csv":
        with ruta.open(encoding="utf-8", newline="") as fh:
            return len(list(csv.DictReader(fh)))
    return len([x for x in contenido.decode("utf-8").splitlines() if x.strip()])


def verificar(permitir_crlf: bool) -> dict:
    resultados = []
    for carpeta in sorted(p for p in DATOS.iterdir() if p.is_dir()):
        manifiesto = json.loads((carpeta / "manifiesto.json").read_text(encoding="utf-8"))
        for item in manifiesto["archivos"]:
            ruta = carpeta / item["archivo"]
            contenido = ruta.read_bytes()
            filas = contar_filas(ruta, contenido)
            exacto = (
                len(contenido) == item["bytes"]
                and sha256(contenido) == item["sha256"]
            )
            crlf = contenido.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            equivalente_crlf = (
                len(crlf) == item["bytes"] and sha256(crlf) == item["sha256"]
            )
            aceptado = exacto or (permitir_crlf and equivalente_crlf)
            resultados.append({
                "lote": carpeta.name,
                "archivo": item["archivo"],
                "filas_manifiesto": item["filas"],
                "filas_actuales": filas,
                "bytes_manifiesto": item["bytes"],
                "bytes_actuales": len(contenido),
                "sha256_manifiesto": item["sha256"],
                "sha256_actual": sha256(contenido),
                "coincide_exacto": exacto,
                "coincide_al_convertir_lf_a_crlf": equivalente_crlf,
                "aceptado": aceptado,
            })
    return {
        "generado_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "raiz": str(DATOS.relative_to(BASE.parent.parent)),
        "politica": "CRLF equivalente aceptado" if permitir_crlf else "comparación estricta",
        "total": len(resultados),
        "aceptados": sum(1 for r in resultados if r["aceptado"]),
        "rechazados": sum(1 for r in resultados if not r["aceptado"]),
        "resultados": resultados,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--permitir-crlf", action="store_true",
                    help="Aceptar CSV cuyo hash coincide al convertir LF a CRLF")
    args = ap.parse_args()
    informe = verificar(args.permitir_crlf)
    EVIDENCIA.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCIA.write_text(json.dumps(informe, indent=2, ensure_ascii=False), encoding="utf-8")
    for r in informe["resultados"]:
        estado = "OK" if r["aceptado"] else "RECHAZADO"
        print(f"{r['lote']:>3} {r['archivo']:<22} filas {r['filas_actuales']:>4}  {estado}")
    print(f"\nAceptados {informe['aceptados']}/{informe['total']}. Informe: {EVIDENCIA}")
    if informe["rechazados"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
