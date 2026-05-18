# DIAGON — ERP Planning Chantier

## Contexte
DIAGON (sans E) est une entreprise belge de bardage, parement de façade et structures métalliques. Ce projet est la première brique d'un ERP sur mesure : un module de planification des équipes sur chantiers.

## Utilisateur principal
Frans — dirigeant de DIAGON. Francophone. Préfère les réponses concises, directes, et aime être challengé. Pas de fluff.

## État actuel
**Maquette fonctionnelle déployée** sur GitHub Pages : https://ffidale-ship-it.github.io/planning-diagon/

- Single-file HTML/CSS/JS (`index.html` = `planning_maquette_v4.html`)
- Tailwind CSS via CDN
- Firebase Realtime Database pour sync multi-utilisateurs (3 users : Frans, Kévin, Olivier)
- Pas de backend — tout est côté client avec Firebase

## Architecture technique actuelle

### Fichier principal : `index.html`
Tout est dans un seul fichier (~134KB). Contient :
- HTML structure (header, grille planning, sidebar, modal Gérer)
- CSS inline + Tailwind
- JS monolithique avec :
  - Firebase init + sync (rerender/mutateAndSync pattern)
  - Données en mémoire : CHANTIERS (26), RESSOURCES (13), EQUIPEMENTS (8), AFFECTATIONS, LIVRAISONS, BESOINS
  - 4 vues : Par ouvrier, Par chantier, Atelier, Ressources
  - Drag & drop HTML5
  - Duplication (jour suivant / jusqu'à vendredi)
  - Clear par jour / par semaine
  - Modal CRUD pour ouvriers, chantiers, équipements

### Firebase
```
Config: diagon-planning (europe-west1)
DB_REF: planning
```
Pattern critique : `rerender()` = affichage seul (jamais de sync). `mutateAndSync()` = affichage + sync Firebase. Seules les mutations utilisateur appellent `mutateAndSync()`.

### GitHub
- Repo : `ffidale-ship-it/planning-diagon`
- Déploiement : GitHub Pages (branche main)

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

## Fichiers du projet
- `index.html` / `planning_maquette_v4.html` — maquette active
- `planning_maquette_v3.html` — version précédente (2 vues, sans Firebase)
- `Cahier_des_charges_Planning_v0.1.md` — spécifications fonctionnelles
- `Schema_base_de_donnees_v0.1.md` — schéma PostgreSQL détaillé
- `Recap_Maquette_Planning_v4.docx` — synthèse features maquette
- `DIAGON_logo_baseline_CMJN_2026.png` — logo entreprise
- `TB COMMANDE DIAGON By HDM 2023 (1).xlsx` — tableau de bord commandes
- `chantiers.pdf` / `fichier personnel.pdf` — données source
- `planning_maquette.html` / `planning_maquette_par_chantier.html` — prototypes initiaux

## Roadmap
1. Migration vers projet structuré (multi-fichiers, composants)
2. Backend PostgreSQL + API REST
3. Authentification (quelques comptes bureau + chefs d'équipe)
4. Pilotage vocal IA (interprétation LLM → stored procedures)
5. Docker + déploiement NAS Synology
6. Module Check-in@Work ONSS
7. App mobile responsive (chefs d'équipe)

## Conventions
- Langue du code : anglais pour les noms de variables/fonctions, français pour les labels UI
- Nommage : **DIAGON** (jamais "Diagone")
- Dates : toujours en local (pas de UTC) pour la Belgique — utiliser `_localISO()` pattern

## Pièges connus

- **Affectations orphelines** : `chantierById(a.c)` peut retourner `undefined` si un chantier a été supprimé par un autre user (sync Firebase asymétrique). `renderViewOuvrier` a une garde au render qui rend une cellule vide ([:1251](index.html:1251)). `renderViewChantier` filtre déjà au render ([:1369](index.html:1369)).
- **NE PAS purger les affectations orphelines au `loadFromFirebase`** : `chantierById` utilise `===` strict, donc un id `"385"` (string) ≠ `385` (number) → une purge globale supprime des affectations VALIDES, et la prochaine mutation écrase la donnée cloud. Tentative et revert documentés dans `git show 10903a5`.
- **Toggle 🏗 / 🔧** (`show_chantier` / `show_atelier`) : désactiver `show_chantier` sur un chantier qui a des affectations à venir crée une incohérence à 3 voix — vue par chantier cache la ligne, vue par ouvrier affiche la bulle, COUVERTURE x/x compte l'ouvrier. `setChantierScope` prévient avant l'action mais ne bloque pas.
- **Affectations fantômes sur jours d'indispo** (sujet identifié, non-traité) : `_dupChantierToDate` ([:2075](index.html:2075)) et `_dupOuvrierToDate` ([:2069](index.html:2069), appelé par `dupWeek('ouvrier')`) ne vérifient pas `indispoAt` → un "+1j" ou "→ven" peut créer des `AFFECTATIONS` invisibles (masquées par l'overlay indispo au render) qui réapparaissent dès que l'indispo est retirée.
