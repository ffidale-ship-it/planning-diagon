# DIAGON — ERP Planning Chantier

## Contexte
DIAGON (sans E) est une entreprise belge de bardage, parement de façade et structures métalliques. Ce projet est la première brique d'un ERP sur mesure : un module de planification des équipes sur chantiers.

## Utilisateur principal
Frans — dirigeant de DIAGON. Francophone. Préfère les réponses concises, directes, et aime être challengé. Pas de fluff.

## État actuel
**Maquette fonctionnelle déployée** sur GitHub Pages : https://ffidale-ship-it.github.io/planning-diagon/

- Single-file HTML/CSS/JS (`index.html` = `planning_maquette_v4.html` + auth)
- Tailwind CSS via CDN
- Firebase Realtime Database pour sync multi-utilisateurs
- **Firebase Authentication activée** (Email/Password + Google Sign-In) — 5 users : Frans, Kévin, Olivier, Laurent, Julie
- Pas de backend — tout est côté client avec Firebase

## Dernière mise à jour majeure (juin 2026) — onglet TO DO LIST
5ᵉ onglet « 📋 TO DO LIST » qui remplace l'Excel `TB COMMANDE DIAGON > TO DO LIST`.
Liste de tâches par chantier, éditable et synchronisée Firebase comme le reste.
- Bouton `#btn-view-taches` (class `view-bubble todo-tab`, plus gros, décalé à droite), `VIEW = "taches"`, `renderViewTaches()`.
- Nouvelle catégorie de ressource **`admin`** (encadrement non imputable) : `show_chantier=false` + `show_atelier=false`, **n'apparaît jamais dans les vues planning**. 5 admins : JN/KB/OG/FF/LD.
- Modèle `TACHE = { id, c (id chantier ou null=Général), todo, qui:[adminId], priorite (faible/normale/elevee/critique/""), dateButoir (ISO local), remarque, fait }`. Tableau `TACHES`, clé Firebase `taches`.
- Colonnes par ligne : À faire · **Chantier (select, déplaçable)** · QUI (pastilles cliquables) · Priorité (pastille couleur) · Date butoir · Remarque · Fait · Supprimer.
- Filtres : **boutons rapides par personne** (Tous/JN/KB/OG/FF/LD, toggle), priorité, « Masquer les faites », « Masquer les chantiers sans tâche ».
- **Seed unique** : `seedTachesIfNeeded()` importe les 77 tâches de l'Excel une seule fois (si la clé `taches` n'existe pas encore dans Firebase) et auto-crée les 5 admins via `ensureSeedAdmins()`. Câblé dans `initDataSync` (capture `hadTaches`).
- Spec : `docs/superpowers/specs/2026-06-02-feuille-de-tache-design.md` · Plan : `docs/superpowers/plans/2026-06-02-todo-list-tab.md`.
- Piège Firebase : RTDB supprime les tableaux vides → une tâche `qui:[]` revient `qui` undefined. Le render gère (`t.qui || []`), `toggleTacheQui` réinitialise `t.qui` si besoin.

## Mise à jour précédente (mai 2026) — Firebase Authentication
Ajout de Firebase Authentication suite à expiration des règles de test :
- Écran de login DIAGON (orange) avec email/password + bouton Google
- Conteneur `#app-container` qui cache toute l'app tant que pas connecté
- DB load (`initDataSync`) déclenché uniquement après `onAuthStateChanged`
- Bouton "Se déconnecter" + email utilisateur affichés dans la sidebar
- Règles RTDB durcies : `.read/.write: "auth != null"` sur `/planning`
- Procédure complète dans `DEPLOIEMENT_AUTH.md`
- Règles JSON archivées dans `firebase.rules.json`

## Architecture technique actuelle

