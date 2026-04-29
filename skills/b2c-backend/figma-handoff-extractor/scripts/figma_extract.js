// figma_extract.js
//
// Reference implementation of the Figma hand-off extraction algorithm.
//
// This file is meant to be run via `Claude in Chrome:javascript_tool` while
// a tab is open on figma.com — the browser session can hit api.figma.com
// directly with the X-Figma-Token header, while the bash environment
// typically cannot (api.figma.com is rarely in the bash allowlist).
//
// Usage pattern (paste into javascript_tool one block at a time, since
// each tool call returns a result you'll inspect before the next):
//
//   const TOKEN = 'figd_...';           // user's personal access token
//   const FILE  = 'BrUcE26Th...';       // file key from URL
//
// Each function below is a self-contained step. Top-level await is not
// available in javascript_tool, so use .then() chains.

// ---------------------------------------------------------------------------
// Step 1 — Fetch the page list (depth=1)
// ---------------------------------------------------------------------------
function listPages(fileKey, token) {
  return fetch(`https://api.figma.com/v1/files/${fileKey}?depth=1`, {
    headers: { 'X-Figma-Token': token }
  })
    .then(r => r.json())
    .then(d => ({
      fileName: d.name,
      lastModified: d.lastModified,
      pages: (d.document?.children || []).map(c => ({
        id: c.id, name: c.name, type: c.type
      }))
    }));
}

// ---------------------------------------------------------------------------
// Step 2 — Get top-level children of a page (depth=2 to see frames)
// ---------------------------------------------------------------------------
function getPageStructure(fileKey, pageId, token) {
  return fetch(`https://api.figma.com/v1/files/${fileKey}/nodes?ids=${pageId}&depth=2`, {
    headers: { 'X-Figma-Token': token }
  })
    .then(r => r.json())
    .then(d => {
      const node = d.nodes[pageId]?.document;
      const kids = (node?.children || []).map(c => ({
        id: c.id,
        name: c.name,
        type: c.type,
        opacity: c.opacity ?? 1,
        visible: c.visible !== false,
        w: c.absoluteBoundingBox?.width,
        h: c.absoluteBoundingBox?.height,
        childCount: c.children?.length || 0
      }));
      return { pageName: node?.name, children: kids };
    });
}

// ---------------------------------------------------------------------------
// Step 3 — Fetch full subtree of one or more sections, store on window
// ---------------------------------------------------------------------------
// Subtree responses can be large (megabytes). Cache them on window so you
// can re-query the same data without paying the API cost again.
function fetchSubtrees(fileKey, sectionIds, token) {
  const ids = sectionIds.join(',');
  return fetch(`https://api.figma.com/v1/files/${fileKey}/nodes?ids=${ids}`, {
    headers: { 'X-Figma-Token': token }
  })
    .then(r => r.json())
    .then(d => {
      window.__figData = window.__figData || { nodes: {} };
      Object.assign(window.__figData.nodes, d.nodes);
      return Object.fromEntries(
        sectionIds.map(id => {
          const n = d.nodes[id]?.document;
          return [id, { name: n?.name, type: n?.type, childCount: n?.children?.length || 0 }];
        })
      );
    });
}

// ---------------------------------------------------------------------------
// Step 4 — Identify dimmed (out-of-scope) vs active children
// ---------------------------------------------------------------------------
function classifyTopLevel(sectionId) {
  const node = window.__figData.nodes[sectionId]?.document;
  if (!node) return null;
  const containers = ['SECTION','FRAME','INSTANCE','COMPONENT','GROUP','COMPONENT_SET'];
  const active = [];
  const dimmed = [];
  for (const c of node.children || []) {
    if (!containers.includes(c.type)) continue;
    const op = c.opacity ?? 1;
    const entry = { id: c.id, name: c.name, type: c.type, opacity: op,
                    w: c.absoluteBoundingBox?.width, h: c.absoluteBoundingBox?.height };
    if (op >= 0.99) active.push(entry);
    else dimmed.push(entry);
  }
  return { sectionName: node.name, active, dimmed };
}

