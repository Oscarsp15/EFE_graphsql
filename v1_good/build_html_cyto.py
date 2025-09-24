# -*- coding: utf-8 -*-
"""
build_html_cyto.py
Renderiza con Cytoscape.js:
- Colores por tipo de tabla:
  * Temporal (CREATE TEMP TABLE)           -> verde
  * Permanente creada (CREATE/VIEW/INSERT) -> azul
  * Externa (sólo fuente)                  -> gris
- Borde verde para temporales
- Aristas grises con etiqueta JOIN (LEFT/INNER/FROM/...)
- Label corto dentro del bloque; nombre completo en panel
"""

import json
import re
from typing import Set, List, Tuple, Dict

def _is_tmp_by_name(name: str) -> bool:
    return bool(re.search(r"\b(TMP|TEMP)\b", name, flags=re.IGNORECASE))

def build_html(nodes: Set[str],
               edges: List[Tuple[str, str, str, str, str]],
               title: str) -> str:

    temp_targets: Set[str] = set()
    perm_targets: Set[str] = set()

    for s, t, op, f, j in edges:
        up = (op or "").upper()
        if up == "CREATE TEMP TABLE":
            temp_targets.add(t)
        elif up in ("CREATE TABLE", "CREATE VIEW", "INSERT"):
            perm_targets.add(t)

    created = temp_targets | perm_targets
    COL_TEMP = "#10b981"
    COL_PERM = "#60a5fa"
    COL_EXT  = "#475569"

    cy_nodes = []
    for n in sorted(nodes):
        short = n.split('.')[-1]
        if n in temp_targets or _is_tmp_by_name(n):
            color = COL_TEMP; role = "Temporal"; classes = "tmp"
        elif n in perm_targets:
            color = COL_PERM; role = "Permanente"; classes = ""
        else:
            color = COL_EXT;  role = "Externa";    classes = ""
        cy_nodes.append({
            "data": { "id": n, "label": short, "full": n, "role": role, "color": color },
            "classes": classes
        })

    def edge_class(j: str) -> str:
        j = (j or "").upper()
        if j.startswith("FROM"): return "join-from"
        if "LEFT"  in j: return "join-left"
        if "RIGHT" in j: return "join-right"
        if "FULL"  in j: return "join-full"
        if "INNER" in j: return "join-inner"
        if "CROSS" in j: return "join-cross"
        return "join-plain"

    cy_edges = []
    incoming: Dict[str, List] = {}
    outgoing: Dict[str, List] = {}

    for s, t, op, f, jtype in edges:
        eid = f"{s}__{t}__{jtype}__{op}__{f}"
        cy_edges.append({
            "data": {
                "id": eid, "source": s, "target": t,
                "join": jtype or "", "op": op, "file": f,
                "activeLabel": jtype or ""
            },
            "classes": edge_class(jtype)
        })
        incoming.setdefault(t, []).append((s, jtype, op, f))
        outgoing.setdefault(s, []).append((t, jtype, op, f))

    elements = cy_nodes + cy_edges

    template = """<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>__TITLE__</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  body { background:#0b1220; color:#e5e7eb; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Inter; }
  .toolbar { display:flex; flex-wrap:wrap; gap:10px; align-items:center; padding:10px;
             border-bottom:1px solid #223; position:sticky; top:0; background:#0b1220; z-index:9; }
  input,button,select,label { color:#e5e7eb; }
  input,select { background:#0f172a; border:1px solid #334155; border-radius:8px; padding:8px 10px; }
  button { background:#0f172a; border:1px solid #334155; border-radius:8px; padding:8px 12px; cursor:pointer; }
  #layoutRow { display:flex; }
  #cy { height:calc(100vh - 72px); flex:1; }
  #side { width:420px; border-left:1px solid #223; padding:10px; overflow:auto; }
  .pill { display:inline-block; background:#111827; border:1px solid #374151; border-radius:999px; padding:2px 8px; margin:2px 6px 2px 0; font-size:.82rem; }
  .muted { color:#9ca3af; }
</style>
</head>
<body>
<div class="toolbar">
  <strong>__TITLE__</strong>
  <input id="search" placeholder="Buscar tabla... (Enter)"/>
  <button id="fit">Ajustar</button>
  <button id="layout">Re-aplicar dagre</button>
  <button id="reset">Reset</button>
  <button id="savePos">Guardar posiciones</button>
  <button id="loadPos">Cargar posiciones</button>
  <button id="clearPos">Borrar posiciones</button>
  <label><input type="checkbox" id="edgeLabels" checked> Etiquetas de aristas</label>
  <label><input type="checkbox" id="toggleTmp" checked> TMP/TEMP</label>
</div>

<div id="layoutRow">
  <div id="cy"></div>
  <aside id="side">
    <h3 id="sideTitle">Selecciona un nodo</h3>
    <div class="muted">Fuentes (entrantes) y destinos (salientes) con tipo de JOIN y archivo.</div>
    <div id="meta"></div>
  </aside>
</div>

<script src="https://unpkg.com/cytoscape@3.26.0/dist/cytoscape.min.js"></script>
<script src="https://unpkg.com/dagre@0.8.5/dist/dagre.min.js"></script>
<script src="https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js"></script>
<script>
const ELEMENTS = __ELEMENTS__;
const INCOMING  = __INCOMING__;
const OUTGOING  = __OUTGOING__;

cytoscape.use(cytoscapeDagre);

const cy = cytoscape({
  container: document.getElementById('cy'),
  elements: ELEMENTS,
  wheelSensitivity: 0.2,
  style: [
    { selector: 'node', style: {
        'shape': 'round-rectangle','width':'label','height':'label','padding':'6px',
        'background-color':'data(color)','border-color':'#334155','border-width':1,
        'label':'data(label)','color':'#e5e7eb','font-size':12,'text-wrap':'wrap','text-max-width':240,
        'text-valign':'center','text-halign':'center','text-outline-color':'#0b1220','text-outline-width':2
    }},
    { selector: 'node.tmp', style: { 'border-color':'#10b981','border-width':3 } },
    { selector: 'edge', style: {
        'curve-style':'bezier','target-arrow-shape':'triangle','line-color':'#9ca3af','target-arrow-color':'#9ca3af',
        'width':2,'label':'data(activeLabel)','font-size':9,'text-rotation':'autorotate',
            'color': '#ffffff',               // <<<<< texto de la etiqueta en blanco
    'text-outline-color': '#0b1220',   
    'text-outline-width': 2, 
        'text-background-opacity':0.2,'text-background-color':'#0b1220','text-background-padding':'2px'
    }},
    { selector:'edge.join-left',  style:{ 'line-style':'dashed','line-dash-pattern':[6,4] } },
    { selector:'edge.join-right', style:{ 'line-style':'dashed','line-dash-pattern':[2,6] } },
    { selector:'edge.join-full',  style:{ 'line-style':'dashed','line-dash-pattern':[1,3],'width':3 } },
    { selector:'edge.join-inner', style:{ 'width':3 } },
    { selector:'edge.join-cross', style:{ 'line-style':'dashed','line-dash-pattern':[8,2] } },
    { selector:'edge.join-from',  style:{ } },
    { selector: '.faded', style: { 'opacity': 0.12 } }
  ],
  layout: { name:'dagre', rankDir:'LR', nodeSep:80, rankSep:120, edgeSep:20, padding:20 }
});

document.getElementById('fit').onclick = () => cy.fit(null, 30);
document.getElementById('layout').onclick = () => cy.layout({ name:'dagre', rankDir:'LR', nodeSep:80, rankSep:120 }).run();

document.getElementById('reset').onclick = () => {
  cy.elements().removeClass('faded');
  cy.nodes().forEach(n => n.style('display','element'));
  const show = document.getElementById('edgeLabels').checked;
  cy.edges().forEach(e => e.data('activeLabel', show ? e.data('join') : ''));
  cy.fit(null, 30);
};

document.getElementById('edgeLabels').onchange = (e) => {
  const show = e.target.checked;
  cy.edges().forEach(ed => ed.data('activeLabel', show ? ed.data('join') : ''));
};
cy.on('mouseover','edge', e => { if(!document.getElementById('edgeLabels').checked) e.target.data('activeLabel', e.target.data('join')); });
cy.on('mouseout','edge',  e => { if(!document.getElementById('edgeLabels').checked) e.target.data('activeLabel',''); });

document.getElementById('toggleTmp').onchange = (e) => {
  const show = e.target.checked;
  cy.nodes().forEach(n => { if(n.hasClass('tmp')) n.style('display', show ? 'element' : 'none'); });
};

document.getElementById('savePos').onclick = () => {
  const pos = {}; cy.nodes().forEach(n => pos[n.id()] = n.position());
  localStorage.setItem('sqlgraph_cyto_positions', JSON.stringify(pos));
  alert('Posiciones guardadas.');
};
document.getElementById('loadPos').onclick = () => {
  const raw = localStorage.getItem('sqlgraph_cyto_positions');
  if (!raw) { alert('No hay posiciones guardadas.'); return; }
  const pos = JSON.parse(raw);
  cy.nodes().forEach(n => { if(pos[n.id()]) n.position(pos[n.id()]); });
  cy.fit(null, 30);
};
document.getElementById('clearPos').onclick = () => {
  localStorage.removeItem('sqlgraph_cyto_positions'); alert('Posiciones borradas.');
};

const search = document.getElementById('search');
search.addEventListener('keydown', e => {
  if (e.key !== 'Enter') return;
  const q = (search.value || '').trim().toLowerCase(); if (!q) return;
  const hit = cy.nodes().filter(n => (n.data('full') || '').toLowerCase().includes(q)).first();
  if (hit) { cy.elements().removeClass('faded'); cy.center(hit); hit.select(); }
});

const sideTitle = document.getElementById('sideTitle');
const meta = document.getElementById('meta');

function renderDetails(id) {
  const inc = INCOMING[id] || [];
  const out = OUTGOING[id] || [];
  const n = cy.getElementById(id);
  let html = '';
  html += `<div class="pill">Tipo: ${n.data('role')}</div>`;
  html += `<div class="pill">Nombre: ${n.data('full')}</div>`;
  html += `<h4 style="margin-top:.8rem">Fuentes (${inc.length})</h4>`;
  if (inc.length===0) html += `<div class="muted">—</div>`;
  inc.forEach(([src, j, op, f]) => { html += `<div class="pill">${j || 'JOIN'}</div> ${src} <span class="muted">· ${op} @ ${f}</span><br/>`; });
  html += `<h4 style="margin-top:.8rem">Destinos (${out.length})</h4>`;
  if (out.length===0) html += `<div class="muted">—</div>`;
  out.forEach(([dst, j, op, f]) => { html += `<div class="pill">${j || 'JOIN'}</div> ${dst} <span class="muted">· ${op} @ ${f}</span><br/>`; });
  meta.innerHTML = html;
}

cy.on('tap','node', evt => {
  const n = evt.target; sideTitle.textContent = n.data('full');
  renderDetails(n.id()); cy.elements().addClass('faded'); n.closedNeighborhood().removeClass('faded');
});
cy.on('tap', evt => {
  if (evt.target === cy) { cy.elements().removeClass('faded'); sideTitle.textContent = 'Selecciona un nodo'; meta.innerHTML = ''; }
});

cy.fit(null, 30);
document.getElementById('edgeLabels').dispatchEvent(new Event('change'));
</script>
</body>
</html>"""

    return (template
            .replace("__TITLE__", title)
            .replace("__ELEMENTS__", json.dumps(elements, ensure_ascii=False))
            .replace("__INCOMING__", json.dumps(incoming, ensure_ascii=False))
            .replace("__OUTGOING__", json.dumps(outgoing, ensure_ascii=False)))
