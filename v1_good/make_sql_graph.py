# -*- coding: utf-8 -*-
"""
make_sql_graph.py
Orquesta: parsea SQL, genera CSV y HTML (Cytoscape).
Uso:
  python make_sql_graph.py --input archivo.sql|carpeta --output salida.html [--glob "*.sql"] [--default-catalog PROD_MODELOS]
"""

import argparse
from pathlib import Path
import csv

from parse_sql import parse_file
from build_html_cyto import build_html

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Archivo SQL o carpeta")
    ap.add_argument("--output", required=True, help="HTML de salida")
    ap.add_argument("--glob", default="*.sql", help="Patrón si --input es carpeta")
    ap.add_argument("--default-catalog", default=None, help="Catálogo por defecto para nombres sin catálogo (ej. DBO.Tabla)")
    args = ap.parse_args()

    p = Path(args.input)
    if not p.exists():
        raise SystemExit(f"No existe: {p}")

    files = sorted(p.rglob(args.glob)) if p.is_dir() else [p]

    all_edges = []
    for f in files:
        all_edges.extend(parse_file(f, args.default_catalog))

    # nodos
    nodes = set()
    for s, t, *_ in all_edges:
        nodes.add(s); nodes.add(t)

    out_html = Path(args.output)
    out_csv  = out_html.with_suffix(".csv")

    # CSV (5 columnas fijas)
    with out_csv.open("w", newline="", encoding="utf-8") as fw:
        w = csv.writer(fw)
        w.writerow(["source","target","op","file","join_type"])
        for row in all_edges:
            s, t, op, f, j = row[:5]
            w.writerow([s, t, op, f, j])

    title = f"SQL Dependency Graph (v6/cyto) - {len(nodes)} nodos / {len(all_edges)} aristas"
    html = build_html(nodes, all_edges, title)
    out_html.write_text(html, encoding="utf-8")

    print(f"OK: {out_html}")
    print(f"OK: {out_csv}")
    if not all_edges:
        print("Aviso: no se detectaron dependencias (¿MERGE, SELECT INTO, funciones externas?).")

if __name__ == "__main__":
    main()
