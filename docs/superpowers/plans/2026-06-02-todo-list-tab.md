# TO DO LIST Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5th "TO DO LIST" tab to the DIAGON planning app — a Firebase-synced task list grouped by chantier — to replace the Excel `TB COMMANDE DIAGON > TO DO LIST` sheet.

**Architecture:** All code lives in the single monolithic `index.html` (HTML + inline CSS + one `<script>` block, lines 607–2380). The feature reuses the existing data/sync plumbing: a new in-memory array `TACHES` is added to `syncToFirebase()` / `loadFromFirebase()` / `initDataSync()`, mutations go through `mutateAndSync()`, display-only refreshes through `rerender()`. The new view renders into the existing `#context-bar` (filters) and `#planning-body` (task table via a single full-width `<td colspan>`), with the planning header rows (`#week-row`, `#day-row`, `#coverage-row`) emptied while the view is active. Assignees ("QUI") are a new `cat: "admin"` resource category that never appears in the planning grid. A one-time seed imports the 77 current Excel tasks on first load.

**Tech Stack:** Vanilla HTML/CSS/JS, Tailwind CSS (CDN), Firebase Realtime Database (compat SDK), Firebase Auth. No build step, no test framework.

---

## Project-Specific Conventions (read before starting)

- **No test runner.** "Tests" in this project = (a) JS syntax check with `node --check`, (b) manual/preview verification in the browser. Every task's verify steps use these, not pytest.
- **Syntax check command** (run after every code edit to the script block):
  ```bash
  sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
  ```
  Expected output: `SYNTAX OK`. If line numbers shift as you add code, widen the range (the script block starts at `<script>` line 607 and ends at `</script>`; check `grep -n '</script>' index.html` for the new end line).
- **Sync pattern (critical):** `rerender()` = display only, NEVER syncs. `mutateAndSync()` = display + Firebase write. Only user-initiated mutations call `mutateAndSync()`. The seed is the one exception (it writes once via `syncToFirebase()` guarded by a "already seeded" check).
- **Naming:** English for variable/function names, French for UI labels. Always "DIAGON", never "Diagone". Dates local via `_localISO()` / the existing date helpers, never UTC.
- **Encadrement non-imputable:** admins (Julie, Kévin, Olivier, François, Laurent) must NEVER appear in any planning view — only in the TO DO LIST as assignees.
- **DEV_MODE:** off-production (`location.hostname !== "ffidale-ship-it.github.io"`) the app bypasses login and uses in-memory sample data; Firebase is NOT written. Verify the new view renders in DEV_MODE before relying on Firebase.
- **Commit cadence:** small, frequent commits. Do NOT push to `main` (that auto-deploys to production) without Frans's explicit go-ahead — he is non-technical; manage git for him and confirm before any push.

---

## File Structure

Only one file changes: `index.html`. New code is grouped by responsibility:

| Region (approx. current line) | What goes there |
|---|---|
| CSS block (~96–122, after `.view-bubble` rules) | `.view-bubble.todo-tab` styling (offset + bigger), `.prio-dot` colors, `.todo-*` table styles |
| Tab buttons HTML (~434–451) | New `#btn-view-taches` button with a separator/offset |
| Data section (~762–850) | `TACHES` global; `taches` key in `syncToFirebase`, `loadFromFirebase`, `initDataSync` |
| Resource category (~1128–1139, ~1682–1697, ~1756–1791) | `admin` category in selects, `migrateRessourcesSchema`, `addOuvrier`, `setOuvrierCat` |
| Helpers (~1146–1228) | `adminInitials`, `_taskNextId`, `adminById`, `resolveQui` |
| Views (~1488–1556) | `renderViewTaches()` + filter state + CRUD handlers |
| Seed (near data section) | `TACHES_SEED` const + `seedTachesIfNeeded()` |
| View routing (~2281–2298, ~2320–2328, ~2370–2373) | `_setWeeksForView`, `setView`, `rerender`, click binding |

---

## Architectural decisions (resolving the spec's open points)

1. **QUI storage = admin ids (per spec), resolved robustly.** `TACHE.qui` holds admin resource ids. The seed stores initials (e.g. `["KB","FF"]`) and `seedTachesIfNeeded()` resolves each initial to an admin id by matching `adminInitials(admin.nom)`. **To remove the seed-vs-admin-creation ordering trap, `seedTachesIfNeeded()` auto-creates any of the 5 known admins that don't already exist** (using the canonical map below) before resolving. If Frans already created them, they're matched by initials and reused; unmatched extras are never created twice. This keeps the id-based model while guaranteeing resolution.

   Canonical admin map (initials → name):
   - `JN` → "Julie Noville"
   - `KB` → "Kévin Bernard"
   - `OG` → "Olivier Gillet"
   - `FF` → "François Fidale"
   - `LD` → "Laurent Delehouse"

2. **Unknown chantier numbers stay grouped by number.** Chantiers 418, 419, 420 appear in the Excel but not in the app's `CHANTIERS`. Rather than dumping them into "Général" (which would mix them with genuinely chantier-less admin tasks), tasks keep their numeric `c` and `renderViewTaches()` shows a header like `418 - (chantier non listé)` when `chantierById(c)` is null. Only tasks with `c === null` (no leading number in the Excel cell) go to the "Général / sans chantier" group. Result: 10 tasks in Général, 67 under chantier groups (3 of them under not-yet-listed chantiers).

3. **Seeding runs once**, gated on `data.taches === undefined` at first load (the existing planning DB has no `taches` key yet). After the first seed the key exists, so it never re-runs. In DEV_MODE (no Firebase) the seed runs in-memory each load so the view is testable.

---

### Task 1: Add `admin` resource category

**Files:**
- Modify: `index.html` (`new-ouv-cat` select ~1694–1697; inline edit options ~1682–1684; `migrateRessourcesSchema` ~1128–1139; `addOuvrier` ~1756–1767; `setOuvrierCat` ~1785–1792)

- [ ] **Step 1: Add `admin` to the create-resource select**

