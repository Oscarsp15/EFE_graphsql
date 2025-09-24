# -*- coding: utf-8 -*-
"""HTML builder for the Cytoscape.js lineage graph."""
from __future__ import annotations

import json
from typing import Sequence


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang=\"es\">
<head>
<meta charset=\"utf-8\" />
<title>__TITLE__</title>
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
<style>
body {
  background:#111827;
  color:#e5e7eb;
  font-family:'Inter',system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  margin:0;
}
header {
  border-bottom:1px solid #1f2937;
  background:#0f172a;
  position:sticky;
  top:0;
  z-index:10;
}
.toolbar {
  display:flex;
  flex-wrap:wrap;
  gap:0.5rem;
  padding:0.75rem 1rem;
  align-items:center;
}
.toolbar h1 {
  font-size:1.1rem;
  margin:0 1rem 0 0;
}
.toolbar input,
.toolbar select,
.toolbar button,
.toolbar label {
  font-size:0.9rem;
  color:#e5e7eb;
}
.toolbar input,
.toolbar select {
  background:#1f2937;
  border:1px solid #334155;
  border-radius:0.5rem;
  padding:0.45rem 0.6rem;
}
.toolbar button {
  background:#1f2937;
  border:1px solid #334155;
  border-radius:0.5rem;
  padding:0.45rem 0.75rem;
  cursor:pointer;
}
main {
  display:flex;
  min-height:calc(100vh - 4.5rem);
}
#cy {
  flex:1;
  height:calc(100vh - 4.5rem);
}
#sidebar {
  width:360px;
  max-width:100%;
  border-left:1px solid #1f2937;
  background:#0f172a;
  padding:1rem;
  overflow-y:auto;
}
.section {
  margin-bottom:1.5rem;
}
.section h2 {
  font-size:1rem;
  margin:0 0 0.5rem 0;
}
.badge {
  display:inline-block;
  background:#1f2937;
  border-radius:999px;
  padding:0.15rem 0.6rem;
  margin-right:0.5rem;
  font-size:0.8rem;
  border:1px solid #334155;
}
.badge.tmp {
  border-color:#10b981;
  color:#6ee7b7;
}
.list {
  list-style:none;
  padding:0;
  margin:0;
}
.list li {
  margin-bottom:0.35rem;
}
.muted {
  color:#9ca3af;
  font-size:0.85rem;
}
.edge-label-toggle {
  margin-left:0.5rem;
}
</style>
</head>
<body>
<header>
  <div class=\"toolbar\">
    <h1>__TITLE__</h1>
    <label>Buscar: <input id=\"searchInput\" type=\"search\" placeholder=\"Nombre de tabla\" /></label>
    <button id=\"searchGo\">Ir</button>
    <button id=\"fitBtn\">Fit</button>
    <button id=\"layoutBtn\">Re-aplicar layout</button>
    <label><input type=\"checkbox\" id=\"toggleLabels\" checked class=\"edge-label-toggle\" /> Etiquetas de aristas</label>
    <label><input type=\"checkbox\" id=\"toggleTemps\" checked /> Mostrar TMP/TEMP</label>
    <label>Catálogo:
      <select id=\"catalogFilter\">
        <option value=\"__ALL__\">Todos</option>
        __CATALOG_OPTIONS__
      </select>
    </label>
    <button id=\"savePos\">Guardar pos</button>
    <button id=\"loadPos\">Cargar pos</button>
    <button id=\"clearPos\">Borrar pos</button>
  </div>
</header>
<main>
  <div id=\"cy\"></div>
  <aside id=\"sidebar\">
    <div id=\"nodeTitle\" class=\"section\"><h2>Selecciona un nodo</h2><p class=\"muted\">Haz clic en una tabla para ver su construcción y uso.</p></div>
    <div id=\"creationSection\" class=\"section\"></div>
    <div id=\"usageSection\" class=\"section\"></div>
  </aside>
</main>
<script src=\"https://unpkg.com/cytoscape@3.26.0/dist/cytoscape.min.js\"></script>
<script src=\"https://unpkg.com/dagre@0.8.5/dist/dagre.min.js\"></script>
<script src=\"https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js\"></script>
<script>
const ELEMENT_NODES = __NODES_JSON__;
const ELEMENT_EDGES = __EDGES_JSON__;
const NODE_DETAILS = __NODE_DETAILS__;
const LOCAL_STORAGE_KEY = 'sqlgraph_cyto_positions';

