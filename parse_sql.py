# -*- coding: utf-8 -*-
"""Utilities to parse SQL lineage information for graph generation."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

# Regular expressions reused across the parser
_IDENT_CHARS = r"[A-Z0-9_\.$\"-]"
_TARGET_IDENT = rf"{_IDENT_CHARS}+"

_CREATE_TABLE_RE = re.compile(
    rf"\bCREATE\s+(?:OR\s+REPLACE\s+)?((?:TEMP|TEMPORARY)\s+)?TABLE\s+({_TARGET_IDENT})",
    flags=re.IGNORECASE,
)
_CREATE_VIEW_RE = re.compile(
    rf"\bCREATE\s+(?:OR\s+REPLACE\s+)?VIEW\s+({_TARGET_IDENT})",
    flags=re.IGNORECASE,
)
_INSERT_INTO_RE = re.compile(
    rf"\bINSERT\s+INTO\s+({_TARGET_IDENT})",
    flags=re.IGNORECASE,
)
_FROM_RE = re.compile(
    rf"\bFROM\s+({_TARGET_IDENT})(?:\s+(?:AS\s+)?({_TARGET_IDENT}))?",
    flags=re.IGNORECASE,
)
_JOIN_RE = re.compile(
    rf"\b(LEFT|RIGHT|FULL|INNER|CROSS)?\s*JOIN\s+({_TARGET_IDENT})(?:\s+(?:AS\s+)?({_TARGET_IDENT}))?(?:\s+ON\s+(.*?))?(?=\b(?:LEFT|RIGHT|FULL|INNER|CROSS)\s+JOIN\b|\bJOIN\b|\bWHERE\b|\bGROUP\b|\bORDER\b|\bHAVING\b|\bUNION\b|\bEXCEPT\b|\bINTERSECT\b|\bLIMIT\b|\bQUALIFY\b|$)",
    flags=re.IGNORECASE | re.DOTALL,
)
_SET_CATALOG_RE = re.compile(r"\bSET\s+CATALOG\s+([A-Z0-9_]+)\b", flags=re.IGNORECASE)
_WITH_HEADER_RE = re.compile(r"\bWITH\b(.*?)\bSELECT\b", flags=re.IGNORECASE | re.DOTALL)
_CTE_NAME_RE = re.compile(rf"\b({_TARGET_IDENT})\s+AS\s*\(", flags=re.IGNORECASE)
_ON_KEY_RE = re.compile(rf"({_IDENT_CHARS}+?)\s*=\s*({_IDENT_CHARS}+?)", flags=re.IGNORECASE)


@dataclass
class JoinInfo:
    """Information about a JOIN used while creating a target."""

    table: str
    join_type: str
    join_key: Optional[str]


@dataclass
class StatementInfo:
    """Metadata captured for a single SQL statement that produces a target."""

    id_stmt: int
    file: str
    target: str
    kind: str
    from_main: Optional[str]
    joins: List[JoinInfo]

    def to_dict(self) -> Dict[str, object]:
        return {
            "id_stmt": self.id_stmt,
            "file": self.file,
            "target": self.target,
            "kind": self.kind,
            "from_main": self.from_main,
            "joins": [join.__dict__ for join in self.joins],
        }


def _strip_comments(path: Path) -> Tuple[str, List[Tuple[int, str]]]:
    """Remove SQL comments while tracking SET CATALOG line numbers."""

    text = path.read_text(encoding="utf-8", errors="ignore")
    sanitized_lines: List[str] = []
    catalog_hits: List[Tuple[int, str]] = []
    in_block = False

    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line
        i = 0
        cleaned = []
        while i < len(line):
            if not in_block and line.startswith("/*", i):
                in_block = True
                i += 2
                continue
            if in_block:
                end = line.find("*/", i)
                if end == -1:
                    # comment continues in next line
                    i = len(line)
                    continue
                in_block = False
                i = end + 2
                continue
            if line.startswith("--", i):
                break
            cleaned.append(line[i])
            i += 1
        cleaned_line = "".join(cleaned)
        sanitized_lines.append(cleaned_line)
        if not in_block:
            match = _SET_CATALOG_RE.search(cleaned_line)
            if match:
                catalog_hits.append((lineno, match.group(1).upper()))

    sanitized = "\n".join(sanitized_lines)
    sanitized = re.sub(r"\s+", " ", sanitized)
    return sanitized, catalog_hits


def _split_statements(sql: str) -> List[str]:
    return [stmt.strip() for stmt in sql.split(";") if stmt.strip()]


def _extract_cte_names(stmt: str) -> Set[str]:
    header_match = _WITH_HEADER_RE.search(stmt)
    if not header_match:
        return set()
    header = header_match.group(1)
    names = set()
    for match in _CTE_NAME_RE.finditer(header):
        candidate = match.group(1).strip('"')
        if candidate:
            names.add(candidate.upper())
    return names


def _normalize_part(part: str) -> str:
    return part.strip().strip('"').upper()


def _qualify(name: str, current_catalog: str) -> str:
    parts = [p for p in (piece.strip() for piece in name.split('.')) if p]
    cleaned = [_normalize_part(part) for part in parts]
    if len(cleaned) >= 3:
        catalog, schema, table = cleaned[-3:]
    elif len(cleaned) == 2:
        schema, table = cleaned
        catalog = current_catalog
    elif len(cleaned) == 1:
        (table,) = cleaned
        schema = "DBO"
        catalog = current_catalog
    else:
        catalog, schema, table = current_catalog, "DBO", "?"
    return f"{catalog}.{schema}.{table}"


def _is_temporary(name: str) -> bool:
    return "TEMP" in name.upper() or "TMP" in name.upper()


def _extract_join_key(on_clause: Optional[str]) -> Optional[str]:
    if not on_clause:
        return None
    match = _ON_KEY_RE.search(on_clause)
    if not match:
        return None
    left = match.group(1).split('.')[-1].strip('"').upper()
    right = match.group(2).split('.')[-1].strip('"').upper()
    if left == right:
        return left
    return f"{left}={right}"


def _statement_kind(stmt: str) -> Tuple[Optional[str], Optional[str]]:
    table_match = _CREATE_TABLE_RE.search(stmt)
    if table_match:
        dest = table_match.group(2)
        if table_match.group(1):
            return "CREATE TEMP TABLE", dest
        return "CREATE TABLE", dest
    view_match = _CREATE_VIEW_RE.search(stmt)
    if view_match:
        return "CREATE VIEW", view_match.group(1)
    insert_match = _INSERT_INTO_RE.search(stmt)
    if insert_match:
        return "INSERT INTO", insert_match.group(1)
    set_match = _SET_CATALOG_RE.search(stmt)
    if set_match:
        return "SET CATALOG", set_match.group(1)
    return None, None


def _collect_sources(stmt: str, current_catalog: str) -> Tuple[Optional[str], List[JoinInfo]]:
    cte_names = _extract_cte_names(stmt)
    main_from: Optional[str] = None
    joins: List[JoinInfo] = []

    for match in _FROM_RE.finditer(stmt):
        raw = match.group(1)
        if raw.strip().startswith('('):
            continue
        base = raw.strip('"')
        if base.upper() in cte_names:
            continue
        qualified = _qualify(base, current_catalog)
        main_from = qualified
        break

    if not main_from:
        return None, []

    for match in _JOIN_RE.finditer(stmt):
        raw_table = match.group(2)
        if raw_table.strip().startswith('('):
            continue
        base = raw_table.strip('"')
        upper = base.upper()
        if upper in cte_names:
            continue
        qualified = _qualify(base, current_catalog)
        join_type = match.group(1).upper() if match.group(1) else "INNER"
        join_key = _extract_join_key(match.group(4))
        joins.append(JoinInfo(table=qualified, join_type=join_type, join_key=join_key))
    return main_from, joins


def parse_file(path: Path, default_catalog: str) -> Dict[str, object]:
    """Parse a SQL file extracting lineage metadata."""

    default_catalog = default_catalog.upper()
    sanitized_sql, catalog_hits = _strip_comments(path)
    statements = _split_statements(sanitized_sql)

    nodes: Set[str] = set()
    created: Set[str] = set()
    temporals: Set[str] = set()
    edges_lineage: List[Tuple[str, str, str, str]] = []
    edges_pairs: List[Tuple[str, str, str, Optional[str], str]] = []
    edges_usage: List[Tuple[str, str, str, str]] = []
    statements_info: List[StatementInfo] = []
    catalogs: List[Tuple[str, int, str]] = []

    current_catalog = default_catalog
    hit_index = 0
    temp_known: Set[str] = set()

    stmt_counter = 0
    for stmt in statements:
        kind, dest_raw = _statement_kind(stmt)

        if kind == "SET CATALOG" and dest_raw:
            current_catalog = dest_raw.upper()
            if hit_index < len(catalog_hits):
                line_no, catalog_name = catalog_hits[hit_index]
                hit_index += 1
            else:
                line_no, catalog_name = (0, current_catalog)
            catalogs.append((str(path), line_no, catalog_name))
            continue

        if not kind or not dest_raw:
            continue

        qualified_target = _qualify(dest_raw, current_catalog)
        stmt_counter += 1

        main_from, joins = _collect_sources(stmt, current_catalog)

        nodes.add(qualified_target)
        created.add(qualified_target)
        if _is_temporary(qualified_target.split('.')[-1]):
            temporals.add(qualified_target)
            temp_known.add(qualified_target)

        sources_for_usage: List[str] = []

        if main_from:
            nodes.add(main_from)
            edges_lineage.append((main_from, qualified_target, "FROM", str(path)))
            sources_for_usage.append(main_from)

        for join in joins:
            nodes.add(join.table)
            if main_from:
                edges_pairs.append((main_from, join.table, join.join_type, join.join_key, str(path)))
            sources_for_usage.append(join.table)

        for source in sources_for_usage:
            if source in temp_known:
                edges_usage.append((source, qualified_target, "UTILIZADO EN", str(path)))

        statements_info.append(
            StatementInfo(
                id_stmt=stmt_counter,
                file=str(path),
                target=qualified_target,
                kind=kind,
                from_main=main_from,
                joins=joins,
            )
        )

    result: Dict[str, object] = {
        "nodes": nodes,
        "created": created,
        "temporals": temporals,
        "edges_lineage": edges_lineage,
        "edges_pairs": edges_pairs,
        "edges_usage": edges_usage,
        "statements": [info.to_dict() for info in statements_info],
        "catalogs": catalogs,
    }
    return result