In the `new-ouv-cat` select (currently):
```html
          <select id="new-ouv-cat" class="text-sm border border-slate-300 rounded px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="chantier">Chantier</option>
            <option value="atelier">Atelier</option>
            <option value="externe">Externe</option>
```
Add one line after the `externe` option:
```html
            <option value="admin">Admin</option>
```

- [ ] **Step 2: Add `admin` to the inline-edit category select**

In the per-row edit options (currently):
```html
          <option value="chantier" ${r.cat === 'chantier' ? 'selected' : ''}>Chantier</option>
          <option value="atelier" ${r.cat === 'atelier' ? 'selected' : ''}>Atelier</option>
          <option value="externe" ${r.cat === 'externe' ? 'selected' : ''}>Externe</option>
```
Add after the `externe` option:
```html
          <option value="admin" ${r.cat === 'admin' ? 'selected' : ''}>Admin</option>
```

- [ ] **Step 3: Make admins invisible in planning via `migrateRessourcesSchema`**

Replace the body of `migrateRessourcesSchema()`:
```js
function migrateRessourcesSchema() {
  RESSOURCES.forEach(r => {
    if (r.cat === "admin") { r.show_chantier = false; r.show_atelier = false; return; }
    if (r.show_chantier === undefined && r.show_atelier === undefined) {
      if (r.cat === "atelier") { r.show_chantier = false; r.show_atelier = true; }
      else { r.show_chantier = true; r.show_atelier = false; } // chantier et externe par defaut
    }
  });
  // Init order par defaut si pas encore defini : prend l'id comme ordre stable
  RESSOURCES.forEach((r, i) => {
    if (r.order === undefined) r.order = i * 10; // pas de 10 pour laisser de la place a l'insertion
  });
}
```

- [ ] **Step 4: Let `addOuvrier` accept admins without a planning scope**

Replace `addOuvrier()`:
```js
function addOuvrier() {
  const nom = document.getElementById("new-ouv-nom").value.trim();
  const cat = document.getElementById("new-ouv-cat").value;
  let show_chantier = document.getElementById("new-ouv-chantier").dataset.active === "1";
  let show_atelier = document.getElementById("new-ouv-atelier").dataset.active === "1";
  if (!nom) { alert("Entrez un nom"); return; }
  if (cat === "admin") { show_chantier = false; show_atelier = false; }
  else if (!show_chantier && !show_atelier) { alert("Cochez au moins 🏗 Chantier ou 🔧 Atelier."); return; }
  const id = Math.max(99, ...RESSOURCES.map(r => Number(r.id) || 0)) + 1;
  RESSOURCES.push({ id, nom, cat, visible: true, show_chantier, show_atelier });
  openModal("ouvriers");
  mutateAndSync();
}
```

- [ ] **Step 5: Allow `admin` in `setOuvrierCat`**

In `setOuvrierCat()`, change the guard:
```js
  if (!["chantier", "atelier", "externe"].includes(newCat)) return;
```
to:
```js
  if (!["chantier", "atelier", "externe", "admin"].includes(newCat)) return;
```
and right after `r.cat = newCat;` add:
```js
  if (newCat === "admin") { r.show_chantier = false; r.show_atelier = false; }
```

- [ ] **Step 6: Syntax check**

Run:
```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK` (adjust the end line if it shifted).

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat(taches): ajoute la categorie ressource 'admin' (non imputable au planning)"
```

---

### Task 2: Add the `TACHES` data array and Firebase sync wiring

**Files:**
- Modify: `index.html` (`syncToFirebase` ~765–783; `loadFromFirebase` ~785–805; `initDataSync` ~809–827; data section to declare the global)

- [ ] **Step 1: Declare the `TACHES` global**

In the data section, next to the other `let CHANTIERS = [...]` / `let RESSOURCES = [...]` declarations (after `RESSOURCES` is fine), add:
```js
let TACHES = []; // TO DO LIST : taches par chantier, synchro Firebase (cle "taches")
```

- [ ] **Step 2: Add `taches` to the sync payload**

In `syncToFirebase()`, inside the `payload` object, add a line after `actions: ACTIONS,`:
```js
    taches: TACHES,
```

- [ ] **Step 3: Load `taches` from Firebase**

In `loadFromFirebase(snap)`, after the line `if (data.actions) ACTIONS = data.actions; else ACTIONS = [];` add:
```js
  if (data.taches) TACHES = data.taches; else TACHES = [];
```

- [ ] **Step 4: Add `taches` to the empty-DB defaults**

In `initDataSync()`, inside the `DB_REF.set({ ... })` default block, add after `actions: ACTIONS,`:
```js
        taches: TACHES,
```

- [ ] **Step 5: Syntax check**

```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK`.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat(taches): cable le tableau TACHES dans la synchro Firebase"
```

---

### Task 3: Add task/admin helper functions

**Files:**
- Modify: `index.html` (helpers area, near `ressourceById` ~1227 / `chantierById` ~1228)

- [ ] **Step 1: Add the helpers**

After `function chantierById(id) { ... }`, add:
```js
// === TO DO LIST helpers ===
const PRIORITES = {
  faible:   { label: "Faible",   color: "#22c55e" }, // vert
  normale:  { label: "Normale",  color: "#eab308" }, // jaune
  elevee:   { label: "Élevée",   color: "#f97316" }, // orange
  critique: { label: "Critique", color: "#ef4444" }, // rouge
};
function adminInitials(nom) {
  return String(nom || "").trim().split(/\s+/).map(w => w[0] || "").join("").toUpperCase();
}
function admins() { return RESSOURCES.filter(r => r.cat === "admin" && r.visible !== false); }
function adminById(id) { return RESSOURCES.find(r => r.id === id && r.cat === "admin"); }
function adminByInitials(init) {
  const target = String(init || "").trim().toUpperCase();
  return admins().find(a => adminInitials(a.nom) === target) || null;
}
function _taskNextId() {
  return (TACHES.length ? Math.max(...TACHES.map(t => Number(t.id) || 0)) : 0) + 1;
}
function tacheById(id) { return TACHES.find(t => t.id === id); }
```

- [ ] **Step 2: Syntax check**

```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK`.

- [ ] **Step 3: Sanity-check the initials logic in isolation**