cytoscape.use(cytoscapeDagre);

const cy = cytoscape({
  container: document.getElementById('cy'),
  elements: {
    nodes: ELEMENT_NODES,
    edges: ELEMENT_EDGES,
  },
  wheelSensitivity: 0.2,
  style: [
    {
      selector: 'node',
      style: {
        'shape': 'round-rectangle',
        'background-color': '#1f2937',
        'border-color': '#334155',
        'border-width': 2,
        'color': '#ffffff',
        'label': 'data(label)',
        'text-outline-color': '#0b1120',
        'text-outline-width': 3,
        'text-wrap': 'wrap',
        'text-max-width': 220,
        'padding': '8px',
        'font-size': 12,
        'min-zoomed-font-size': 8,
        'text-valign': 'center',
        'text-halign': 'center',
      }
    },
    {
      selector: 'node.tmp',
      style: {
        'border-color': '#10b981',
        'border-width': 3,
      }
    },
    {
      selector: 'edge',
      style: {
        'curve-style': 'bezier',
        'target-arrow-shape': 'triangle',
        'target-arrow-color': '#94a3b8',
        'line-color': '#94a3b8',
        'width': 2,
        'label': 'data(edgeLabel)',
        'font-size': 11,
        'color': '#ffffff',
        'text-outline-color': '#0b1120',
        'text-outline-width': 2,
        'text-background-color': '#0b1120',
        'text-background-opacity': 0.8,
        'text-background-shape': 'round-rectangle',
        'text-background-padding': '2px',
        'text-rotation': 'autorotate',
        'text-wrap': 'wrap',
        'text-max-width': 240,
        'min-zoomed-font-size': 8,
      }
    },
    { selector: 'edge.edge-lineage', style: { 'line-color': '#9ca3af', 'target-arrow-color': '#9ca3af' } },
    { selector: 'edge.edge-join', style: { 'target-arrow-color': '#9ca3af' } },
    { selector: 'edge.edge-usage', style: {
        'line-style': 'dashed',
        'line-dash-pattern': [4,4],
        'line-color': '#a78bfa',
        'target-arrow-color': '#a78bfa',
        'width': 2,
      }
    },
    { selector: 'edge.join-left', style: {
        'line-style': 'dashed',
        'line-dash-pattern': [6,4],
        'line-color': '#059669',
        'target-arrow-color': '#059669',
        'width': 2,
      }
    },
    { selector: 'edge.join-right', style: {
        'line-style': 'dashed',
        'line-dash-pattern': [2,6],
        'line-color': '#d97706',
        'target-arrow-color': '#d97706',
        'width': 2,
      }
    },
    { selector: 'edge.join-inner', style: {
        'line-color': '#2563eb',
        'target-arrow-color': '#2563eb',
        'width': 3,
      }
    },
    { selector: 'edge.join-full', style: {
        'line-style': 'dashed',
        'line-dash-pattern': [1,3],
        'line-color': '#dc2626',
        'target-arrow-color': '#dc2626',
        'width': 3,
      }
    },
    { selector: 'edge.join-cross', style: {
        'line-style': 'dashed',
        'line-dash-pattern': [8,2],
        'line-color': '#7c3aed',
        'target-arrow-color': '#7c3aed',
        'width': 2,
      }
    },
  ],
});

function runLayout() {
  cy.layout({ name: 'dagre', rankDir: 'LR', nodeSep: 120, rankSep: 100, edgeSep: 50 }).run();
}

runLayout();

const searchInput = document.getElementById('searchInput');
const searchButton = document.getElementById('searchGo');
const fitButton = document.getElementById('fitBtn');
const layoutButton = document.getElementById('layoutBtn');
const toggleLabels = document.getElementById('toggleLabels');
const toggleTemps = document.getElementById('toggleTemps');
const catalogFilter = document.getElementById('catalogFilter');
const savePos = document.getElementById('savePos');
const loadPos = document.getElementById('loadPos');
const clearPos = document.getElementById('clearPos');
const nodeTitle = document.getElementById('nodeTitle');
const creationSection = document.getElementById('creationSection');
const usageSection = document.getElementById('usageSection');

