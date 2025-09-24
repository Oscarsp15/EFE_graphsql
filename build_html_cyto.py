# -*- coding: utf-8 -*-
"""
build_html_cyto.py
Cytoscape.js con:
- Temporales: verde (#22c55e), No temporales: gris (#64748b)
- Modo: Linaje (source->target) vs Pares JOIN (FROM->JOIN)
- Etiquetas de arista (LEFT/RIGHT/INNER/FROM, texto blanco con halo)
- Panel lateral, búsqueda, filtro "Solo temporales"
- Guardar/cargar posiciones
"""

import json
import re
from typing import Set, List, Tuple, Dict

def is_tmp(name: str) -> bool:
    return bool(re.search(r"\b(TMP|TEMP)\b", name, flags=re.IGNORECASE))

def build_html(
    nodes: Set[str],
    edges_lineage: List[Tuple[str, str, str, str, str]],
    edges_pairs:   List[Tuple[str, str, str, str]],
    title: str
) -> str:

    # Nodos (verde si temporal, gris si no)
    cy_nodes = []
    for n in sorted(nodes):
        cy_nodes.append({
            "data": {
                "id": n,
                "label": n,
                "isTmp": is_tmp(n),
                "color": "#22c55e" if is_tmp(n) else "#64748b"  # verde / gris
            },
            "classes": "tmp" if is_tmp(n) else "base"
        })

    # Aristas de linaje (source -> target)
    def join_class(j: str) -> str:
        j = (j or "").lower()
        if j.startswith("from"):  return "join-from"
        if j.startswith("left"):  return "join-left"
        if j.startswith("right"): return "join-right"
        if j.startswith("full"):  return "join-full"
        if j.startswith("inner"): return "join-inner"
        if j.startswith("cross"): return "join-cross"
        return "join-plain"

    cy_edges = []
    incomingL: Dict[str, List] = {}
    outgoingL: Dict[str, List] = {}
    for s, t, op, f, jtype in edges_lineage:
        eid = f"L::{s}=>{t}::{jtype}::{op}::{f}"
        lbl = (jtype or "").upper()
        cy_edges.append({
            "data": {
                "id": eid, "source": s, "target": t,
                "kind": "lineage",
                "join": lbl, "op": op, "file": f,
                "showLabel": lbl
            },
            "classes": f"etype-lineage {join_class(lbl)}"
        })
        incomingL.setdefault(t, []).append((s, lbl, op, f))
        outgoingL.setdefault(s, []).append((t, lbl, op, f))

    # Aristas de pares (FROM -> JOIN de la MISMA sentencia)
    incomingP: Dict[str, List] = {}
    outgoingP: Dict[str, List] = {}
    for a, b, jtype, f in edges_pairs:
        eid = f"P::{a}=>{b}::{jtype}::{f}"
        lbl = (jtype or "").upper()
        cy_edges.append({
            "data": {
                "id": eid, "source": a, "target": b,
                "kind": "pair",
                "join": lbl, "file": f,
                "showLabel": lbl
            },
            "classes": f"etype-pair {join_class(lbl)}"
        })
        incomingP.setdefault(b, []).append((a, lbl, f))
        outgoingP.setdefault(a, []).append((b, lbl, f))

    template = """<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>__TITLE__</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  body{background:#0b1220;color:#e5e7eb;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Inter}
  .toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding:10px;border-bottom:1px solid #223;position:sticky;top:0;background:#0b1220;z-index:9}
  input,button,select,label{color:#e5e7eb}
  input,select{background:#0f172a;border:1px solid #334155;border-radius:8px;padding:8px 10px}
  button{background:#0f172a;border:1px solid #334155;border-radius:8px;padding:8px 12px;cursor:pointer}
  #layoutRow{display:flex}
  #cy{height:calc(100vh - 72px);flex:1}
  #side{width:380px;border-left:1px solid #223;padding:10px;overflow:auto}
  .legend{display:flex;gap:10px;flex-wrap:wrap;margin-top:6px}
  .dot{width:12px;height:12px;border-radius:3px;display:inline-block}
  .pill{display:inline-block;background:#111827;border:1px solid #374151;border-radius:999px;padding:2px 8px;margin:2px 4px 2px 0;font-size:.8rem}
  .pill-tmp{background:#064e3b;border-color:#10b981;color:#a7f3d0}
  .tmpSummary{background:#111827;border:1px solid #1f2937;border-radius:10px;padding:8px 10px;margin:10px 0;font-size:.9rem}
  .muted{color:#9ca3af}
</style>
</head>
<body>
<div class="toolbar">
  <strong>__TITLE__</strong>
  <select id="mode">
    <option value="lineage" selected>Modo: Linaje (creación)</option>
    <option value="pairs">Modo: Pares JOIN (FROM → JOIN)</option>
  </select>
  <label><input type="checkbox" id="onlyTmp"> Solo temporales</label>
  <label><input type="checkbox" id="edgeLabels" checked> Etiquetas de aristas</label>
  <input id="search" placeholder="Buscar tabla... (Enter)"/>
  <button id="fit">Ajustar</button>
  <button id="relayout">Re-aplicar dagre</button>
  <button id="reset">Reset</button>
  <button id="savePos">Guardar posiciones</button>
  <button id="loadPos">Cargar posiciones</button>
  <button id="clearPos">Borrar posiciones</button>
</div>

<div id="layoutRow">
  <div id="cy"></div>
  <aside id="side">
    <h3 id="sideTitle">Selecciona un nodo</h3>
    <div class="muted">En Linaje: fuentes → destino de creación<br>En Pares: FROM → JOIN de la misma sentencia</div>
    <div id="meta"></div>
  </aside>
</div>

<script src="https://unpkg.com/cytoscape@3.26.0/dist/cytoscape.min.js"></script>
<script src="https://unpkg.com/dagre@0.8.5/dist/dagre.min.js"></script>
<script src="https://unpkg.com/cytoscape-dagre@2.5.0/cytoscape-dagre.js"></script>
<script>
const NODES   = __NODES__;
const EDGES   = __EDGES__;
const IN_L    = __IN_L__;
const OUT_L   = __OUT_L__;
const IN_P    = __IN_P__;
const OUT_P   = __OUT_P__;

cytoscape.use(cytoscapeDagre);

const cy = cytoscape({
  container: document.getElementById('cy'),
  elements: { nodes: NODES, edges: EDGES },
  wheelSensitivity: 0.2,
  style: [
    // nodos
    { selector: 'node', style: {
        'shape': 'round-rectangle',
        'width': 'label',
        'height': 'label',
        'padding': '6px',
        'background-color': 'data(color)',
        'border-color': '#0f172a', 'border-width': 1,
        'label': 'data(label)',
        'font-size': 12, 'color':'#ffffff',
        'text-outline-color':'#0b1220','text-outline-width':2,
        'text-wrap':'wrap','text-max-width':260,
        'text-valign':'center','text-halign':'center',
        'min-zoomed-font-size':8
    }},
    { selector: 'node.tmp',  style: { 'border-color':'#10b981', 'border-width':3 } },
    { selector: 'node.base', style: { } },

    // aristas (estilo base)
    { selector: 'edge', style: {
        'curve-style':'bezier',
        'target-arrow-shape':'triangle',
        'line-color':'#94a3b8',
        'target-arrow-color':'#94a3b8',
        'width': 2,
        'label': 'data(showLabel)',
        'font-size': 11, 'color':'#ffffff',
        'text-outline-color':'#0b1220','text-outline-width':2,
        'text-rotation':'autorotate',
        'text-background-opacity':0.35,
        'text-background-color':'#0b1220',
        'text-background-shape':'round-rectangle',
        'text-background-padding':'2px',
        'min-zoomed-font-size':8,
        'text-wrap':'wrap','text-max-width':200,
        'text-margin-y': -6
    }},
    // clases por tipo de join
    { selector:'edge.join-left',  style:{ 'line-style':'dashed','line-dash-pattern':[6,4], 'line-color':'#059669','target-arrow-color':'#059669' } },
    { selector:'edge.join-right', style:{ 'line-style':'dashed','line-dash-pattern':[2,6], 'line-color':'#d97706','target-arrow-color':'#d97706' } },
    { selector:'edge.join-full',  style:{ 'line-style':'dashed','line-dash-pattern':[1,3], 'width':3, 'line-color':'#dc2626','target-arrow-color':'#dc2626' } },
    { selector:'edge.join-inner', style:{ 'width':3, 'line-color':'#2563eb','target-arrow-color':'#2563eb' } },
    { selector:'edge.join-cross', style:{ 'line-style':'dashed','line-dash-pattern':[8,2], 'line-color':'#7c3aed','target-arrow-color':'#7c3aed' } },
    { selector:'edge.join-from',  style:{ 'line-color':'#9ca3af','target-arrow-color':'#9ca3af','width':1 } },

    // visibilidad por modo
    { selector:'edge.etype-lineage', style:{ 'display':'element' } },
    { selector:'edge.etype-pair',    style:{ 'display':'none'    } },

    // atenuado
    { selector:'.faded', style:{ 'opacity':0.12 } }
  ],
  layout: { name:'dagre', rankDir:'LR', nodeSep:80, rankSep:120, edgeSep:20, padding:20 }
});

// --------- Controles ----------
const modeSel   = document.getElementById('mode');
const onlyTmp   = document.getElementById('onlyTmp');
const edgeLbls  = document.getElementById('edgeLabels');

document.getElementById('fit').onclick = () => cy.fit(null,30);
document.getElementById('relayout').onclick = () => cy.layout({ name:'dagre', rankDir:'LR', nodeSep:80, rankSep:120 }).run();

document.getElementById('reset').onclick = () => {
  cy.elements().removeClass('faded');
  cy.nodes().forEach(n => n.style('display','element'));
  applyMode();
  applyOnlyTmp();
  applyEdgeLabels();
  cy.fit(null,30);
};

document.getElementById('savePos').onclick = () => {
  const pos={}; cy.nodes().forEach(n => pos[n.id()] = n.position());
  localStorage.setItem('sqlgraph_cyto_positions', JSON.stringify(pos));
  alert('Posiciones guardadas.');
};
document.getElementById('loadPos').onclick = () => {
  const raw = localStorage.getItem('sqlgraph_cyto_positions');
  if(!raw){ alert('No hay posiciones guardadas.'); return; }
  const pos = JSON.parse(raw);
  cy.nodes().forEach(n => { if(pos[n.id()]) n.position(pos[n.id()]); });
  cy.fit(null,30);
};
document.getElementById('clearPos').onclick = () => {
  localStorage.removeItem('sqlgraph_cyto_positions');
  alert('Posiciones borradas.');
};

const search=document.getElementById('search');
search.addEventListener('keydown', e=>{
  if(e.key!=='Enter') return;
  const q=(search.value||'').trim().toLowerCase();
  if(!q) return;
  const hit=cy.nodes().filter(n => (n.data('label')||'').toLowerCase().includes(q)).first();
  if(hit){ cy.elements().removeClass('faded'); cy.center(hit); hit.select(); }
});

// switches
modeSel.onchange = applyMode;
onlyTmp.onchange = applyOnlyTmp;
edgeLbls.onchange = applyEdgeLabels;

function applyMode(){
  const m = modeSel.value; // 'lineage' | 'pairs'
  cy.edges('.etype-lineage').style('display', m==='lineage' ? 'element' : 'none');
  cy.edges('.etype-pair').style('display',    m==='pairs'   ? 'element' : 'none');
}
function applyOnlyTmp(){
  const showTmp = onlyTmp.checked;
  cy.nodes().forEach(n => {
    const isTmp = n.data('isTmp');
    n.style('display', (showTmp && !isTmp) ? 'none' : 'element');
  });
}
function applyEdgeLabels(){
  const show = edgeLbls.checked;
  cy.edges().forEach(e => e.style('label', show ? e.data('showLabel') : ''));
}
applyMode(); applyOnlyTmp(); applyEdgeLabels();

// Panel lateral + enfoque
const sideTitle=document.getElementById('sideTitle');
const meta=document.getElementById('meta');

function tmpBadgeFor(id){
  const el = cy.getElementById(id);
  if(el && el.length && el.data('isTmp')){
    return ' <span class="pill pill-tmp">TMP</span>';
  }
  return '';
}

function renderDetails(id){
  const mode = modeSel.value;
  const node = cy.getElementById(id);
  const isTmpNode = !!(node && node.length && node.data('isTmp'));
  let inc = [], out = [];
  if(mode==='lineage'){ inc = IN_L[id] || []; out = OUT_L[id] || []; }
  else                { inc = IN_P[id] || []; out = OUT_P[id] || []; }

  let html='';
  if(mode==='lineage' && isTmpNode){
    const tmpUsages = out.filter(row => {
      const target = row[0];
      const targetEl = cy.getElementById(target);
      return targetEl && targetEl.length && targetEl.data('isTmp');
    }).length;
    const otherUsages = out.length - tmpUsages;
    if(out.length){
      html+=`<div class="tmpSummary">Utilizada en ${out.length} tabla(s): ${tmpUsages} temporales · ${otherUsages} permanentes.</div>`;
    }else{
      html+=`<div class="tmpSummary muted">Esta tabla temporal no es utilizada posteriormente.</div>`;
    }
  }
  html+=`<h4>Entrantes (${inc.length})</h4>`;
  if(inc.length===0) html+=`<div class="muted">—</div>`;
  inc.forEach(row => {
    if(mode==='lineage'){
      const [src,j,op,f]=row;
      html+=`<div class="pill">${j}</div> ${src}${tmpBadgeFor(src)} <span class="muted">· ${op} @ ${f}</span><br/>`;
    }else{
      const [src,j,f]=row;
      html+=`<div class="pill">${j}</div> ${src}${tmpBadgeFor(src)} <span class="muted">· ${f}</span><br/>`;
    }
  });
  const outTitle = (mode==='lineage' && isTmpNode) ? 'Utilizado en' : 'Salientes';
  html+=`<h4 style="margin-top:.8rem">${outTitle} (${out.length})</h4>`;
  if(out.length===0) html+=`<div class="muted">—</div>`;
  out.forEach(row => {
    if(mode==='lineage'){
      const [dst,j,op,f]=row;
      html+=`<div class="pill">${j}</div> ${dst}${tmpBadgeFor(dst)} <span class="muted">· ${op} @ ${f}</span><br/>`;
    }else{
      const [dst,j,f]=row;
      html+=`<div class="pill">${j}</div> ${dst}${tmpBadgeFor(dst)} <span class="muted">· ${f}</span><br/>`;
    }
  });
  meta.innerHTML = html;
}

cy.on('tap','node', evt=>{
  const n=evt.target;
  sideTitle.textContent=n.data('label');
  renderDetails(n.id());
  cy.elements().addClass('faded'); n.closedNeighborhood().removeClass('faded');
});
cy.on('tap', evt=>{
  if(evt.target===cy){
    cy.elements().removeClass('faded');
    sideTitle.textContent='Selecciona un nodo'; meta.innerHTML='';
  }
});

// Ajuste inicial
cy.fit(null, 30);
</script>
</body>
</html>"""

    html = (template
            .replace("__TITLE__", title)
            .replace("__NODES__", json.dumps(cy_nodes, ensure_ascii=False))
            .replace("__EDGES__", json.dumps(cy_edges, ensure_ascii=False))
            .replace("__IN_L__", json.dumps(incomingL, ensure_ascii=False))
            .replace("__OUT_L__", json.dumps(outgoingL, ensure_ascii=False))
            .replace("__IN_P__", json.dumps(incomingP, ensure_ascii=False))
            .replace("__OUT_P__", json.dumps(outgoingP, ensure_ascii=False)))
    return html