Run:
```bash
node -e 'const f=n=>String(n||"").trim().split(/\s+/).map(w=>w[0]||"").join("").toUpperCase(); console.log(f("Julie Noville"),f("Kévin Bernard"),f("François Fidale"));'
```
Expected: `JN KB FF`.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "feat(taches): helpers initiales admin, priorites, ids taches"
```

---

### Task 4: CSS for the TO DO LIST tab button and table

**Files:**
- Modify: `index.html` (CSS block, after the `#btn-view-ressources.active` rule ~122)

- [ ] **Step 1: Add the styles**

After `#btn-view-ressources.active { background: #10b981; }` add:
```css
  /* TO DO LIST : bouton decale + plus gros pour le differencier des vues planning */
  .view-bubble.todo-tab { margin-left: 28px; padding: 16px 30px; min-width: 140px; border: 2px solid #6366f1; }
  .view-bubble.todo-tab .v-icon { font-size: 34px; }
  .view-bubble.todo-tab .v-label { font-size: 15px; }
  #btn-view-taches.active { background: #6366f1; } /* indigo */
  /* Table TO DO LIST */
  .todo-wrap { padding: 0 24px 40px; }
  .todo-group-title { font-size: 13px; font-weight: 800; color: #334155; text-transform: uppercase; margin: 18px 0 6px; }
  table.todo-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  table.todo-table th { text-align: left; font-size: 10px; font-weight: 700; color: #64748b; text-transform: uppercase; padding: 4px 8px; border-bottom: 1px solid #e2e8f0; }
  table.todo-table td { padding: 6px 8px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
  table.todo-table tr.done td { opacity: 0.5; text-decoration: line-through; }
  .prio-dot { display: inline-block; width: 12px; height: 12px; border-radius: 50%; }
  .qui-pill { display: inline-block; background: #e0e7ff; color: #3730a3; font-weight: 700; font-size: 11px; border-radius: 8px; padding: 1px 6px; margin-right: 3px; }
  .todo-inp { width: 100%; border: 1px solid #cbd5e1; border-radius: 4px; padding: 2px 6px; font-size: 13px; }
  .todo-add-btn { font-size: 12px; color: #6366f1; border: 1px dashed #c7d2fe; border-radius: 6px; padding: 3px 10px; margin-top: 4px; cursor: pointer; background: #fff; }
  .todo-del { color: #ef4444; cursor: pointer; font-weight: 700; }
  .todo-filters { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; font-size: 12px; }
```

- [ ] **Step 2: Verify (visual, deferred)** — CSS has no JS to syntax-check; visual verification happens in Task 7. Mark this step done after the edit.

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "style(taches): styles bouton onglet TO DO LIST + table taches"
```

---

### Task 5: Add the tab button and wire the view routing

**Files:**
- Modify: `index.html` (button HTML ~447–450; `_setWeeksForView` ~2281–2289; `setView` ~2290–2299; `rerender` ~2320–2328; click bindings ~2370–2373)

- [ ] **Step 1: Add the button**

After the `#btn-view-ressources` button block (the `</button>` at ~450, still inside the `<div class="flex-1 flex items-center justify-center gap-4 flex-wrap py-2">`), add:
```html
          <button id="btn-view-taches" class="view-bubble todo-tab">
            <span class="v-icon">📋</span>
            <span class="v-label">TO DO LIST</span>
          </button>
```

- [ ] **Step 2: Give the view a fixed week count (no calendar grid)**

In `_setWeeksForView(v)`, change:
```js
  else newWeeks = v === "atelier" ? 2 : 4;
```
to:
```js
  else if (v === "taches") newWeeks = WEEKS; // pas de grille calendrier dans la TO DO LIST
  else newWeeks = v === "atelier" ? 2 : 4;
```

- [ ] **Step 3: Toggle the active class in `setView`**

In `setView(v)`, after the existing `btnAtelier` toggle block, add:
```js
  const btnTaches = document.getElementById("btn-view-taches");
  if (btnTaches) btnTaches.classList.toggle("active", v === "taches");
```

- [ ] **Step 4: Route `rerender` to the new view**

In `rerender()`, change:
```js
  if (VIEW === "ouvrier") renderViewOuvrier();
  else if (VIEW === "atelier") renderViewAtelier();
  else if (VIEW === "chantier") renderViewChantier();
  else renderViewRessources();
```
to:
```js
  if (VIEW === "taches") { renderViewTaches(); renderStats(); return; }
  if (VIEW === "ouvrier") renderViewOuvrier();
  else if (VIEW === "atelier") renderViewAtelier();
  else if (VIEW === "chantier") renderViewChantier();
  else renderViewRessources();
```
(The early `return` skips `attachDragHandlers()` — the TO DO LIST has no drag/drop. `renderStats()` is kept so the footer stats stay consistent.)

- [ ] **Step 5: Bind the click**

After:
```js
document.getElementById("btn-view-ressources").addEventListener("click", () => setView("ressources"));
```
add:
```js
document.getElementById("btn-view-taches").addEventListener("click", () => setView("taches"));
```

- [ ] **Step 6: Add a temporary stub so syntax/routing is testable now**

`renderViewTaches` is implemented in Task 6. To keep this commit runnable, add a stub near the other render functions (it will be replaced in Task 6):
```js
function renderViewTaches() {
  document.getElementById("week-row").innerHTML = "";
  document.getElementById("day-row").innerHTML = "";
  document.getElementById("coverage-row").innerHTML = "";
  document.getElementById("context-bar").innerHTML = "";
  document.getElementById("planning-body").innerHTML =
    '<tr><td class="p-6 text-slate-400">TO DO LIST — en construction</td></tr>';
}
```

- [ ] **Step 7: Syntax check**

```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK` (the script end line will have grown — adjust the upper bound, e.g. `grep -n '</script>' index.html`).

- [ ] **Step 8: Commit**

```bash
git add index.html
git commit -m "feat(taches): ajoute le bouton onglet TO DO LIST + routage de vue (stub)"
```

---

### Task 6: Implement `renderViewTaches` with grouping, filters, and CRUD

**Files:**
- Modify: `index.html` (replace the Task 5 stub `renderViewTaches`; add filter state + CRUD handlers nearby)

- [ ] **Step 1: Add filter state**

