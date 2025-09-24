# -*- coding: utf-8 -*-
"""CLI to build the SQL lineage HTML graph and CSV extracts."""
from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

from build_html_cyto import build_html
from parse_sql import parse_file


def _resolve_case_insensitive(path: Path) -> Path | None:
    """Try to resolve a path ignoring case differences."""

    if path.exists():
        return path

    parts = path.parts
    if not parts:
        return None

    if path.is_absolute():
        current = Path(parts[0])
        index = 1
    else:
        current = Path('.')
        index = 0

    for idx in range(index, len(parts)):
        segment = parts[idx]
        try:
            candidates = list(current.iterdir())
        except FileNotFoundError:
            return None
        except NotADirectoryError:
            return None
        match = None
        for candidate in candidates:
            if candidate.name.lower() == segment.lower():
                match = candidate
                break
        if match is None:
            return None
        current = match
    return current


def _iter_sql_files(input_path: Path, pattern: str) -> List[Path]:
    if input_path.is_file():
        return [input_path]
    return sorted(input_path.rglob(pattern))


def _split_identifier(identifier: str) -> Tuple[str, str, str]:
    parts = identifier.split('.')
    if len(parts) >= 3:
        return parts[-3], parts[-2], parts[-1]
    if len(parts) == 2:
        return '(SIN CATALOGO)', parts[0], parts[1]
    if len(parts) == 1:
        return '(SIN CATALOGO)', 'DBO', parts[0]
    return '(SIN CATALOGO)', 'DBO', '?'


def _is_temporal(table_name: str) -> bool:
    upper = table_name.upper()
    return 'TEMP' in upper or 'TMP' in upper


def _prepare_node_payload(
    node_id: str,
    temporals: set[str],
    creations_map: Dict[str, List[dict]],
    consumers_map: Dict[str, List[dict]],
) -> dict:
    catalog, schema, table_name = _split_identifier(node_id)
    return {
        'id': node_id,
        'label': node_id,
        'isTmp': node_id in temporals or _is_temporal(table_name),
        'catalog': catalog,
        'schema': schema,
        'table_name': table_name,
        'creations': creations_map.get(node_id, []),
        'consumers': consumers_map.get(node_id, []),
    }


def _aggregate_results(files: Sequence[Path], default_catalog: str) -> Dict[str, object]:
    all_nodes: set[str] = set()
    temporals: set[str] = set()
    edges_lineage: List[Tuple[str, str, str, str]] = []
    edges_pairs: List[Tuple[str, str, str, str | None, str]] = []
    edges_usage: List[Tuple[str, str, str, str]] = []
    catalogs: List[Tuple[str, int, str]] = []
    statements: List[dict] = []

    creations_map: Dict[str, List[dict]] = defaultdict(list)
    consumers_map: Dict[str, List[dict]] = defaultdict(list)

    for file_path in files:
        result = parse_file(file_path, default_catalog=default_catalog)
        file_nodes = set(result.get('nodes', []))
        all_nodes.update(file_nodes)
        temporals.update(result.get('temporals', []))
        edges_lineage.extend(result.get('edges_lineage', []))
        edges_pairs.extend(result.get('edges_pairs', []))
        edges_usage.extend(result.get('edges_usage', []))
        catalogs.extend(result.get('catalogs', []))

        for stmt in result.get('statements', []):
            statements.append(stmt)
            creation_entry = {
                'from_main': stmt.get('from_main'),
                'joins': [
                    {
                        'table': join.get('table'),
                        'join_type': (join.get('join_type') or '').upper(),
                        'join_key': join.get('join_key'),
                    }
                    for join in stmt.get('joins', [])
                ],
                'kind': stmt.get('kind'),
                'file': stmt.get('file'),
            }
            creations_map[stmt['target']].append(creation_entry)

            sources = []
            if stmt.get('from_main'):
                sources.append(stmt['from_main'])
            for join in stmt.get('joins', []):
                src_table = join.get('table')
                if src_table:
                    sources.append(src_table)
            for source in sources:
                consumers_map[source].append(
                    {
                        'target': stmt['target'],
                        'kind': stmt.get('kind'),
                        'file': stmt.get('file'),
                    }
                )

    edges_pairs = list(dict.fromkeys(edges_pairs))
    edges_usage = list(dict.fromkeys(edges_usage))

    for key, consumers in list(consumers_map.items()):
        seen = set()
        deduped = []
        for consumer in consumers:
            ident = (consumer.get('target'), consumer.get('kind'), consumer.get('file'))
            if ident in seen:
                continue
            seen.add(ident)
            deduped.append(consumer)
        consumers_map[key] = deduped

    nodes_payload = [
        _prepare_node_payload(node_id, temporals, creations_map, consumers_map)
        for node_id in sorted(all_nodes)
    ]

    return {
        'nodes': nodes_payload,
        'temporals': temporals,
        'edges_lineage': edges_lineage,
        'edges_pairs': edges_pairs,
        'edges_usage': edges_usage,
        'statements': statements,
        'catalogs': catalogs,
    }


