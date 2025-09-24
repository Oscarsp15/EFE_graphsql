# -*- coding: utf-8 -*-
"""
parse_sql.py
- Lee SET CATALOG <CAT>; y mantiene un catálogo actual.
- Cualquier objeto no calificado (sin catálogo) se califica con el catálogo actual.
- Normaliza nombres a: CATALOG.SCHEMA.TABLE (todo MAYÚSCULAS). Si falta schema, usa DBO.
- Devuelve aristas (source, target, op, file, join_type) con 5 campos.
"""

import re
from pathlib import Path
from typing import Dict, List, Tuple, Set

IDENT = r'[A-Z0-9_$."-]+'

# Targets
CREATE_TABLE_TARGET = re.compile(
    rf"\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:(?:TEMP|TEMPORARY)\s+)?TABLE\s+({IDENT})\b",
    flags=re.IGNORECASE,
)
CREATE_VIEW_TARGET = re.compile(
    rf"\bCREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+({IDENT})\b",
    flags=re.IGNORECASE,
)
INSERT_TARGET = re.compile(
    rf"\bINSERT\s+INTO\s+({IDENT})\b",
    flags=re.IGNORECASE,
)

# Fuentes con tipo
FROM_JOIN_WITH_TYPE = re.compile(
    rf"\b((?:FROM)|(?:(?:LEFT|RIGHT|FULL|INNER|CROSS)\s+JOIN)|(?:JOIN))\s+({IDENT})\b",
    flags=re.IGNORECASE,
)

# CTEs
WITH_CTE_HEADER = re.compile(r"\bWITH\b(.*?)\bSELECT\b", flags=re.IGNORECASE | re.DOTALL)
CTE_NAME = re.compile(rf"\b({IDENT})\s+AS\s*\(", flags=re.IGNORECASE)

# SET CATALOG
SET_CATALOG = re.compile(r"\bSET\s+CATALOG\s+([A-Z0-9_]+)\b", flags=re.IGNORECASE)

RESERVED = {
    'SELECT','FROM','JOIN','WHERE','GROUP','ORDER','BY','ON','UNION','ALL','WITH','AS',
    'INSERT','INTO','CREATE','TABLE','VIEW','VALUES','LEFT','RIGHT','FULL','INNER','OUTER',
    'CROSS','LATERAL','LIMIT','OFFSET','HAVING','DISTINCT'
}

def read_sql(path: Path) -> str:
    txt = path.read_text(encoding='utf-8', errors='ignore')
    txt = re.sub(r"/\*.*?\*/", " ", txt, flags=re.DOTALL)          # /* ... */
    txt = re.sub(r"(?m)\s*--.*?$", " ", txt)                       # -- ...
    txt = re.sub(r"\s+", " ", txt)
    return txt

def split_statements(sql: str) -> List[str]:
    return [s.strip() for s in sql.split(';') if s.strip()]

def extract_cte_names(stmt: str) -> Set[str]:
    names: Set[str] = set()
    m = WITH_CTE_HEADER.search(stmt)
    if not m:
        return names
    header = m.group(1)
    for m2 in CTE_NAME.finditer(header):
        n = m2.group(1).strip('"')
        if n and n.upper() not in RESERVED:
            names.add(n)
    return names

def norm_part(p: str) -> str:
    # quita comillas y normaliza a MAYÚSCULAS
    return p.strip().strip('"').upper()

def qualify(name: str, current_catalog: str | None, default_schema: str = "DBO") -> str:
    """
    Devuelve CATALOG.SCHEMA.TABLE.
    name puede venir como:
      - CATALOG.SCHEMA.TABLE
      - SCHEMA.TABLE           (usa catálogo actual)
      - TABLE                  (usa catálogo actual + DBO)
    """
    raw = name.strip()
    parts = [norm_part(p) for p in raw.split('.') if p.strip()]

    if len(parts) >= 3:
        cat, sch, tbl = parts[-3], parts[-2], parts[-1]
        return f"{cat}.{sch}.{tbl}"
    elif len(parts) == 2:
        sch, tbl = parts[0], parts[1]
        cat = (current_catalog or "").upper().strip() or "(SIN CATALOGO)"
        return f"{cat}.{sch}.{tbl}"
    elif len(parts) == 1:
        tbl = parts[0]
        cat = (current_catalog or "").upper().strip() or "(SIN CATALOGO)"
        sch = default_schema.upper()
        return f"{cat}.{sch}.{tbl}"
    else:
        # fallback raro: devuelve como "(SIN CATALOGO).DBO.?"
        cat = (current_catalog or "").upper().strip() or "(SIN CATALOGO)"
        return f"{cat}.{default_schema.upper()}.?"