Near the other view-state globals (next to `let VIEW = ...` ~1092), add:
```js
let TACHE_FILTER_QUI = "all";    // "all" | adminId
let TACHE_FILTER_PRIO = "all";   // "all" | clé de PRIORITES
let TACHE_HIDE_DONE = false;     // masquer les taches faites
```

- [ ] **Step 2: Add the CRUD handlers**

Add these functions near `renderViewTaches` (all user mutations call `mutateAndSync()`):
```js
function addTache(c) {
  const cVal = (c === "null" || c === null) ? null : Number(c);
  TACHES.push({ id: _taskNextId(), c: cVal, todo: "", qui: [], priorite: "", dateButoir: "", remarque: "", fait: false });
  mutateAndSync();
}
function updateTacheField(id, field, value) {
  const t = tacheById(id); if (!t) return;
  if (field === "fait") t.fait = !!value;
  else if (field === "priorite") t.priorite = value;
  else if (field === "dateButoir") t.dateButoir = value;
  else if (field === "todo") t.todo = value;
  else if (field === "remarque") t.remarque = value;
  mutateAndSync();
}
function toggleTacheQui(id, adminId) {
  const t = tacheById(id); if (!t) return;
  adminId = Number(adminId);
  const i = t.qui.indexOf(adminId);
  if (i >= 0) t.qui.splice(i, 1); else t.qui.push(adminId);
  mutateAndSync();
}
function deleteTache(id) {
  if (!confirm("Supprimer cette tâche ?")) return;
  TACHES = TACHES.filter(t => t.id !== id);
  mutateAndSync();
}
function setTacheFilterQui(v) { TACHE_FILTER_QUI = v; rerender(); }
function setTacheFilterPrio(v) { TACHE_FILTER_PRIO = v; rerender(); }
function toggleTacheHideDone() { TACHE_HIDE_DONE = !TACHE_HIDE_DONE; rerender(); }
```
(Filter setters call `rerender()` — they change display only, never the data, so they must NOT sync.)

- [ ] **Step 3: Replace the stub `renderViewTaches` with the full implementation**

```js
function renderViewTaches() {
  // Pas de grille calendrier : on vide les en-tetes planning
  document.getElementById("week-row").innerHTML = "";
  document.getElementById("day-row").innerHTML = "";
  document.getElementById("coverage-row").innerHTML = "";

  // --- Barre de filtres ---
  const adminOpts = ['<option value="all">Tous</option>']
    .concat(admins().sort(_byOrder).map(a =>
      `<option value="${a.id}" ${TACHE_FILTER_QUI == a.id ? "selected" : ""}>${esc(adminInitials(a.nom))} — ${esc(a.nom)}</option>`))
    .join("");
  const prioOpts = ['<option value="all">Toutes</option>']
    .concat(Object.entries(PRIORITES).map(([k, p]) =>
      `<option value="${k}" ${TACHE_FILTER_PRIO === k ? "selected" : ""}>${esc(p.label)}</option>`))
    .join("");
  document.getElementById("context-bar").innerHTML = `
    <div class="todo-filters">
      <span class="text-xs font-semibold text-slate-500">FILTRES :</span>
      <label>QUI <select class="todo-inp" style="width:auto" onchange="setTacheFilterQui(this.value)">${adminOpts}</select></label>
      <label>Priorité <select class="todo-inp" style="width:auto" onchange="setTacheFilterPrio(this.value)">${prioOpts}</select></label>
      <label><input type="checkbox" ${TACHE_HIDE_DONE ? "checked" : ""} onchange="toggleTacheHideDone()"> Masquer les faites</label>
    </div>`;

  // --- Filtrage ---
  const visible = TACHES.filter(t => {
    if (TACHE_HIDE_DONE && t.fait) return false;
    if (TACHE_FILTER_QUI !== "all" && !(t.qui || []).includes(Number(TACHE_FILTER_QUI))) return false;
    if (TACHE_FILTER_PRIO !== "all" && t.priorite !== TACHE_FILTER_PRIO) return false;
    return true;
  });

  // --- Groupement par chantier (ordre des chantiers), puis Général (c===null) ---
  const groupKeys = [];
  CHANTIERS.forEach(c => { if (c.id !== 0) groupKeys.push(c.id); });
  // chantiers cites dans les taches mais absents de CHANTIERS (ex: 418/419/420)
  visible.forEach(t => { if (t.c !== null && !groupKeys.includes(t.c)) groupKeys.push(t.c); });
  groupKeys.push(null); // Général en dernier

  const groupLabel = (key) => {
    if (key === null) return "Général / sans chantier";
    const ch = chantierById(key);
    return ch ? (key + " - " + ch.nom) : (key + " - (chantier non listé)");
  };

  // --- Rendu ---
  const adminList = admins().sort(_byOrder);
  let html = '<tr><td><div class="todo-wrap">';
  groupKeys.forEach(key => {
    const rows = visible.filter(t => t.c === key);
    const all = TACHES.filter(t => t.c === key);
    if (!rows.length && !all.length) return; // groupe totalement vide : on saute
    html += `<div class="todo-group-title">${esc(groupLabel(key))}</div>`;
    html += `<table class="todo-table"><thead><tr>
      <th style="width:32%">À faire</th><th style="width:10%">QUI</th><th style="width:10%">Priorité</th>
      <th style="width:12%">Date butoir</th><th style="width:26%">Remarque</th><th style="width:5%">Fait</th><th style="width:5%"></th>
    </tr></thead><tbody>`;
    rows.forEach(t => {
      const quiHtml = adminList.map(a => {
        const on = (t.qui || []).includes(a.id);
        return `<span class="qui-pill" style="cursor:pointer;${on ? "" : "opacity:.3"}" onclick="toggleTacheQui(${t.id},${a.id})" title="${esc(a.nom)}">${esc(adminInitials(a.nom))}</span>`;
      }).join("");
      const prioSel = ['<option value="">—</option>'].concat(Object.entries(PRIORITES).map(([k, p]) =>
        `<option value="${k}" ${t.priorite === k ? "selected" : ""}>${esc(p.label)}</option>`)).join("");
      const dot = t.priorite && PRIORITES[t.priorite]
        ? `<span class="prio-dot" style="background:${PRIORITES[t.priorite].color}"></span> ` : "";
      html += `<tr class="${t.fait ? "done" : ""}">
        <td><input class="todo-inp" value="${esc(t.todo)}" onchange="updateTacheField(${t.id},'todo',this.value)"></td>
        <td>${quiHtml}</td>
        <td>${dot}<select class="todo-inp" style="width:auto" onchange="updateTacheField(${t.id},'priorite',this.value)">${prioSel}</select></td>
        <td><input type="date" class="todo-inp" value="${esc(t.dateButoir)}" onchange="updateTacheField(${t.id},'dateButoir',this.value)"></td>
        <td><input class="todo-inp" value="${esc(t.remarque)}" onchange="updateTacheField(${t.id},'remarque',this.value)"></td>
        <td style="text-align:center"><input type="checkbox" ${t.fait ? "checked" : ""} onchange="updateTacheField(${t.id},'fait',this.checked)"></td>
        <td style="text-align:center"><span class="todo-del" onclick="deleteTache(${t.id})" title="Supprimer">✕</span></td>
      </tr>`;
    });
    html += `</tbody></table>`;
    const cArg = key === null ? "null" : key;
    html += `<button class="todo-add-btn" onclick="addTache(${cArg})">+ Ajouter une tâche</button>`;
  });
  html += '</div></td></tr>';
  document.getElementById("planning-body").innerHTML = html;
}
```