### Fichier principal : `index.html` (~2200 lignes)
Tout est dans un seul fichier. Contient :
- **Login overlay** (`#login-overlay`) — affiché par défaut, caché après auth
- **App container** (`#app-container`) — caché par défaut, affiché après auth
- HTML structure (header, grille planning, sidebar, modal Gérer)
- CSS inline + Tailwind
- JS monolithique avec :
  - Firebase init + Auth + sync (rerender/mutateAndSync pattern)
  - `AUTH.onAuthStateChanged()` bascule entre login et app
  - `initDataSync()` charge la DB uniquement après auth réussie
  - Données en mémoire : CHANTIERS (26), RESSOURCES (13 + 5 admins), EQUIPEMENTS (8), AFFECTATIONS, LIVRAISONS, BESOINS, TACHES
  - 5 vues : Par ouvrier, Par chantier, Atelier, Ressources, TO DO LIST
  - Drag & drop HTML5
  - Duplication (jour suivant / jusqu'à vendredi)
  - Clear par jour / par semaine
  - Modal CRUD pour ouvriers, chantiers, équipements

### Firebase
```
Project: diagon-planning (europe-west1)
Forfait: Spark (gratuit)
DB_REF: planning
Auth providers: Email/Password + Google
Authorized domains: localhost, ffidale-ship-it.github.io
```

**Pattern critique** :
- `rerender()` = affichage seul (jamais de sync)
- `mutateAndSync()` = affichage + sync Firebase
- Seules les mutations utilisateur appellent `mutateAndSync()`
- DB load (`DB_REF.once`) est appelé UNIQUEMENT depuis `initDataSync()` après auth

**Règles RTDB actuelles** (`firebase.rules.json`) :
```json
{
  "rules": {
    "planning": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

### GitHub
- Repo : `ffidale-ship-it/planning-diagon`
- Déploiement : GitHub Pages (branche main)
- Push direct vers main = déploiement auto en 1-2 min

## Stack cible (backend à construire)
- PostgreSQL 16+ avec 3 schémas séparés (RGPD) :
  - `planning` : chantiers, affectations, ressources (prénom seul) — accessible IA
  - `fiches` : nom complet, photo, dates — PAS accessible IA
  - `rh` : registre national (AES-256), pointages, salaires — JAMAIS accessible IA
- Backend : Node.js / Next.js
- Hébergement : Docker sur NAS Synology (dev), puis VPS UE (prod)
- L'IA accède au planning uniquement via des stored procedures nommées

## Contraintes métier
- Granularité : journée entière (pas de demi-journée)
- 1 ouvrier = 1 chantier/jour (contrainte unique)
- 1 équipement = 1 chantier/jour (contrainte unique)
- Semaine de travail : lundi → samedi (pas de dimanche)
- Vue : 4 semaines glissantes
- Encadrement (Frans, Kevin, Laurent, Olivier, Julie) : non imputable au planning chantier
- Check-in@Work ONSS : obligation légale BTP Belgique à intégrer ultérieurement

## Fichiers du projet (dossier `planning-diagon/`)
- `index.html` — version active déployée (avec auth)
- `src/planning_maquette_v4.html` — maquette de référence
- `src/planning_maquette_v3.html` — version précédente (2 vues, sans Firebase)
- `firebase.rules.json` — règles RTDB de production (auth != null)
- `DEPLOIEMENT_AUTH.md` — procédure de déploiement auth pas à pas
- `MIGRATION_BRIEFING.md` — notes de migration
- `db/001_init_schema_planning.sql` — premier jet du schéma PostgreSQL
- `docs/Cahier_des_charges_Planning_v0.1.md` — spécifications fonctionnelles
- `docs/Schema_base_de_donnees_v0.1.md` — schéma PostgreSQL détaillé
- `assets/DIAGON_logo_baseline_CMJN_2026.png` — logo entreprise

## Roadmap
1. Migration vers projet structuré (multi-fichiers, composants)
2. Backend PostgreSQL + API REST
3. ~~Authentification (quelques comptes bureau + chefs d'équipe)~~ ✅ **FAIT (mai 2026)**
4. Pilotage vocal IA (interprétation LLM → stored procedures)
5. Docker + déploiement NAS Synology
6. Module Check-in@Work ONSS
7. App mobile responsive (chefs d'équipe)
8. **Backup automatique RTDB** (export JSON hebdo → GitHub Actions ou cron)

## Sécurité (à surveiller)
- Forfait Spark → pas de backup automatique : faire export JSON manuel régulier
- Règles RTDB durcies (`auth != null`) — ne PAS repasser en mode test
- MFA Google obligatoire sur le compte propriétaire Firebase
- Si un utilisateur quitte DIAGON : supprimer son compte dans Firebase Auth > Users

## Conventions
- Langue du code : anglais pour les noms de variables/fonctions, français pour les labels UI
- Nommage : **DIAGON** (jamais "Diagone")
- Dates : toujours en local (pas de UTC) pour la Belgique — utiliser `_localISO()` pattern
- Avant tout commit : tester en local en ouvrant `index.html` dans le navigateur
- Toujours vérifier la syntaxe JS avec un parser avant de commit (le fichier est monolithique)

## Pièges connus

- **Affectations orphelines** : `chantierById(a.c)` peut retourner `undefined` si un chantier a été supprimé par un autre user (sync Firebase asymétrique). `renderViewOuvrier` a une garde au render qui rend une cellule vide ([:1251](index.html:1251)). `renderViewChantier` filtre déjà au render ([:1369](index.html:1369)).
- **NE PAS purger les affectations orphelines au `loadFromFirebase`** : `chantierById` utilise `===` strict, donc un id `"385"` (string) ≠ `385` (number) → une purge globale supprime des affectations VALIDES, et la prochaine mutation écrase la donnée cloud. Tentative et revert documentés dans `git show 10903a5`.
- **Toggle 🏗 / 🔧** (`show_chantier` / `show_atelier`) : désactiver `show_chantier` sur un chantier qui a des affectations à venir crée une incohérence à 3 voix — vue par chantier cache la ligne, vue par ouvrier affiche la bulle, COUVERTURE x/x compte l'ouvrier. `setChantierScope` prévient avant l'action mais ne bloque pas.
- **Affectations fantômes sur jours d'indispo** (sujet identifié, non-traité) : `_dupChantierToDate` ([:2075](index.html:2075)) et `_dupOuvrierToDate` ([:2069](index.html:2069), appelé par `dupWeek('ouvrier')`) ne vérifient pas `indispoAt` → un "+1j" ou "→ven" peut créer des `AFFECTATIONS` invisibles (masquées par l'overlay indispo au render) qui réapparaissent dès que l'indispo est retirée.
