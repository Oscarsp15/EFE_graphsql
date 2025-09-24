# -*- coding: utf-8 -*-
"""
make_sql_graph.py (compat)
- Soporta parse_sql.parse_file() devolviendo:
  * NUEVA API: dict con keys ["nodes","edges_lineage","edges_pairs","catalogs","statements"]
  * API ANTIGUA: list[(source,target,op,file[,join_type])]
- Genera HTML (Cytoscape) + CSVs.
CLI:
  python make_sql_graph.py --input PATH --output salida.html [--glob "*.sql"] [--default-catalog PROD_MODELOS]
"""

import argparse
import csv
from pathlib import Path
from typing import List, Set, Tuple

from build_html_cyto import build_html, is_tmp

# importación del parser
try:
    from parse_sql import parse_file  # esperamos esta firma
except Exception as e:
    raise SystemExit(f"No pude importar parse_sql.parse_file: {e}")

def _catalog_of(name: str) -> str:
    try:
        return name.split(".")[0] if "." in name else "(SIN CATALOGO)"
    except Exception:
        return "(SIN CATALOGO)"

def gather(files: List[Path], default_catalog: str | None):
    nodes: Set[str] = set()
    edges_lineage: List[Tuple[str,str,str,str,str]] = []
    edges_pairs:   List[Tuple[str,str,str,str]] = []
    catalogs: Set[str] = set()
    statements_all: List[str] = []

    for f in files:
        # Llamada compatible con ambas firmas (con/sin default_catalog)
        try:
            res = parse_file(f, default_catalog=default_catalog)
        except TypeError:
            # parse_file antiguo sin default_catalog
            res = parse_file(f)

        # --- NUEVA API: dict ---
        if isinstance(res, dict):
            # nodes
            if "nodes" in res:
                nodes.update(res["nodes"])
            # edges_lineage
            if "edges_lineage" in res:
                for row in res["edges_lineage"]:
                    # (s,t,op,file,join_type)
                    if isinstance(row, (list, tuple)):
                        if len(row) >= 5:
                            s,t,op,fi,jt = row[:5]
                        elif len(row) == 4:
                            s,t,op,fi = row; jt = ""
                        else:
                            continue
                        edges_lineage.append((s,t,op,fi,jt))
                        nodes.update((s,t))
                        catalogs.update([_catalog_of(s), _catalog_of(t)])
            # edges_pairs
            if "edges_pairs" in res:
                for row in res["edges_pairs"]:
                    # (from_table, join_table, join_type, file)
                    if isinstance(row, (list, tuple)) and len(row) >= 4:
                        a,b,jt,fi = row[:4]
                        edges_pairs.append((a,b,jt,fi))
                        nodes.update((a,b))
                        catalogs.update([_catalog_of(a), _catalog_of(b)])
            # catalogs
            if "catalogs" in res:
                catalogs.update(res["catalogs"])
            # statements
            if "statements" in res:
                statements_all.extend(res["statements"])

        # --- API ANTIGUA: lista de aristas (asumimos linaje) ---
        elif isinstance(res, (list, tuple)):
            for row in res:
                if not isinstance(row, (list, tuple)):
                    continue
                if len(row) >= 5:
                    s,t,op,fi,jt = row[:5]
                elif len(row) == 4:
                    s,t,op,fi = row
                    jt = ""
                else:
                    continue
                edges_lineage.append((s,t,op,fi,jt))
                nodes.update((s,t))
                catalogs.update([_catalog_of(s), _catalog_of(t)])
            # Aviso silencioso: no habrá edges_pairs ni statements
        else:
            # Formato desconocido: lo ignoramos sin romper
            continue

    return nodes, edges_lineage, edges_pairs, catalogs, statements_all

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Archivo .sql o carpeta")
    ap.add_argument("--output", required=True, help="HTML de salida")
    ap.add_argument("--glob", default="*.sql", help="Patrón si --input es carpeta")
    ap.add_argument("--default-catalog", default=None, help="Catálogo por defecto cuando falte SET CATALOG y/o calificador")
    args = ap.parse_args()

    p = Path(args.input)
    if not p.exists():
        raise SystemExit(f"No existe: {p}")

    files = sorted(p.rglob(args.glob)) if p.is_dir() else [p]

    nodes, edges_lineage, edges_pairs, catalogs, statements = gather(files, args.default_catalog)

    out_html = Path(args.output)
    base = out_html.with_suffix("")

    # CSV: nodes
    with (base.parent / f"{base.name}.nodes.csv").open("w", newline="", encoding="utf-8") as fw:
        w = csv.writer(fw)
        w.writerow(["name", "is_tmp"])
        for n in sorted(nodes):
            w.writerow([n, "Y" if is_tmp(n) else "N"])

    # CSV: edges_lineage (source -> target)
    with (base.parent / f"{base.name}.edges_lineage.csv").open("w", newline="", encoding="utf-8") as fw:
        w = csv.writer(fw)
        w.writerow(["source", "target", "op", "file", "join_type"])
        for row in edges_lineage:
            w.writerow(row)

    # CSV: edges_pairs (FROM -> JOIN)
    with (base.parent / f"{base.name}.edges_pairs.csv").open("w", newline="", encoding="utf-8") as fw:
        w = csv.writer(fw)
        w.writerow(["from_table", "join_table", "join_type", "file"])
        for row in edges_pairs:
            w.writerow(row)

    # CSV: catalogs
    with (base.parent / f"{base.name}.catalogs.csv").open("w", newline="", encoding="utf-8") as fw:
        w = csv.writer(fw)
        w.writerow(["catalog"])
        for c in sorted(catalogs):
            w.writerow([c])

    # HTML
    html = build_html(nodes, edges_lineage, edges_pairs, "SQL Dependency Graph (Linaje / Pares JOIN)")
    out_html.write_text(html, encoding="utf-8")

    print(f"OK: {out_html}")
    print(f"OK: {(base.parent / (base.name + '.nodes.csv'))}")
    print(f"OK: {(base.parent / (base.name + '.edges_lineage.csv'))}")
    print(f"OK: {(base.parent / (base.name + '.edges_pairs.csv'))}")
    print(f"OK: {(base.parent / (base.name + '.catalogs.csv'))}")
    if not edges_lineage and not edges_pairs:
        print("Aviso: no se detectaron dependencias (¿MERGE, SELECT INTO, funciones externas?).")

if __name__ == "__main__":
    main()