- [ ] **Step 4: Syntax check**

```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK` (adjust the upper bound to the current `</script>` line).

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(taches): vue TO DO LIST complete (groupes, filtres, CRUD inline)"
```

---

### Task 7: Browser verification in DEV_MODE (no Firebase)

**Files:** none (verification only).

- [ ] **Step 1: Start the preview server**

Use `preview_start` (config `.claude/launch.json`, port 8765). The DEV_MODE banner should read "MODE TEST (local)" and the app should load with sample data, no login.

- [ ] **Step 2: Confirm no console errors on load**

Use `preview_console_logs`. Expected: no red errors. (A Firebase "permission"/offline notice is fine in DEV_MODE.)

- [ ] **Step 3: Open the tab and snapshot**

`preview_click` on `#btn-view-taches`, then `preview_snapshot`. Expected: the tab is visibly bigger/offset; the body shows group titles and a "+ Ajouter une tâche" button per group. (With empty sample data and no admins, groups may be empty — that's fine; the seed is Task 8.)

- [ ] **Step 4: Manually create an admin and a task to exercise CRUD**

In the preview: open "Gérer" → add a resource with category **Admin** named "Kévin Bernard". Switch back to TO DO LIST, click "+ Ajouter une tâche" under any chantier, type a description, toggle the `KB` pill, pick a priority, check "Fait". `preview_snapshot` after each to confirm the row updates and the priority dot colors correctly.

- [ ] **Step 5: Confirm admins do NOT appear in planning**

`preview_click` on `#btn-view-ouvrier`, `preview_snapshot`. Expected: "Kévin Bernard" (the admin) is absent from the planning grid.

- [ ] **Step 6: Screenshot for Frans**

`preview_screenshot` of the TO DO LIST view with the test task. Share it.

- [ ] **Step 7: Commit** — nothing to commit (verification only). If any bug was found, fix it in `index.html`, re-run Step 1–6, then commit the fix with a descriptive message.

---

### Task 8: One-time seed of the 77 Excel tasks

**Files:**
- Modify: `index.html` (add `TACHES_SEED` const + `seedTachesIfNeeded()` near the data section; call it from `initDataSync`)

- [ ] **Step 1: Add the seed data and seeding function**