function showNodeDetails(node) {
  if (!node) {
    nodeTitle.innerHTML = '<h2>Selecciona un nodo</h2><p class="muted">Haz clic en una tabla para ver su construcción y uso.</p>';
    creationSection.innerHTML = '';
    usageSection.innerHTML = '';
    return;
  }
  const data = node.data();
  const details = NODE_DETAILS[data.id] || {};
  const label = data.label;
  nodeTitle.innerHTML = `<h2>${label}</h2>` + (data.isTmp ? '<span class="badge tmp">TMP/TEMP</span>' : '');

  const creations = details.creations || (details.creation ? [details.creation] : []);
  if (creations.length === 0) {
    creationSection.innerHTML = '<h2>Creación</h2><p class="muted">Sin información de creación.</p>';
  } else {
    const items = creations.map((entry) => {
      const joins = (entry.joins || []).map((j) => {
        const joinKey = j.join_key ? ` · por ${j.join_key}` : '';
        return `<li>${j.join_type}${joinKey}: ${j.table}</li>`;
      }).join('') || '<li class="muted">Sin JOINs</li>';
      const fromText = entry.from_main ? entry.from_main : '<span class="muted">Sin FROM principal</span>';
      const fileText = entry.file ? `<div class="muted">${entry.kind} · ${entry.file}</div>` : `<div class="muted">${entry.kind || ''}</div>`;
      return `<li><div><strong>FROM</strong>: ${fromText}</div><ul class="list">${joins}</ul>${fileText}</li>`;
    }).join('');
    creationSection.innerHTML = `<h2>Creación</h2><ul class="list">${items}</ul>`;
  }

  const consumers = details.consumers || [];
  if (consumers.length === 0) {
    usageSection.innerHTML = '<h2>Utilizado en</h2><p class="muted">Sin usos posteriores detectados.</p>';
  } else {
    const items = consumers.map((item) => `<li>${item.target}${item.kind ? ` · ${item.kind}` : ''}</li>`).join('');
    usageSection.innerHTML = `<h2>Utilizado en</h2><ul class="list">${items}</ul>`;
  }
}

function applyFilters() {
  const showTemps = toggleTemps.checked;
  const catalogValue = catalogFilter.value;
  const visibleNodes = new Set();

  cy.nodes().forEach((node) => {
    const isTmp = node.data('isTmp') === 1;
    const catalog = node.data('catalog');
    const matchesCatalog = catalogValue === '__ALL__' || catalog === catalogValue;
    const shouldShow = (!isTmp || showTemps) && matchesCatalog;
    node.style('display', shouldShow ? 'element' : 'none');
    if (shouldShow) {
      visibleNodes.add(node.id());
    }
  });

  cy.edges().forEach((edge) => {
    const srcVisible = visibleNodes.has(edge.source().id());
    const tgtVisible = visibleNodes.has(edge.target().id());
    const shouldShow = srcVisible && tgtVisible;
    edge.style('display', shouldShow ? 'element' : 'none');
  });
}

toggleTemps.addEventListener('change', applyFilters);
catalogFilter.addEventListener('change', applyFilters);

function performSearch() {
  const query = (searchInput.value || '').trim().toUpperCase();
  if (!query) {
    return;
  }
  const matches = cy.nodes().filter((node) => {
    return node.data('label').toUpperCase().includes(query);
  });
  if (matches.length > 0) {
    const target = matches[0];
    cy.elements().unselect();
    target.select();
    cy.animate({ center: { eles: target }, duration: 250, easing: 'ease' });
    showNodeDetails(target);
  }
}

searchInput.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    performSearch();
  }
});
searchButton.addEventListener('click', performSearch);

fitButton.addEventListener('click', () => {
  const visible = cy.elements().filter(':visible');
  cy.fit(visible, 50);
});

layoutButton.addEventListener('click', () => {
  runLayout();
});

toggleLabels.addEventListener('change', () => {
  const show = toggleLabels.checked;
  const style = cy.style();
  style.selector('edge').style('label', show ? 'data(edgeLabel)' : '');
  style.update();
});

savePos.addEventListener('click', () => {
  const positions = {};
  cy.nodes().forEach((node) => {
    const pos = node.position();
    positions[node.id()] = { x: pos.x, y: pos.y };
  });
  localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(positions));
  alert('Posiciones guardadas.');
});

loadPos.addEventListener('click', () => {
  const raw = localStorage.getItem(LOCAL_STORAGE_KEY);
  if (!raw) {
    alert('No hay posiciones guardadas.');
    return;
  }
  try {
    const saved = JSON.parse(raw);
    cy.nodes().forEach((node) => {
      if (saved[node.id()]) {
        node.position(saved[node.id()]);
      }
    });
  } catch (err) {
    console.error(err);
  }
});