// ---------------------------------------------------------------------------
// Step 5 — Walk active subtree and collect text with parent context
// ---------------------------------------------------------------------------
// Returns array of { d, parents, text, parentName }
// Skips any node whose own opacity is < 0.99 (we treat opacity as
// effectively non-inheriting for this walk because the API gives us local
// opacity only — but since we already filtered top-level, this is fine).
function walkActiveText(node, depth = 0, parents = [], out = []) {
  if (!node || node.visible === false) return out;
  if ((node.opacity ?? 1) < 0.99) return out;

  if (node.type === 'TEXT' && node.characters) {
    out.push({
      d: depth,
      parents: parents.slice(-3).join(' > '),
      parentName: parents[parents.length - 1] || '',
      text: node.characters.replace(/\n/g, ' / ')
    });
  }

  if (node.children) {
    const isContainer = ['SECTION','FRAME','INSTANCE','COMPONENT','COMPONENT_SET'].includes(node.type);
    const newParents = isContainer ? [...parents, node.name] : parents;
    for (const c of node.children) walkActiveText(c, depth + 1, newParents, out);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Step 6 — Bucket A: extract policy cells (Summary table rows)
// ---------------------------------------------------------------------------
function extractPolicyCells(sectionId) {
  const node = window.__figData.nodes[sectionId]?.document;
  const all = walkActiveText(node);
  const policies = all.filter(t => t.parentName === 'Cell');
  // dedupe (same Summary table is often instantiated multiple times)
  const seen = new Set();
  return policies.filter(p => {
    if (seen.has(p.text)) return false;
    seen.add(p.text);
    return true;
  });
}

// ---------------------------------------------------------------------------
// Step 7 — Bucket B: extract case labels from "설명" instances
// ---------------------------------------------------------------------------
// Adjust the labelComponentName argument if the file uses a different
// convention (e.g., 'Note', 'Case', 'Description').
function extractCaseLabels(sectionId, labelComponentName = '설명') {
  const node = window.__figData.nodes[sectionId]?.document;
  const out = [];
  function recurse(n) {
    if (!n || n.visible === false || (n.opacity ?? 1) < 0.99) return;
    if (n.type === 'INSTANCE' && n.name === labelComponentName) {
      const texts = [];
      function gather(x) {
        if (x.type === 'TEXT' && x.characters) texts.push(x.characters.trim());
        if (x.children) for (const c of x.children) gather(c);
      }
      gather(n);
      if (texts.length) out.push(texts.join(' | '));
    }
    if (n.children) for (const c of n.children) recurse(c);
  }
  recurse(node);
  return out;
}

// ---------------------------------------------------------------------------
// Step 8 — Find clarification markers (🔥, ⚠️, TBD, TODO, etc.)
// ---------------------------------------------------------------------------
function findMarkers(sectionId) {
  const node = window.__figData.nodes[sectionId]?.document;
  const all = walkActiveText(node);
  const re = /🔥|⚠️|🚧|❓|❗|TBD|TODO|FIXME|확인필요|정의필요|미정/i;
  const seen = new Set();
  return all
    .filter(t => re.test(t.text))
    .filter(t => { if (seen.has(t.text)) return false; seen.add(t.text); return true; });
}

// ---------------------------------------------------------------------------
// Step 9 — Survey opacity values used in this specific file
// ---------------------------------------------------------------------------
// Run this once early in a session to confirm the dimming convention.
// If you see {1, 0.7, 0.2} the convention is "0.2 = out of scope, 0.7 =
// label". If you see {1, 0.5} adjust the cutoff accordingly.
function surveyOpacities(sectionId) {
  const node = window.__figData.nodes[sectionId]?.document;
  const counts = new Map();
  function recurse(n) {
    if (!n) return;
    const op = n.opacity ?? 1;
    counts.set(op, (counts.get(op) || 0) + 1);
    if (n.children) for (const c of n.children) recurse(c);
  }
  recurse(node);
  return Object.fromEntries([...counts.entries()].sort((a, b) => b[1] - a[1]));
}

// ---------------------------------------------------------------------------
// Convenience: full pipeline for one section
// ---------------------------------------------------------------------------
// Assumes fetchSubtrees() has already been called for this id.
function summarizeSection(sectionId, opts = {}) {
  const labelName = opts.labelComponentName || '설명';
  return {
    classify: classifyTopLevel(sectionId),
    policies: extractPolicyCells(sectionId),
    caseLabels: extractCaseLabels(sectionId, labelName),
    markers: findMarkers(sectionId)
  };
}

// Expose to window so subsequent javascript_tool calls can use them
window.figma_extract = {
  listPages, getPageStructure, fetchSubtrees,
  classifyTopLevel, walkActiveText,
  extractPolicyCells, extractCaseLabels, findMarkers, surveyOpacities,
  summarizeSection
};