Add near the `TACHES` declaration:
```js
// Mapping canonique des admins (initiales -> nom) pour resoudre le seed QUI.
const ADMIN_SEED_MAP = { JN: "Julie Noville", KB: "Kévin Bernard", OG: "Olivier Gillet", FF: "François Fidale", LD: "Laurent Delehouse" };
// 77 taches reprises de l'Excel TO DO LIST (qui = initiales, resolues en ids au seed).
const TACHES_SEED = [
  { c:385, todo:"Commander stacbond", qui:["KB"], priorite:"", dateButoir:"2026-04-17", remarque:"Dimension plafond stacbond Anodic Light.8pc de 1500/5000 : livraison 27/05", fait:true },
  { c:385, todo:"FACTURER 200€ SUPPLEMENT MB TRANSPORT ISOLANTS", qui:["KB","FF"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:385, todo:"Vérifier M2 magnélis par rapport à commande -> rampe en plus ?", qui:["OG","FF"], priorite:"normale", dateButoir:"", remarque:"Vérifier CSC et métré - Pas le même travail de faire une rampe ou des tôles planes", fait:false },
  { c:385, todo:"Réparation autour de la passerelle à chiffrer", qui:["KB"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:385, todo:"Réparation de deux tôles abîmées par un sous-traitant à chiffrer", qui:["KB"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:396, todo:"Lever les points de RP", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"Retourner TD arrière + rejet d'eau sur rive pignon", fait:false },
  { c:399, todo:"Pliage des tôles en magnélis dessus escalier", qui:["KB"], priorite:"critique", dateButoir:"", remarque:"", fait:false },
  { c:399, todo:"Fixer date montage filets garde-corps", qui:["KB","LD"], priorite:"critique", dateButoir:"", remarque:"", fait:false },
  { c:399, todo:"Pose escalier et passerelles", qui:[], priorite:"", dateButoir:"", remarque:"Pose 01/06", fait:true },
  { c:399, todo:"Bardage zone PAC", qui:["KB","LD","OG"], priorite:"elevee", dateButoir:"", remarque:"Tôles commandées (attente date livraison) - Pose 08/06", fait:false },
  { c:399, todo:"Pose tôle alu anodisé sur pignon", qui:[], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:400, todo:"Toiture posée - Lever les remarques", qui:["KB","OG"], priorite:"elevee", dateButoir:"", remarque:"Aller mesurer les finitions - En attente retour DE GRAEVE pour intervenir", fait:false },
  { c:401, todo:"Livraison bac de toiture", qui:[], priorite:"", dateButoir:"", remarque:"46177", fait:true },
  { c:401, todo:"Partie 3 : Dessiner auvent + commande matériaux", qui:["LD"], priorite:"critique", dateButoir:"", remarque:"Tout est commandé - plat + poutres (Liv:22/05) + bac de toiture (Liv:26/05) - plan assemblage ok - plan montage ok", fait:true },
  { c:401, todo:"Retirer les gouttières du décompte (Posées par couvreur)", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:401, todo:"offre de prix Isolation structure", qui:["LD"], priorite:"", dateButoir:"2026-04-21", remarque:"Prix refusé - en attente retour EG", fait:false },
  { c:401, todo:"Partie 2 : Finitions à commander", qui:["KB"], priorite:"critique", dateButoir:"", remarque:"livraison 28/05/2026", fait:true },
  { c:401, todo:"Facturer les tôles de bardage abîmées à PICARD", qui:["KB"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:404, todo:"Suivi permis", qui:["OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:404, todo:"Dessiner + commande matériaux", qui:["LD"], priorite:"faible", dateButoir:"", remarque:"", fait:false },
  { c:404, todo:"Relever bâtiment", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"Date a définir", fait:false },
  { c:405, todo:"Bat arr. : Commander tôle bardage + tôles de finition + support + fixations", qui:["LD","OG"], priorite:"elevee", dateButoir:"", remarque:"Tôle validée par client : JI 25-115-1035  RAL 7016", fait:false },
  { c:405, todo:"Bat av. : Relever façade quand isolant posé", qui:[], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:405, todo:"Isolant livré à l'atelier 13/04 avec fixations", qui:["OG"], priorite:"", dateButoir:"", remarque:"Reçu isolant, fixations et tape", fait:true },
  { c:405, todo:"Trespa de stock chez BIEMAR", qui:[], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:405, todo:"Planning", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"Démarrage DIAGON 01/06/26", fait:true },
  { c:405, todo:"Type de nacelle à confirmer ultérieurement avec L. BOVEROUX", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:405, todo:"Prévoir renfort vertical pour tuyaux de descente", qui:["KB","LD","OG"], priorite:"normale", dateButoir:"", remarque:"", fait:false },
  { c:405, todo:"Coactivité techniques spéciales", qui:[], priorite:"", dateButoir:"", remarque:"Besoin de 2 jours de démontage avant nous et 3 jours de remontage après nous", fait:false },
  { c:406, todo:"Pose corniches en sous-traitance", qui:["KB","OG"], priorite:"critique", dateButoir:"", remarque:"Calculer en fonction de notre prix - Prestations Dominique à 60€/h", fait:false },
  { c:406, todo:"Planning pose gouttières et TD", qui:[], priorite:"", dateButoir:"", remarque:"05/06 + 08/06 + 09/06", fait:false },
  { c:406, todo:"Toles de finition", qui:[], priorite:"", dateButoir:"", remarque:"livraison: 26/05/26", fait:false },
  { c:406, todo:"Commander 2 tôles de zinc + 2 m de TD zinc diam 160 pour naissances", qui:["KB"], priorite:"critique", dateButoir:"", remarque:"", fait:false },
  { c:407, todo:"Livraison STACBOND le 27/04 chez CAREMISO", qui:["KB"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:407, todo:"Mesurer façades pour affiner calepinage vertical après pose châssis", qui:["KB","OG"], priorite:"critique", dateButoir:"", remarque:"", fait:true },
  { c:407, todo:"Planning intervention DIAGON", qui:[], priorite:"", dateButoir:"", remarque:"démarrage 20/05", fait:true },
  { c:407, todo:"Commander fixations,...", qui:["LD"], priorite:"elevee", dateButoir:"", remarque:"ok- 900 pces fm x3 à l'atlier", fait:true },
  { c:407, todo:"Vérifier que tous les accessoires soient bien commandés", qui:["LD"], priorite:"critique", dateButoir:"2026-03-27", remarque:"Commander grilles et oméga", fait:true },
  { c:407, todo:"Echantillon STACBOND gris ardoise à fournir", qui:["KB"], priorite:"", dateButoir:"", remarque:"Transmis sur chantier le 08/05/26", fait:true },
  { c:407, todo:"Commander les toles sèche.", qui:["KB","LD"], priorite:"critique", dateButoir:"2026-04-14", remarque:"échantillon commandé 08/04/26", fait:false },
  { c:408, todo:"Commander isolant, fixations,... pour Stacbond et Renson", qui:["LD"], priorite:"", dateButoir:"2026-02-25", remarque:"ok isolant +fixation PIR + Pare-pluie + fixation STACBOND - Rappeler à Alex de livrer nos fixations", fait:false },
  { c:408, todo:"Commander RENSON", qui:["KB","OG"], priorite:"", dateButoir:"2026-06-08", remarque:"", fait:false },
  { c:410, todo:"Planning", qui:["KB"], priorite:"", dateButoir:"", remarque:"Fin mai", fait:false },
  { c:410, todo:"Commander tôles", qui:["KB","LD"], priorite:"", dateButoir:"", remarque:"Livraison 27/05", fait:false },
  { c:412, todo:"Planning", qui:[], priorite:"", dateButoir:"", remarque:"Mi-juin", fait:false },
  { c:412, todo:"Dessiner cadre metallique  ( dimension a adapter apres mesurage)", qui:["LD"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:412, todo:"Mesurage pour fabrication", qui:["KB"], priorite:"", dateButoir:"", remarque:"Mesurage 19/05", fait:false },
  { c:413, todo:"Intervention DIAGON vers juin/juillet", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:413, todo:"Calepinnage Trespa", qui:["LD"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:414, todo:"Poutre treilli à dessiner", qui:["LD"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:414, todo:"Intervention DIAGON mi-juin", qui:["KB","OG"], priorite:"elevee", dateButoir:"", remarque:"Commander panneaux", fait:false },
  { c:414, todo:"Analyser détail bandeaux façades", qui:["OG"], priorite:"", dateButoir:"", remarque:"Attente confirmation PICARD sur position buses chauffage", fait:false },
  { c:414, todo:"Descentes PE extérieures - Voir pour pose (jonctions soudées)", qui:["OG"], priorite:"", dateButoir:"", remarque:"analyser jonction avaloir toiture vers PE", fait:false },
  { c:414, todo:"Quid passer les habillage en tôle vers STACBOND", qui:["OG","LD"], priorite:"", dateButoir:"", remarque:"Variante STACBOND et tôles post-laquées à soumettre à PICARD", fait:false },
  { c:414, todo:"Plan de calepinage STACBOND et tôle", qui:["OG"], priorite:"elevee", dateButoir:"", remarque:"", fait:false },
  { c:415, todo:"Aller mesurer caillebotti + commande", qui:["KB"], priorite:"", dateButoir:"", remarque:"Mesurage 10/04", fait:false },
  { c:415, todo:"Réclamer BDC à Nicolas Lelotte", qui:["OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:415, todo:"Remettre prix pour habillages - voir mail", qui:["KB","OG"], priorite:"", dateButoir:"", remarque:"Mesurage 10/04", fait:false },
  { c:417, todo:"Panneaux sandwich RAL 9007", qui:["OG","KB"], priorite:"", dateButoir:"", remarque:"Délai au 24/04 : prod semaine 22 et fourniture semaine 23", fait:false },
  { c:417, todo:"Livraison Joris", qui:[], priorite:"", dateButoir:"", remarque:"Toles planes ( 26-05) - Panneaux sandwich ( 29-06)", fait:false },
  { c:417, todo:"Commander isolant et panneaux sandwich", qui:["KB","OG"], priorite:"critique", dateButoir:"", remarque:"", fait:true },
  { c:418, todo:"Envoyer FT", qui:["OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:418, todo:"Passer commande pour PIR", qui:["OG"], priorite:"", dateButoir:"", remarque:"Livraison début juillet sous réserve qu'on puisse démarrer.", fait:false },
  { c:419, todo:"Envoyer FT", qui:["OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:419, todo:"Envoyer plans", qui:["LD","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:null, todo:"1000mc de CLS   plus de 2000mc de voliges", qui:["LD","OG"], priorite:"", dateButoir:"2026-04-08", remarque:"", fait:true },
  { c:null, todo:"Placement accessoires Nico Lelotte", qui:["KB"], priorite:"", dateButoir:"2026-03-04", remarque:"", fait:true },
  { c:null, todo:"Prévoir le démontage de la barrière au dépot car montage de la nouvelle en semaine 14", qui:["KB","FF"], priorite:"", dateButoir:"2026-03-27", remarque:"fondation 10/04. et pose barrière le 15/04", fait:true },
  { c:419, todo:"Passer commande pour PIR", qui:["OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:420, todo:"Envoyer Fiches technique", qui:["OG"], priorite:"elevee", dateButoir:"", remarque:"FT PS vulcasteel + ardoise envoyé - reste les autres", fait:false },
  { c:null, todo:"Relancer Philippe Haggelstein pour dossier SERAING", qui:["OG","FF"], priorite:"", dateButoir:"", remarque:"fait le 01/04  on va le recevoir", fait:false },
  { c:null, todo:"Boite a lettre michmich", qui:["KB"], priorite:"elevee", dateButoir:"", remarque:"", fait:false },
  { c:null, todo:"Mail urgent chez Joriside pour gestion problème commande", qui:["KB","OG","FF"], priorite:"", dateButoir:"", remarque:"Joriside propose un geste commercial de 50% sur les panneaux recommandés.  UPDATE 07/04 NC pas encore recue", fait:true },
  { c:null, todo:"Pliage des finitions", qui:["KB"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:null, todo:"Offre de prix selon mesurage", qui:["KB","LD","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:null, todo:"MATOUL-GOORE", qui:["LD","OG"], priorite:"", dateButoir:"", remarque:"", fait:false },
  { c:null, todo:"MY HOTEL MALMEDY", qui:["KB","OG"], priorite:"", dateButoir:"2026-05-15", remarque:"replacer un seuil et refixer des visses.", fait:false },
];

// Cree les admins manquants (idempotent) puis renvoie une map initiales -> id.
function ensureSeedAdmins() {
  Object.entries(ADMIN_SEED_MAP).forEach(([init, nom]) => {
    if (!adminByInitials(init)) {
      const id = Math.max(99, ...RESSOURCES.map(r => Number(r.id) || 0)) + 1;
      RESSOURCES.push({ id, nom, cat: "admin", visible: true, show_chantier: false, show_atelier: false, order: id * 10 });
    }
  });
  const map = {};
  admins().forEach(a => { map[adminInitials(a.nom)] = a.id; });
  return map;
}

// Importe les 77 taches une seule fois. alreadyHadTaches = true si la cle "taches"
// existait deja dans Firebase (=> ne pas re-seeder). Renvoie true si un seed a eu lieu.
function seedTachesIfNeeded(alreadyHadTaches) {
  if (alreadyHadTaches) return false;      // deja seede une fois
  if (TACHES.length > 0) return false;      // securite
  const initMap = ensureSeedAdmins();
  TACHES = TACHES_SEED.map((s, i) => ({
    id: i + 1,
    c: s.c,
    todo: s.todo,
    qui: (s.qui || []).map(init => initMap[init]).filter(id => id != null),
    priorite: s.priorite,
    dateButoir: s.dateButoir,
    remarque: s.remarque,
    fait: s.fait,
  }));
  return true;
}
```