clearPos.addEventListener('click', () => {
  localStorage.removeItem(LOCAL_STORAGE_KEY);
  alert('Posiciones eliminadas.');
});

cy.on('tap', 'node', (event) => {
  const node = event.target;
  cy.elements().unselect();
  node.select();
  showNodeDetails(node);
});

cy.on('tap', (event) => {
  if (event.target === cy) {
    cy.elements().unselect();
    showNodeDetails(null);
  }
});

applyFilters();
</script>
</body>
</html>
"""


def build_html(
    nodes: Sequence[dict],
    edges_lineage: Sequence[tuple],
    edges_pairs: Sequence[tuple],
    edges_usage: Sequence[tuple],
    title: str,
) -> str:
    """Return an interactive HTML page rendering the SQL lineage graph."""

    def node_entry(node: dict) -> dict:
        classes = []
        if node.get("isTmp"):
            classes.append("tmp")
        return {
            "data": {
                "id": node["id"],
                "label": node["label"],
                "isTmp": int(bool(node.get("isTmp"))),
                "catalog": node.get("catalog"),
                "schema": node.get("schema"),
                "table_name": node.get("table_name"),
            },
            "classes": " ".join(classes),
        }

    def lineage_entry(idx: int, src: str, dst: str, op: str, file: str) -> dict:
        return {
            "data": {
                "id": f"lineage-{idx}",
                "source": src,
                "target": dst,
                "edgeLabel": op,
                "kind": "lineage",
                "file": file,
            },
            "classes": "edge-lineage",
        }

    def join_label(join_type: str, join_key: str | None) -> str:
        base = (join_type or "").upper()
        if join_key:
            return f"{base} · por {join_key}"
        return base

    def join_entry(idx: int, src: str, dst: str, join_type: str, join_key: str | None, file: str) -> dict:
        jt = (join_type or "INNER").upper()
        classes = ["edge-join"]
        match jt:
            case "LEFT":
                classes.append("join-left")
            case "RIGHT":
                classes.append("join-right")
            case "FULL":
                classes.append("join-full")
            case "INNER" | "JOIN":
                classes.append("join-inner")
            case "CROSS":
                classes.append("join-cross")
            case _:
                classes.append("join-inner")
        return {
            "data": {
                "id": f"join-{idx}",
                "source": src,
                "target": dst,
                "edgeLabel": join_label(jt, join_key),
                "kind": "join",
                "joinType": jt,
                "joinKey": join_key,
                "file": file,
            },
            "classes": " ".join(classes),
        }

    def usage_entry(idx: int, src: str, dst: str, op: str, file: str) -> dict:
        return {
            "data": {
                "id": f"usage-{idx}",
                "source": src,
                "target": dst,
                "edgeLabel": op,
                "kind": "usage",
                "file": file,
            },
            "classes": "edge-usage",
        }

    cy_nodes = [node_entry(node) for node in nodes]
    lineage_edges = [
        lineage_entry(idx, src, dst, op, file)
        for idx, (src, dst, op, file) in enumerate(edges_lineage)
    ]
    join_edges = [
        join_entry(idx, src, dst, join_type, join_key, file)
        for idx, (src, dst, join_type, join_key, file) in enumerate(edges_pairs)
    ]
    usage_edges = [
        usage_entry(idx, src, dst, op, file)
        for idx, (src, dst, op, file) in enumerate(edges_usage)
    ]

    node_details = {
        node["id"]: {
            k: v for k, v in node.items() if k not in {"id", "label", "isTmp", "catalog", "schema", "table_name"}
        }
        for node in nodes
    }

    catalogs = sorted({node["catalog"] for node in nodes if node.get("catalog")})
    catalog_options = "".join(f'<option value="{c}">{c}</option>' for c in catalogs)

    nodes_json = json.dumps(cy_nodes, ensure_ascii=False)
    edges_json = json.dumps(lineage_edges + join_edges + usage_edges, ensure_ascii=False)
    node_details_json = json.dumps(node_details, ensure_ascii=False)

    html = (
        HTML_TEMPLATE
        .replace("__TITLE__", title)
        .replace("__CATALOG_OPTIONS__", catalog_options)
        .replace("__NODES_JSON__", nodes_json)
        .replace("__EDGES_JSON__", edges_json)
        .replace("__NODE_DETAILS__", node_details_json)
    )
    return html
