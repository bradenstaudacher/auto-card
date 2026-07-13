// Content brainstorm board. Talks to /api/v1/drafts (same-origin — open this at
// http://localhost:3000/board.html so the Rails API is reachable). No build
// step: plain ES modules-free vanilla JS to match the static content browser.

const TYPE_COLORS = { Occult: '#8b3fd6', Holy: '#f4e88a', Law: '#7fb2e6', Fury: '#d63a4a', Death: '#1c1c22' };
const TYPE_TEXT   = { Occult: '#fff', Holy: '#3a3320', Law: '#12314f', Fury: '#fff', Death: '#f2f2f2' };
const TYPE_GLYPH  = { Occult: '⚗', Holy: '☀', Law: '⚖', Fury: '⚔', Death: '☠' };
const TYPES = ['Fury', 'Law', 'Occult', 'Death', 'Holy'];
const CATEGORIES = ['ability', 'weapon', 'equipment', 'passive', 'modifier'];
const RARITIES = ['common', 'uncommon', 'rare'];
const COLUMNS = [
  { status: 'proposed', label: 'Proposed' },
  { status: 'edits_needed', label: 'Edits Needed' },
  { status: 'accepted', label: 'Accepted' },
  { status: 'rejected', label: 'Rejected' },
];

let STATE = { drafts: [], core: { cards: [] } };

const $ = (id) => document.getElementById(id);
function esc(s) { return String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function glyphStyle(type) { return `background:${TYPE_COLORS[type] || '#4a4f5e'};color:${TYPE_TEXT[type] || '#fff'}`; }
function glyphChar(type) { return TYPE_GLYPH[type] || '◆'; }

function toast(msg, isErr) {
  const t = $('toast');
  t.textContent = msg;
  t.className = 'toast show' + (isErr ? ' err' : '');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => { t.className = 'toast'; }, 2600);
}

async function api(method, path, body) {
  const res = await fetch('/api/v1/drafts' + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let msg = res.status + ' ' + res.statusText;
    try { const j = await res.json(); if (j.error) msg = j.error; } catch (e) {}
    throw new Error(msg);
  }
  return res.status === 204 ? null : res.json();
}

async function load() {
  try {
    const data = await api('GET', '');
    STATE = data;
    render();
  } catch (e) {
    toast('Load failed: ' + e.message + ' — is Rails running on :3000?', true);
  }
}

// ---- Card rendering ----
function draftCard(d) {
  const tags = [`<span class="tag">${esc(d.category)}</span>`];
  if (d.rarity) tags.push(`<span class="tag rarity-${d.rarity}">${esc(d.rarity)}</span>`);
  if (d.type_affinity) tags.push(`<span class="tag">${esc(d.type_affinity)}</span>`);
  const promoted = d.promoted ? `<span class="badge-promoted">● in core</span>` : '';
  const notes = d.notes ? `<div class="notes">✎ ${esc(d.notes)}</div>` : '';
  const el = document.createElement('div');
  el.className = 'tcard' + (d.promoted ? ' promoted' : '');
  el.style.borderLeftColor = TYPE_COLORS[d.type_affinity] || '#4a4f5e';
  el.draggable = true;
  el.dataset.id = d.id;
  el.innerHTML = `
    <div class="row1">
      <div class="glyph" style="${glyphStyle(d.type_affinity)}">${glyphChar(d.type_affinity)}</div>
      <div class="name">${esc(d.name) || '(unnamed)'}</div>${promoted}
    </div>
    ${d.description ? `<div class="desc">${esc(d.description)}</div>` : ''}
    <div class="tags">${tags.join('')}</div>
    ${notes}`;
  el.addEventListener('click', () => openEditor(d));
  el.addEventListener('dragstart', (e) => {
    e.dataTransfer.setData('text/plain', d.id);
    e.dataTransfer.effectAllowed = 'move';
    el.classList.add('dragging');
  });
  el.addEventListener('dragend', () => el.classList.remove('dragging'));
  return el;
}

