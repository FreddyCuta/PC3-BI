"""Carga manual registrada de un lote a Azure SQL. Hace lo mismo que el pipeline de Data Factory,
en el mismo orden y llamando a los mismos procedimientos almacenados.

Adaptación local (manual §8.3): el argumento --umbral envía el tercer parámetro
C8 sólo a trusted.sp_merge_despacho y trusted.sp_merge_reclamo.
Tobotex usa 0.20; el fixture de control adaptado usa 0.25 (decisión documentada,
no regla oficial). trusted.sp_merge_tienda se llama siempre con dos argumentos.
Requiere que los procedimientos parametrizados de sql/fase3 estén desplegados.
"""
import argparse, csv, json, os, sys, time
import pyodbc

FUENTES = [
    ("tienda",   "tienda",   "csv",   ["tienda", "zona_comercial", "vigente_desde", "vigente_hasta"]),
    ("despacho", "despacho", "csv",   ["id_movimiento", "version", "fecha_salida", "tienda", "marca", "producto",
                                       "contrato", "detalle", "cantidad_contratada", "cantidad_despachada",
                                       "importe_pen", "fecha_actualizacion_origen"]),
    ("reclamo",  "reclamo",  "jsonl", ["id_reclamo", "id_movimiento", "fecha_reclamo", "cantidad_devuelta",
                                       "importe_devuelto_pen", "motivo", "fecha_actualizacion_origen"]),
]

def conectar():
    cadena = os.environ["AZ_SQL_CONN"]
    for intento in range(4):
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
    return None, filas

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lote", required=True)
    ap.add_argument("--carpeta", default=os.path.join("datos", "tobotex"))
    ap.add_argument("--falla", default="no", choices=["no", "tras_despacho"])
    ap.add_argument("--umbral", default="0.2000",
                    help="Umbral C8 para despacho y reclamo; 0.2000 Tobotex, 0.2500 control adaptado")
    a = ap.parse_args()
    try:
        umbral = float(a.umbral)
    except ValueError:
        sys.exit("--umbral debe ser decimal, por ejemplo 0.2000")
    if not 0 <= umbral <= 1:
        sys.exit("--umbral debe estar entre 0 y 1")
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
            if cabecera is not None:
                cur.execute("EXEC ctl.sp_validar_contrato ?, ?, ?, ?", a.lote, intento, fuente,
                            json.dumps([{"name": c} for c in cabecera]))
            datos = [[(None if f.get(c) in (None, "") else str(f.get(c))) for c in cols] + [a.lote, os.path.basename(ruta)]
                     for f in filas]
            if datos:
                cur.executemany(f"INSERT INTO stg.{fuente} ({', '.join(cols)}, lote_id, archivo) "
                                f"VALUES ({', '.join('?' * (len(cols) + 2))})", datos)
            if cabecera is None:
                cur.execute("EXEC ctl.sp_validar_contrato ?, ?, ?, NULL", a.lote, intento, fuente)
            print(f"  {fuente}: {len(datos)} filas a staging")
        cur.execute("EXEC trusted.sp_merge_tienda ?, ?", a.lote, intento)
        for sp in ["trusted.sp_merge_despacho", "trusted.sp_merge_reclamo"]:
            cur.execute(f"EXEC {sp} ?, ?, ?", a.lote, intento, umbral)
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
