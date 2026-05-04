# Module Planning DIAGON — Spécification pour intégration ERP

**Version** : 1.0 (2026-04-18)
**Repo** : https://github.com/ffidale-ship-it/planning-diagon
**Live** : https://ffidale-ship-it.github.io/planning-diagon/

Ce document est la référence pour intégrer le module Planning dans un ERP plus large. Il décrit le modèle de données, les règles métier, les vues UI, et les points d'intégration avec d'autres modules.

---

## 1. Contexte métier

**Société** : DIAGON (Belgique) — bardage, parement de façade, structures métalliques.

**Volumétrie** :
| Élément | Volume |
|---|---|
| Chantiers actifs simultanés | 5 à 10 |
| Chantiers par an | ~40 |
| Ouvriers chantier | ~10 |
| Ouvriers atelier | 3 |
| Externes (intérim, sous-traitants) | ~2 |
| Encadrement (Frans, Kévin, Laurent, Olivier, Julie) | non imputable au planning |

**Granularité** : journée entière côté chantier, multi-affectations/jour côté atelier.
**Horizon visible** : 1, 2 ou 4 semaines glissantes (toggle utilisateur).
**Semaine de travail** : lundi → vendredi par défaut, samedi en option.

---

## 2. Modèle de données

### 2.1 Entités

```typescript
// Chantier (incluant les "travaux atelier" comme pliage, soudure pour tiers, etc.)
CHANTIER {
  id: number              // 365–417 historique, 500+ pour les nouveaux
  client: string
  nom: string
  show_chantier: boolean  // visible dans Par ouvrier + Par chantier
  show_atelier: boolean   // visible dans la vue Atelier
  // Aucun scope coché = archivé
}

// Ouvrier (ressource humaine)
RESSOURCE {
  id: number              // 1–13 historique, 100+ pour les nouveaux
  nom: string             // prénom seul (RGPD : pas de nom de famille ici)
  cat: "chantier" | "atelier" | "externe"  // catégorie principale (couleur)
  chef: boolean           // chef d'équipe (étoile ⭐)
  show_chantier: boolean  // apparait dans Par ouvrier + Par chantier
  show_atelier: boolean   // apparait dans Atelier
  visible: boolean        // soft-delete (legacy)
}

// Équipement (matériel)
EQUIPEMENT {
  id: string              // "nac-15", "cam-iv", etc.
  type: "nacelle" | "camion" | "remorque" | "outillage"
  nom: string
}

// Affectation chantier : 1 ouvrier / 1 chantier / 1 jour (UNIQUE)
AFFECTATION {
  r: number               // ressource id
  c: number               // chantier id
  d: string               // "YYYY-MM-DD" (timezone Belgique)
}

// Affectation atelier : 1 ouvrier peut être sur N chantiers le même jour
AFFECTATION_ATELIER {
  r: number
  c: number
  d: string
}

// Affectation équipement : 1 équipement / 1 chantier / 1 jour
AFFECTATION_EQUIP {
  e: string               // équipement id
  c: number
  d: string
}

// Indisponibilité (congé, maladie, formation)
INDISPO {
  r: number
  d: string
  type: "conge" | "maladie" | "formation"
}

// Livraison : matériel livré sur un chantier à une date précise
LIVRAISON {
  id: string
  nom: string             // "Bardage Rockpanel"
  qte: string             // "120 m2"
  c: number               // chantier
  d: string               // "YYYY-MM-DD"
}

// Besoin matériel : projection à la semaine, pas encore livré
BESOIN {
  id: string
  nom: string
  qte: string
  c: number
  semaine: number         // numéro semaine ISO
}
```

### 2.2 Contraintes d'intégrité

- **Affectation chantier** : `UNIQUE(r, d)` — un ouvrier ne peut être que sur un chantier par jour.
- **Indispo et affectation chantier** : mutuellement exclusives sur `(r, d)`.
- **Affectation atelier** : pas de contrainte d'unicité — un ouvrier peut empiler plusieurs entrées le même jour.
- **Affectation équipement** : `UNIQUE(e, d)` — un équipement = un chantier par jour.
- **Si `show_chantier=false` ET `show_atelier=false`** sur un chantier ou ressource → considéré archivé, exclu de toutes les vues.