def _write_nodes_csv(path: Path, nodes: Sequence[dict]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['table', 'is_temp', 'catalog', 'schema', 'table_name'])
        for node in nodes:
            writer.writerow([
                node['id'],
                '1' if node.get('isTmp') else '0',
                node.get('catalog'),
                node.get('schema'),
                node.get('table_name'),
            ])


def _write_edges_lineage_csv(path: Path, edges: Sequence[Tuple[str, str, str, str]]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['source', 'target', 'op', 'file'])
        for src, dst, op, file in edges:
            writer.writerow([src, dst, op, file])


def _write_edges_pairs_csv(path: Path, edges: Sequence[Tuple[str, str, str, str | None, str]]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['src_from', 'dst_join', 'join_type', 'join_key', 'file'])
        for src, dst, join_type, join_key, file in edges:
            writer.writerow([src, dst, join_type, join_key or '', file])


def _write_edges_usage_csv(path: Path, edges: Sequence[Tuple[str, str, str, str]]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['source', 'consumer', 'op', 'file'])
        for src, dst, op, file in edges:
            writer.writerow([src, dst, op, file])


def _write_statements_csv(path: Path, statements: Sequence[dict]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['id_stmt', 'file', 'target', 'kind', 'from_main', 'joins_json'])
        for index, stmt in enumerate(statements, start=1):
            joins_json = json.dumps(stmt.get('joins', []), ensure_ascii=False)
            writer.writerow([
                index,
                stmt.get('file'),
                stmt.get('target'),
                stmt.get('kind'),
                stmt.get('from_main') or '',
                joins_json,
            ])


def _write_catalogs_csv(path: Path, catalogs: Sequence[Tuple[str, int, str]]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['file', 'lineno', 'catalog'])
        for file, lineno, catalog in catalogs:
            writer.writerow([file, lineno, catalog])


def main() -> None:
    parser = argparse.ArgumentParser(description='Genera un grafo HTML/CSV a partir de scripts SQL.')
    parser.add_argument('--input', required=True, help='Archivo SQL o carpeta con scripts.')
    parser.add_argument('--output', required=True, help='Ruta del HTML de salida.')
    parser.add_argument('--glob', default='*.sql', help='Patrón glob cuando --input es carpeta.')
    parser.add_argument('--default-catalog', required=True, help='Catálogo por defecto cuando no hay SET CATALOG.')
    args = parser.parse_args()

    input_path = Path(args.input)
    resolved_input = _resolve_case_insensitive(input_path)
    if resolved_input is None or not resolved_input.exists():
        raise SystemExit(f'No existe la ruta de entrada: {input_path}')
    input_path = resolved_input

    files = _iter_sql_files(input_path, args.glob)
    if not files:
        raise SystemExit('No se encontraron archivos SQL para procesar.')

    aggregated = _aggregate_results(files, args.default_catalog)
    nodes = aggregated['nodes']

    output_html = Path(args.output)
    output_html.parent.mkdir(parents=True, exist_ok=True)
    base = output_html.with_suffix('')

    _write_nodes_csv(base.parent / f'{base.name}.nodes.csv', nodes)
    _write_edges_lineage_csv(base.parent / f'{base.name}.edges_lineage.csv', aggregated['edges_lineage'])
    _write_edges_pairs_csv(base.parent / f'{base.name}.edges_pairs.csv', aggregated['edges_pairs'])
    _write_edges_usage_csv(base.parent / f'{base.name}.edges_usage.csv', aggregated['edges_usage'])
    _write_statements_csv(base.parent / f'{base.name}.statements.csv', aggregated['statements'])
    _write_catalogs_csv(base.parent / f'{base.name}.catalogs.csv', aggregated['catalogs'])

    html = build_html(
        nodes,
        aggregated['edges_lineage'],
        aggregated['edges_pairs'],
        aggregated['edges_usage'],
        f'SQL Graph - {base.name}',
    )
    output_html.write_text(html, encoding='utf-8')

    print(f'OK: {output_html}')
    print(f'OK: {base.parent / (base.name + ".nodes.csv")}')
    print(f'OK: {base.parent / (base.name + ".edges_lineage.csv")}')
    print(f'OK: {base.parent / (base.name + ".edges_pairs.csv")}')
    print(f'OK: {base.parent / (base.name + ".edges_usage.csv")}')
    print(f'OK: {base.parent / (base.name + ".statements.csv")}')
    print(f'OK: {base.parent / (base.name + ".catalogs.csv")}')


if __name__ == '__main__':
    main()