def classify_join(token: str) -> str:
    t = token.upper()
    if t.startswith("FROM"): return "FROM"
    if "LEFT"  in t: return "LEFT"
    if "RIGHT" in t: return "RIGHT"
    if "FULL"  in t: return "FULL"
    if "INNER" in t: return "INNER"
    if "CROSS" in t: return "CROSS"
    return "JOIN"

def extract_sources(stmt: str, current_catalog: str | None) -> List[Tuple[str, str]]:
    """
    Devuelve [(fuente_ya_calificada, tipo_join)]
    Excluye CTEs.
    """
    cte_names = {n.upper() for n in extract_cte_names(stmt)}
    out: List[Tuple[str, str]] = []
    for m in FROM_JOIN_WITH_TYPE.finditer(stmt):
        token = m.group(1)
        raw = m.group(2)
        base = raw.strip('"')
        # si el token capturado es palabra reservada o es CTE, ignora
        if base.upper() in RESERVED or base.upper() in cte_names:
            continue
        q = qualify(base, current_catalog)
        out.append((q, classify_join(token)))
    return out

def _catalog_of(name: str) -> str:
    try:
        return name.split(".")[0]
    except Exception:
        return "(SIN CATALOGO)"


def parse_file(path: Path, default_catalog: str | None = None) -> Dict[str, object]:
    """
    Parsea el archivo SQL respetando SET CATALOG.
    Retorna un dict con llaves:
      - "nodes": set de objetos involucrados
      - "edges_lineage": [(source, target, op, file, join_type)]
      - "edges_pairs":   [(from_table, join_table, join_type, file)]
      - "catalogs": set de catálogos observados
      - "statements": lista de sentencias normalizadas
    """
    sql = read_sql(path)
    stmts = split_statements(sql)

    nodes: Set[str] = set()
    catalogs: Set[str] = set()
    edges_lineage: List[Tuple[str, str, str, str, str]] = []
    edges_pairs: List[Tuple[str, str, str, str]] = []
    stmts_out: List[str] = []

    current_catalog = (default_catalog.upper() if default_catalog else None)

    for s in stmts:
        stmts_out.append(s)
        # 1) SET CATALOG (actualiza contexto y continúa)
        mset = SET_CATALOG.search(s)
        if mset:
            current_catalog = norm_part(mset.group(1))
            continue

        sources = extract_sources(s, current_catalog)
        if sources:
            for src, _ in sources:
                nodes.add(src)
                catalogs.add(_catalog_of(src))

        # 2) CREATE TABLE ... AS SELECT ...
        m_ct = CREATE_TABLE_TARGET.search(s)
        if m_ct and re.search(r"\bAS\b.*?\bSELECT\b", s, flags=re.IGNORECASE | re.DOTALL):
            target_raw = m_ct.group(1)
            target = qualify(target_raw, current_catalog)
            nodes.add(target)
            catalogs.add(_catalog_of(target))
            for (src, jtype) in sources:
                edges_lineage.append((src, target, "CREATE TABLE", path.name, jtype))
            continue

        # 3) CREATE VIEW ... AS SELECT ...
        m_cv = CREATE_VIEW_TARGET.search(s)
        if m_cv and re.search(r"\bAS\b.*?\bSELECT\b", s, flags=re.IGNORECASE | re.DOTALL):
            target_raw = m_cv.group(1)
            target = qualify(target_raw, current_catalog)
            nodes.add(target)
            catalogs.add(_catalog_of(target))
            for (src, jtype) in sources:
                edges_lineage.append((src, target, "CREATE VIEW", path.name, jtype))
            continue

        # 4) INSERT INTO ... SELECT ...
        m_it = INSERT_TARGET.search(s)
        if m_it and re.search(r"\bSELECT\b", s, flags=re.IGNORECASE):
            target_raw = m_it.group(1)
            target = qualify(target_raw, current_catalog)
            nodes.add(target)
            catalogs.add(_catalog_of(target))
            for (src, jtype) in sources:
                edges_lineage.append((src, target, "INSERT", path.name, jtype))
            continue

        # Si la sentencia tiene múltiples fuentes (FROM + JOIN), arma pares
        base = None
        for src, jtype in sources:
            if jtype.upper().startswith("FROM"):
                base = src
                break
        if base:
            for src, jtype in sources:
                if src == base:
                    continue
                edges_pairs.append((base, src, jtype, path.name))

    return {
        "nodes": nodes,
        "edges_lineage": edges_lineage,
        "edges_pairs": edges_pairs,
        "catalogs": catalogs,
        "statements": stmts_out,
    }
