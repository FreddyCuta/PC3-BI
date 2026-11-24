"""Prevalidación manual de objetos JSONL (manual §3.2 y §6.4).

Comprueba, para cada línea, presencia de propiedades requeridas, valores nulos
y tipo inválido. Separa la ausencia estructural (C1) del resto (C4).
No sustituye la validación automática dentro de ADF: se ejecuta antes de subir
y su informe se conserva como prevalidación manual.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

BASE = Path(__file__).resolve().parent
EVIDENCIA = BASE.parent.parent / "evidencias" / "relevo" / "validacion_jsonl.json"

REQUERIDOS = {
    "id_reclamo": str,
    "id_movimiento": str,
    "fecha_reclamo": str,
    "cantidad_devuelta": ("entero",),
    "importe_devuelto_pen": ("decimal",),
}


def tipo_valido(valor: object, tipo: object) -> bool:
    """Acepta el tipo nativo o su representación textual inequívoca.

    Los JSONL entregados representan los importes como cadenas con punto
    decimal. Eso es admisible porque staging los recibe como NVARCHAR y los
    procedimientos aplican TRY_CAST. Un booleano nunca cuenta como número.
    """
    if isinstance(valor, bool):
        return False
    if tipo is str:
        return isinstance(valor, str)
    if "decimal" in tipo:
        if isinstance(valor, (int, float, Decimal)):
            return True
        if not isinstance(valor, str):
            return False
        try:
            Decimal(valor.strip())
            return True
        except InvalidOperation:
            return False
    if "entero" in tipo:
        if isinstance(valor, int):
            return True
        if not isinstance(valor, str):
            return False
        try:
            return Decimal(valor.strip()) == Decimal(int(valor.strip()))
        except (InvalidOperation, ValueError):
            return False
    return False


def revisar(ruta: Path) -> dict:
    problemas = []
    total = 0
    for numero, linea in enumerate(ruta.read_text(encoding="utf-8").splitlines(), start=1):
        if not linea.strip():
            continue
        total += 1
        try:
            objeto = json.loads(linea)
        except json.JSONDecodeError as exc:
            problemas.append({"linea": numero, "control": "C1", "motivo": f"JSON inválido: {exc.msg}"})
            continue
        if not isinstance(objeto, dict):
            problemas.append({"linea": numero, "control": "C1", "motivo": "La línea no es un objeto JSON"})
            continue
        for campo, tipo in REQUERIDOS.items():
            if campo not in objeto:
                problemas.append({"linea": numero, "control": "C1", "motivo": f"Falta propiedad requerida: {campo}"})
            elif objeto[campo] is None:
                problemas.append({"linea": numero, "control": "C4", "motivo": f"Valor nulo: {campo}"})
            elif not tipo_valido(objeto[campo], tipo):
                problemas.append({"linea": numero, "control": "C4", "motivo": f"Tipo inválido: {campo}"})
    return {
        "archivo": str(ruta.relative_to(BASE)),
        "objetos": total,
        "problemas": problemas,
        "resultado": "OK" if not problemas else "REVISAR",
    }


def main() -> None:
    resultados = []
    for ruta in sorted(BASE.glob("datos/tobotex/**/*.jsonl")):
        resultados.append(revisar(ruta))
    informe = {
        "generado_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "alcance": "prevalidación manual local; no es validación automática de ADF",
        "resultados": resultados,
    }
    EVIDENCIA.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCIA.write_text(json.dumps(informe, indent=2, ensure_ascii=False), encoding="utf-8")
    for r in resultados:
        print(f"{r['archivo']:<55} objetos={r['objetos']:>3}  {r['resultado']}  problemas={len(r['problemas'])}")
    print(f"Informe: {EVIDENCIA}")


if __name__ == "__main__":
    main()