- [ ] **Step 2: Call the seed from `initDataSync`**

In `initDataSync()`, the `DB_REF.once("value", snap => { ... })` callback currently handles both the data-present and empty-DB branches, then sets `_firebaseReady = true`. Capture whether `taches` already existed, and seed after `_firebaseReady = true`. Change the start of the callback:
```js
  DB_REF.once("value", snap => {
    const existing = snap.val();
    const hadTaches = !!(existing && existing.taches);
    if (existing) {
      loadFromFirebase(snap); // charge les données existantes
    } else {
```
(i.e. replace `if (snap.val()) {` with the three lines above, keeping the rest of the `if/else` intact.)

Then, immediately after `_firebaseReady = true;` and the existing `_dedupChanged` block, add:
```js
    // Seed unique des taches (premier deploiement : la cle "taches" n'existe pas encore)
    if (seedTachesIfNeeded(hadTaches)) {
      console.log("[DIAGON] Seed TO DO LIST : " + TACHES.length + " taches importees -> sauvegarde Firebase");
      rerender();
      syncToFirebase();
    }
```

- [ ] **Step 3: Syntax check**

```bash
sed -n '608,2379p' index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK` (use the current `</script>` line as the upper bound).

- [ ] **Step 4: Verify the seed shape with Node (offline check)**