### 2.3 Migration depuis ancien schéma

L'ancien schéma utilisait `actif: boolean` + `atelier_only: boolean` sur les chantiers et `cat` seul sur les ressources. La migration est lazy au chargement (voir `migrateChantiersSchema()` et `migrateRessourcesSchema()` dans `index.html`).

---

## 3. Vues UI (4 vues)

| Vue | Rows | Cols | Cellule contient | Particularité |
|---|---|---|---|---|
| **Par ouvrier** | ouvriers (`show_chantier=true`) | jours | bulle chantier ou indispo | 1 affectation/jour |
| **Par chantier** | chantiers (`show_chantier=true`) | jours | liste ouvriers + équipements + livraisons | + ligne INDISPONIBILITÉS en bas |
| **Atelier** | ouvriers (`show_atelier=true`) | jours | stack de chantiers | multi-affectations/jour, 2 semaines max |
| **Par ressources** | équipements + livraisons + besoins | jours | détails matériel | 4 semaines |

**Boutons globaux dans le header** :
- `🏗 Chantiers` `👷 Ouvriers` `🚚 Équipements` (gestion CRUD via modal unique)
- `🖨 PDF sem.` / `🖨 PDF 4 sem.` (export A3 paysage natif via dialog d'impression)
- `+ Sam` / `− Sam` (toggle colonne samedi)
- `Vue 1 sem.` / `Vue 4 sem.` (zoom écran)

---

## 4. Architecture technique

### 4.1 Stack actuel (maquette)

- **Front** : single-file `index.html` (1800 lignes, HTML + Tailwind CDN + JS vanilla)
- **Backend** : aucun, **Firebase Realtime Database** comme BD côté client
- **Sync** : pattern `rerender()` (affichage seul) vs `mutateAndSync()` (affichage + push Firebase)
- **Auth** : aucune (3 users de confiance, ouvert à tout porteur de l'URL)
- **Hébergement** : GitHub Pages (statique gratuit, déploiement automatique sur push `main`)

### 4.2 Stack cible (ERP)

```
PostgreSQL 16+ avec 3 schémas séparés (séparation RGPD stricte) :

  ┌─ schéma planning ────────────────────────┐
  │ chantiers, ressources (prénom seul),     │  ← accessible IA
  │ affectations, indispos, livraisons,      │     via stored procedures nommées
  │ besoins, equipements                     │
  └──────────────────────────────────────────┘

  ┌─ schéma fiches ──────────────────────────┐
  │ identité complète : nom + prénom,        │  ← PAS accessible IA
  │ photo, date d'embauche, fonction         │     accès bureau uniquement
  └──────────────────────────────────────────┘

  ┌─ schéma rh ──────────────────────────────┐
  │ registre national (AES-256), pointages,  │  ← JAMAIS accessible IA
  │ heures supp, salaires, contrats          │     accès direction + paie
  └──────────────────────────────────────────┘
```

- **Backend** : Node.js / Next.js (API REST + stored procedures pour l'IA)
- **Hébergement** :
  - Phase 1 : Docker sur **NAS Synology** au bureau (données on-premise)
  - Phase 2 : VPS UE sécurisé (OVH Roubaix, Combell, Scaleway)
- **Auth** : login simple, comptes bureau + chefs d'équipe (~5–8 users max)
- **Accès distant** : Tailscale ou tunnel VPN
- **Sauvegardes 3-2-1** : NAS + disque externe + cloud chiffré (Backblaze ou domicile)

### 4.3 Pattern de sync (critique)

Dans la maquette actuelle :
- `rerender()` = affichage UI seul, **JAMAIS** appelé depuis un listener Firebase (boucle infinie sinon)
- `mutateAndSync()` = mutation locale + UI + push Firebase
- `loadFromFirebase()` = écrase l'état local + rerender (sans sync retour)
- Initial : `DB_REF.once()` charge la DB AVANT d'activer le listener temps réel

À conserver dans l'ERP : le front-end doit avoir un sync optimiste (UI mise à jour immédiate, retry transparent si l'API échoue).

---

## 5. Sécurité

- **XSS** : tous les noms saisis utilisateur sont passés par la fonction `esc()` avant insertion dans le DOM.
- **Firebase credentials** : actuellement en clair dans `index.html` (publié sur GitHub). Tolérable pour 3 users de confiance, **inacceptable pour l'ERP** : à externaliser dans `.env` côté backend.
- **Pas d'auth actuelle** : URL secrète = sécurité. Quiconque a le lien peut éditer. À durcir dans l'ERP.

---

## 6. Points d'intégration avec un ERP

### 6.1 Modules consommateurs (lisent les données du planning)

| Module ERP | Donnée consommée | Usage |
|---|---|---|
| **Facturation** | AFFECTATIONS | Calcul heures main d'œuvre par chantier (taux × jours × ouvriers) |
| **Reporting / Tableau de bord** | AFFECTATIONS, INDISPOS | Taux de couverture, occupation, absences |
| **Check-in@Work ONSS** (BTP Belgique, légal) | AFFECTATIONS, RESSOURCES | Déclaration quotidienne obligatoire ouvriers présents par chantier |
| **App mobile chefs d'équipe** | AFFECTATIONS du jour J / J+1 | Vue "où je vais demain" + prépa matériel |

### 6.2 Modules fournisseurs (alimentent le planning)

| Module ERP | Donnée produite | Cible planning |
|---|---|---|
| **Commandes / CRM** | Nouveau chantier signé (client, nom, dates estimées) | crée un CHANTIER |
| **RH** | Embauche / départ ouvrier | crée / archive RESSOURCE |
| **RH** | Demande de congé approuvée | crée INDISPO type=conge |
| **RH** | Arrêt maladie reçu | crée INDISPO type=maladie |
| **RH** | Formation programmée | crée INDISPO type=formation |
| **Stock / Achats** | Bon de livraison prévu | crée LIVRAISON |
| **Stock / Achats** | Estimation matériel chantier | crée BESOIN |
| **Parc matériel** | Équipement loué / cassé | màj disponibilité EQUIPEMENT |

### 6.3 Pilotage vocal IA (spécifique DIAGON)

Cas d'usage prévu : Frans dicte des modifications au téléphone, le LLM interprète, appelle des stored procedures Postgres nommées (`affecter_ouvrier`, `marquer_indispo`, `dupliquer_equipe`, etc.), confirme visuellement avant validation.

L'IA n'a accès **qu'au schéma `planning`**, jamais aux fiches RH ni aux salaires.

---

## 7. Roadmap

### Court terme (priorités à attaquer)
1. **Backend PostgreSQL** : implémenter le schéma `planning`, exposer une API REST minimale, écrire le script de migration Firebase → Postgres.
2. **Authentification** : login simple, rôles admin / chef / lecture seule.
3. **Bascule front** : remplacer les appels Firebase par `fetch('/api/...')` dans `index.html`. Sync via polling 3s ou Server-Sent Events.

### Moyen terme
4. Pilotage vocal IA (LLM → stored procedures).
5. App mobile responsive pour chefs d'équipe.
6. Module Check-in@Work ONSS.
7. Alertes automatiques ("Delhaize commence lundi, aucune équipe affectée").
8. Équipes-types mémorisables (sauver + rappeler une équipe en un clic).

### Long terme
9. Module RH complet (pointages, heures sup) — schéma `rh` jamais exposé à l'IA.
10. Module facturation alimenté par les affectations.

---

## 8. Conventions du projet

- **Code** : variables/fonctions en anglais, labels UI en français
- **Nommage société** : **DIAGON** (jamais "Diagone")
- **Dates** : toujours en local Belgique, jamais en UTC. Utiliser `_localISO()` (pattern existant) ou équivalent côté backend
- **Granularité** : journée entière côté chantier ; pas de 1/2 journée (sauf vue atelier qui empile)

---

## 9. Liens utiles

- Live planning : https://ffidale-ship-it.github.io/planning-diagon/
- Repo : https://github.com/ffidale-ship-it/planning-diagon
- Cahier des charges initial : `docs/Cahier_des_charges_Planning_v0.1.md`
- Schéma DB détaillé : `docs/Schema_base_de_donnees_v0.1.md`
- Briefing migration : `MIGRATION_BRIEFING.md`
- Contexte projet : `CLAUDE.md`