function refCard(c) {
  const el = document.createElement('div');
  el.className = 'tcard';
  el.style.borderLeftColor = TYPE_COLORS[c.type_affinity] || '#4a4f5e';
  el.style.cursor = 'default';
  el.innerHTML = `
    <div class="row1">
      <div class="glyph" style="${glyphStyle(c.type_affinity)}">${glyphChar(c.type_affinity)}</div>
      <div class="name">${esc(c.name)}</div>
    </div>
    ${c.description ? `<div class="desc">${esc(c.description)}</div>` : ''}
    <div class="tags"><span class="tag">${esc(c.category)}</span>${c.rarity ? `<span class="tag rarity-${c.rarity}">${esc(c.rarity)}</span>` : ''}</div>`;
  return el;
}

function render() {
  const total = STATE.drafts.length;
  const accepted = STATE.drafts.filter(d => d.status === 'accepted' && !d.promoted).length;
  $('meta').textContent = `${total} drafts · ${accepted} accepted awaiting promote · ${STATE.core.cards.length} live cards`;

  const board = $('board');
  board.innerHTML = '';
  for (const col of COLUMNS) {
    const items = STATE.drafts.filter(d => d.status === col.status);
    const colEl = document.createElement('div');
    colEl.className = 'col ' + col.status;
    colEl.innerHTML = `<div class="col-head"><span class="dot"></span>${col.label}<span class="count">${items.length}</span></div>`;
    const body = document.createElement('div');
    body.className = 'col-body';
    items.forEach(d => body.appendChild(draftCard(d)));
    wireDrop(body, col.status);
    colEl.appendChild(body);
    board.appendChild(colEl);
  }

  if ($('showRef').checked) {
    const colEl = document.createElement('div');
    colEl.className = 'col reference';
    colEl.innerHTML = `<div class="col-head"><span class="dot"></span>Live (core)<span class="count">${STATE.core.cards.length}</span></div>`;
    const body = document.createElement('div');
    body.className = 'col-body';
    STATE.core.cards.forEach(c => body.appendChild(refCard(c)));
    colEl.appendChild(body);
    board.appendChild(colEl);
  }
}

// ---- Drag/drop: dropping a draft into a column PATCHes its status ----
function wireDrop(body, status) {
  body.addEventListener('dragover', (e) => { e.preventDefault(); body.classList.add('drop-hover'); });
  body.addEventListener('dragleave', () => body.classList.remove('drop-hover'));
  body.addEventListener('drop', async (e) => {
    e.preventDefault();
    body.classList.remove('drop-hover');
    const id = e.dataTransfer.getData('text/plain');
    const d = STATE.drafts.find(x => x.id === id);
    if (!d || d.status === status) return;
    d.status = status; // optimistic
    render();
    try { await api('PATCH', '/' + id, { status }); }
    catch (err) { toast('Move failed: ' + err.message, true); load(); }
  });
}

// ---- Editor modal (create + edit share one form) ----
let EDITING = null; // draft object, or null for a new card

function field(label, name, value, opts = {}) {
  if (opts.type === 'select') {
    const options = opts.options.map(o =>
      `<option value="${esc(o)}" ${o === value ? 'selected' : ''}>${esc(o)}</option>`).join('');
    return `<div class="field"><label>${label}</label><select name="${name}">${opts.allowBlank ? `<option value="">—</option>` : ''}${options}</select></div>`;
  }
  if (opts.type === 'textarea') {
    return `<div class="field"><label>${label}</label><textarea name="${name}" rows="${opts.rows || 3}">${esc(value)}</textarea>${opts.hint ? `<div class="rules-hint">${opts.hint}</div>` : ''}</div>`;
  }
  return `<div class="field"><label>${label}</label><input name="${name}" value="${esc(value)}" placeholder="${esc(opts.placeholder || '')}" /></div>`;
}