Extract and test the seed logic without a browser:
```bash
node -e '
const ADMIN_SEED_MAP={JN:"Julie Noville",KB:"Kévin Bernard",OG:"Olivier Gillet",FF:"François Fidale",LD:"Laurent Delehouse"};
const initials=n=>String(n||"").trim().split(/\s+/).map(w=>w[0]||"").join("").toUpperCase();
const map={}; Object.entries(ADMIN_SEED_MAP).forEach(([i,n],k)=>map[initials(n)]=100+k);
const SEED=require("./docs/superpowers/taches_seed.json");
const out=SEED.map((s,i)=>({id:i+1,c:s.c,qui:(s.qui||[]).map(x=>map[x]).filter(x=>x!=null)}));
console.log("count",out.length);
console.log("unresolved QUI tokens:", [...new Set(SEED.flatMap(s=>s.qui||[]))].filter(t=>map[t]==null));
console.log("general (c=null):", out.filter(t=>t.c===null).length);
'
```
Expected: `count 77`, `unresolved QUI tokens: []`, `general (c=null): 10`.

- [ ] **Step 5: Browser verify in DEV_MODE**

Reload the preview. Open TO DO LIST. Expected: 5 admins auto-created (visible in "Gérer" as cat Admin, absent from planning), tasks grouped under their chantiers with chantiers 418/419/420 shown as "(chantier non listé)", QUI pills lit for assigned admins, priority dots colored, done tasks struck-through. Test the "Masquer les faites" filter and the QUI/priorité filters. `preview_screenshot` and share with Frans.

- [ ] **Step 6: Commit**

```bash
git add index.html
git commit -m "feat(taches): seed unique des 77 taches Excel + auto-creation des 5 admins"
```

---

### Task 9: Clean up scratch files and final review

**Files:**
- Delete: `docs/superpowers/taches_seed.json`, `docs/superpowers/taches_seed_js.txt` (scratch artifacts from data extraction; the seed now lives inline in `index.html`)

- [ ] **Step 1: Remove scratch files**

```bash
git rm --ignore-unmatch docs/superpowers/taches_seed.json docs/superpowers/taches_seed_js.txt 2>/dev/null; rm -f docs/superpowers/taches_seed.json docs/superpowers/taches_seed_js.txt
```

- [ ] **Step 2: Full syntax check**

```bash
END=$(grep -n '</script>' index.html | tail -1 | cut -d: -f1); sed -n "608,$((END-1))p" index.html > /tmp/diagon_check.js && node --check /tmp/diagon_check.js && echo "SYNTAX OK" && rm /tmp/diagon_check.js
```
Expected: `SYNTAX OK`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore(taches): supprime les fichiers de travail du seed"
```

- [ ] **Step 4: Deployment gate (do NOT push without Frans's OK)**

Pushing `main` auto-deploys to production and runs the one-time seed against the live Firebase DB. Before pushing:
- Confirm with Frans that he's ready for the 77 tasks + 5 admins to appear live.
- Confirm whether he wants to create/rename the 5 admins himself first (if he already created some with the exact names in `ADMIN_SEED_MAP`, the seed reuses them; otherwise it creates them and he can rename later).
- Only then: `git push origin main`. Watch the deploy (1–2 min) and verify on https://ffidale-ship-it.github.io/planning-diagon/ that the seed ran exactly once (reload twice — task count must stay 77, not double).

---

## Self-Review

**Spec coverage:**
- §1 Onglet/bouton → Task 4 (CSS) + Task 5 (button, offset+bigger, id `btn-view-taches`, VIEW `taches`, `renderViewTaches`). ✓
- §2 Catégorie Admin → Task 1 (select, migrate, addOuvrier, setOuvrierCat; admins invisible in planning). ✓ Frans's 5 admins auto-ensured in Task 8.
- §3 Modèle de données → Task 2 (`TACHES`) + Task 6 (fields) + Task 3 (initials derived, no stored field). ✓
- §4 Affichage (groupé par chantier + Général, colonnes, pastilles couleur, faites grisées) → Task 4 (CSS) + Task 6 (render). ✓
- §5 Édition CRUD via mutateAndSync → Task 6 (add/update/toggleQui/delete). ✓
- §6 Filtres (QUI, priorité, masquer faites) → Task 6 (filter state + bar + `rerender`-only setters). ✓
- §7 Reprise des données (77 tâches, mapping chantier/QUI/priorité/date/fait, NOTIFIER ignorée) → Task 8. ✓
- §8 Synchro Firebase (`taches` dans sync/load/init) → Task 2. ✓
- Open point "ordre seed vs admins" → resolved by auto-ensuring admins in Task 8. ✓
- Open point "édition inline vs formulaire" → resolved: inline inputs/selects per cell (Task 6). ✓

**Placeholder scan:** No TBD/TODO/"handle errors" placeholders; every code step has complete code. ✓

**Type consistency:** `TACHE` fields (`id,c,todo,qui,priorite,dateButoir,remarque,fait`) are identical across Task 2/6/8. Function names consistent: `renderViewTaches`, `addTache`, `updateTacheField`, `toggleTacheQui`, `deleteTache`, `tacheById`, `_taskNextId`, `adminInitials`, `adminByInitials`, `admins`, `seedTachesIfNeeded`, `ensureSeedAdmins`. Filter globals `TACHE_FILTER_QUI/PRIO`, `TACHE_HIDE_DONE` used consistently. `PRIORITES` keys (`faible/normale/elevee/critique`) match seed priorities. ✓

**Note on line numbers:** all line references are from the pre-change file and will drift as code is added; locate by the quoted anchor text, not the number.
