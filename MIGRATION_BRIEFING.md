# Briefing migration — Planning DIAGON → Claude Code

## Ce que tu as entre les mains

```
planning-diagon/
├── CLAUDE.md              ← Contexte projet (lu automatiquement par Claude Code)
├── index.html             ← Maquette live (= GitHub Pages)
├── .gitignore
├── src/
│   ├── planning_maquette_v4.html   ← Version de travail (identique à index.html)
│   └── planning_maquette_v3.html   ← Version précédente (référence)
├── docs/
│   ├── Cahier_des_charges_Planning_v0.1.md
│   └── Schema_base_de_donnees_v0.1.md
├── assets/
│   └── DIAGON_logo_baseline_CMJN_2026.png
└── db/
    └── 001_init_schema_planning.sql   ← Premier script migration PostgreSQL
```

## Ce qui fonctionne aujourd'hui

La maquette est **en production** sur GitHub Pages, utilisée par 3 personnes (Frans, Kévin, Olivier). Elle tourne sur Firebase Realtime DB en sync temps réel.

**Features opérationnelles :**
- 3 vues : Par ouvrier, Par chantier, Ressources (équipements + livraisons + besoins)
- Drag & drop complet entre cellules et pool
- CRUD ouvriers, chantiers, équipements via modal "Gérer"
- Duplication jour suivant (+1j) et jusqu'à vendredi (→ven)
- Clear par jour et par semaine
- Barre de couverture avec tooltip ouvriers non affectés
- Sync Firebase temps réel (pattern rerender/mutateAndSync)
- Indicateur de connexion Firebase dans la sidebar

## Ce qui reste à faire (priorité révisée 2026-04-18)

### ORDRE DE TRAVAIL DÉCIDÉ
Contrairement à une première version du doc, on **NE commence PAS par éclater le monolithe**.
Raison : refactorer la maquette en composants sans backend = travail à valeur nulle pour les 3 users en prod, et double travail quand on bascule ensuite sur l'API REST.

### Phase 1 — Backend local (en cours)
Construire le backend à côté, **sans toucher la maquette qui tourne sur Firebase**.
- Docker Compose : Postgres 16 + Next.js (TypeScript, driver `pg` natif — pas d'ORM car l'IA tapera du SQL nommé)
- Appliquer les 3 schémas : `planning`, `fiches`, `rh` (séparation RGPD)
- API REST minimale : CRUD sur chantiers, ressources, affectations, livraisons, besoins
- Script one-shot de migration Firebase → Postgres (lire le JSON Firebase, insérer en SQL)
- **La maquette continue de tourner sur Firebase pendant tout ce temps**

### Phase 2 — Basculer la maquette sur l'API REST
- Remplacer les appels Firebase par `fetch('/api/...')` dans `index.html`
- Garder la structure single-file (pas de refactor React pour l'instant)
- Sync temps réel : **polling 3s** (décision prise : pas besoin de < 1s pour du planning chantier)
- Firebase reste en backup 1-2 semaines, puis débranché

### Phase 3 — Authentification
- Login simple par token (bureau + chefs d'équipe)
- Rôles : admin / chef / lecture seule

### Phase 4 — Éclater le monolithe (OPTIONNEL, à trancher plus tard)
- À ce stade seulement, si passage nécessaire en Next.js pour la suite (mobile, check-in@work)
- Sinon, 134 KB de HTML bien organisé peut très bien vivre

### Moyen terme
- **Pilotage vocal IA** : interprétation LLM des commandes vocales → appel de stored procedures
- **Docker déployé sur NAS Synology** (dev OK en local, prod sur NAS)
- **Check-in@Work ONSS** : déclaration obligatoire BTP Belgique

### Long terme
- **Mobile responsive** pour les chefs d'équipe
- **Module RH** : pointages, heures sup (schéma `rh`, jamais exposé à l'IA)

## Décisions techniques actées
- **Migration Firebase** : on récupère les données existantes (3 users ont déjà rempli la maquette)
- **Sync** : polling 3s suffisant
- **Hébergement dev** : local sur Mac de Frans (Apple Silicon arm64) — puis NAS Synology plus tard
- **Stack backend** : Next.js 15 + TypeScript + Postgres 16 + driver `pg` natif (pas d'ORM)

## Environnement déjà en place (2026-04-18)
- Node 24.15.0 via nvm (installé dans `~/.nvm/`)
- Claude Code 2.1.114
- Docker Desktop 29.4.0 + Docker Compose 5.1.1 (installé, tourne)
- Repo cloné localement, push HTTPS fonctionnel (token à régénérer à chaque push pour l'instant — TODO : installer `gh` CLI ou configurer SSH)

## Points d'attention pour Claude Code

1. **Firebase config** : les credentials sont en dur dans index.html. Elles doivent migrer vers un `.env`
2. **Le pattern de sync** est critique : ne jamais appeler `syncToFirebase()` depuis un listener Firebase (boucle infinie). Seules les actions utilisateur passent par `mutateAndSync()`
3. **Dates** : toujours utiliser `_localISO()` (timezone Belgique UTC+1/+2), jamais `toISOString()`
4. **RGPD** : l'IA ne doit jamais accéder aux schémas `fiches` ou `rh`. Uniquement `planning` via stored procedures
5. **DIAGON** sans E — jamais "Diagone"

## Comment utiliser avec Claude Code

```bash
cd planning-diagon
claude
# Claude Code va lire CLAUDE.md automatiquement au démarrage
```

Tu peux directement demander :
- "Éclate index.html en composants React/Next.js"
- "Crée le docker-compose avec PostgreSQL 16 + Next.js"
- "Implémente l'API REST pour les affectations"
- "Ajoute l'authentification"

Le fichier CLAUDE.md donne tout le contexte nécessaire à Claude Code pour comprendre le projet.