function openEditor(draft) {
  EDITING = draft;
  const d = draft || { category: 'ability', rarity: 'common', rules: {} };
  const rulesText = JSON.stringify(d.rules || {}, null, 2);
  $('modal').innerHTML = `
    <h2>${draft ? 'Edit card' : 'New card'}</h2>
    ${field('Name', 'name', d.name || '', { placeholder: 'e.g. Frost Nova' })}
    <div class="grid2">
      ${field('Category', 'category', d.category, { type: 'select', options: CATEGORIES })}
      ${field('Type affinity', 'type_affinity', d.type_affinity || '', { type: 'select', options: TYPES, allowBlank: true })}
    </div>
    <div class="grid2">
      ${field('Rarity', 'rarity', d.rarity || 'common', { type: 'select', options: RARITIES })}
      ${field('Slot type', 'slot_type', d.slot_type || '', { placeholder: 'defaults to category' })}
    </div>
    ${field('Description', 'description', d.description || '', { type: 'textarea', rows: 2 })}
    ${field('Rules (JSON)', 'rules', rulesText, { type: 'textarea', rows: 6, hint: 'Machine data: stat_modifiers, combat_effects, ability_name, ability_params.' })}
    ${field('Triage notes', 'notes', d.notes || '', { type: 'textarea', rows: 2, hint: 'Private notes for the board (not shipped).' })}
    <div class="modal-actions">
      <button class="primary" id="saveBtn">${draft ? 'Save' : 'Create'}</button>
      <button class="ghost" id="cancelBtn">Cancel</button>
      <div class="spacer" style="flex:1"></div>
      ${draft ? '<button class="danger ghost" id="deleteBtn">Delete</button>' : ''}
    </div>`;
  $('overlay').classList.add('open');
  $('saveBtn').onclick = saveEditor;
  $('cancelBtn').onclick = closeEditor;
  if (draft) $('deleteBtn').onclick = () => deleteDraft(draft);
  $('modal').querySelector('[name=name]').focus();
}

function closeEditor() { $('overlay').classList.remove('open'); EDITING = null; }

function readForm() {
  const get = (n) => $('modal').querySelector(`[name=${n}]`);
  const rulesEl = get('rules');
  let rules;
  try { rules = JSON.parse(rulesEl.value || '{}'); }
  catch (e) { rulesEl.closest('.field').classList.add('err'); throw new Error('Rules is not valid JSON'); }
  rulesEl.closest('.field').classList.remove('err');
  return {
    name: get('name').value.trim(),
    category: get('category').value,
    type_affinity: get('type_affinity').value || null,
    rarity: get('rarity').value,
    slot_type: get('slot_type').value.trim() || null,
    description: get('description').value.trim(),
    rules,
    notes: get('notes').value.trim(),
  };
}

async function saveEditor() {
  let payload;
  try { payload = readForm(); } catch (e) { return toast(e.message, true); }
  if (!payload.name) return toast('Name is required', true);
  try {
    if (EDITING) await api('PATCH', '/' + EDITING.id, payload);
    else await api('POST', '', { ...payload, origin: 'manual' });
    closeEditor();
    await load();
    toast('Saved');
  } catch (e) { toast('Save failed: ' + e.message, true); }
}

async function deleteDraft(draft) {
  if (!confirm(`Delete "${draft.name}"? This cannot be undone.`)) return;
  try { await api('DELETE', '/' + draft.id); closeEditor(); await load(); toast('Deleted'); }
  catch (e) { toast('Delete failed: ' + e.message, true); }
}

async function promote() {
  const ready = STATE.drafts.filter(d => d.status === 'accepted' && !d.promoted);
  if (!ready.length) return toast('No accepted cards awaiting promotion');
  const names = ready.map(d => '• ' + d.name).join('\n');
  if (!confirm(`Promote ${ready.length} accepted card(s) into config/game/cards.yml?\n\n${names}\n\nThis appends them to the real game content file.`)) return;
  try {
    const res = await api('POST', '/promote');
    await load();
    toast(`Promoted ${res.count} card(s) into cards.yml`);
  } catch (e) { toast('Promote failed: ' + e.message, true); }
}

// ---- Wire header + init ----
$('addBtn').onclick = () => openEditor(null);
$('refreshBtn').onclick = load;
$('promoteBtn').onclick = promote;
$('showRef').onchange = render;
$('overlay').addEventListener('click', (e) => { if (e.target === $('overlay')) closeEditor(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeEditor(); });
load();
