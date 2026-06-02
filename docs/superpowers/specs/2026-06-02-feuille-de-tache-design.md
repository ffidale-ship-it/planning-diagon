# Feuille de tâche — nouvel onglet (design)

Date : 2026-06-02
Auteur : Frans + Claude

## Objectif

Ajouter un 5ᵉ onglet « Feuille de tâche » dans l'app planning, destiné à
**remplacer l'Excel `TB COMMANDE DIAGON > TO DO LIST`**. Liste de tâches par
chantier, éditable et synchronisée Firebase entre tous les utilisateurs comme le
reste du planning.

## 1. Onglet / bouton

- 5ᵉ bouton `view-bubble` sur la même rangée que les 4 vues existantes
  (Par ouvrier / Par chantier / Atelier / Ressources).
- **Décalé à droite** (espace/séparateur avant) et **un peu plus gros** pour le
  différencier visuellement des vues planning.
- Icône 📋, label « Feuille de tâche ».
- `id="btn-view-taches"`, état `VIEW = "taches"`, fonction `renderViewTaches()`.

## 2. Catégorie « Admin » dans les ressources

Les assignés « QUI » sont gérés comme une nouvelle catégorie de ressource.

- Ajouter le type **`admin`** dans le sélecteur de création d'ouvrier
  (`new-ouv-cat` : chantier / atelier / externe / **admin**).
- Les ressources `cat === "admin"` :
  - `show_chantier = false`, `show_atelier = false` → **n'apparaissent jamais
    dans les vues planning** (encadrement non imputable).
  - `addOuvrier()` : pour `admin`, ne pas exiger qu'une case chantier/atelier
    soit cochée (les deux restent à false).
- Frans créera lui-même les 5 admins :
  - JN = Julie Noville
  - KB = Kévin Bernard
  - OG = Olivier Gillet
  - FF = François Fidale
  - LD = Laurent Delehouse

## 3. Modèle de données

Nouveau tableau en mémoire `TACHES`, synchronisé Firebase (clé `taches`).

```
TACHE = {
  id,                 // number, unique (max+1, même logique anti-collision que les ressources)
  c,                  // id chantier (number) ou null = groupe "Général / sans chantier"
  todo,               // string, description de la tâche
  qui,                // [adminId, ...] ids de ressources cat="admin"
  priorite,           // "faible" | "normale" | "elevee" | "critique" | "" (vide)
  dateButoir,         // ISO local "YYYY-MM-DD" ou "" (réutiliser _localISO())
  remarque,           // string libre
  fait,               // bool
}
```

Initiales QUI : **déduites du nom** de l'admin (1ʳᵉ lettre de chaque mot).
Ex. « Julie Noville » → JN, « Kévin Bernard » → KB. Pas de champ initiales stocké.

## 4. Affichage

- Tâches **regroupées par chantier**, dans l'ordre des chantiers, plus un groupe
  **« Général / sans chantier »** (`c === null`).
- Colonnes par tâche : **À faire · QUI (initiales) · Priorité · Date butoir ·
  Remarque · Fait**.
- Priorité = pastille couleur :
  - Faible → vert · Normale → jaune · Élevée → orange · Critique → rouge.
- Tâches **faites** : grisées (et masquables via filtre).

## 5. Édition (CRUD, synchro via `mutateAndSync()`)

- Bouton **« + Ajouter une tâche »** sous chaque chantier (et dans Général).
- Modifier un champ directement dans la ligne (clic → input/select).
- Cocher **Fait** (case à cocher).
- Supprimer une tâche (croix).

## 6. Filtres (barre en haut de l'onglet)

- Par **QUI** (mes tâches / un admin donné).
- Par **priorité**.
- **Masquer les tâches faites** (case à cocher).

## 7. Reprise des données (import unique depuis l'Excel)

- Pré-charger les **77 tâches** actuelles de l'onglet `TO DO LIST` comme données
  de départ (seed), une seule fois.
- Mapping :
  - Chantier « 385- INTERNAT DE SPA » → `c = 385` (numéro en tête de cellule).
    Si le numéro ne correspond à aucun chantier connu → groupe Général.
  - QUI (texte « KB, FF ») → résolu vers les ids des admins par initiales.
    Si un admin n'existe pas encore au moment du seed, l'initiale est ignorée
    (Frans crée les admins avant/après ; à préciser dans le plan d'implémentation).
  - Priorité Excel (Faible/Normale/Élevée/Critique) → clés internes.
  - DATE BUTOIR (date Excel) → ISO local.
  - FAIT « Oui » → `true`.
  - Colonne NOTIFIER : **ignorée** (hors scope v1).

## 8. Synchronisation Firebase

- Ajouter `taches` au payload de `syncToFirebase()` et au chargement
  `loadFromFirebase()` + valeurs par défaut de `initDataSync()`.
- CRUD via `mutateAndSync()` (affichage + sync), lectures via `rerender()`.

## Hors scope (v1)

- Colonne/notifications « NOTIFIER ».
- Vues séparées par personne (l'onglet TAB LAURENT de l'Excel) — couvert par le
  filtre QUI.
- Rappels/alertes sur date butoir.

## Points ouverts pour le plan d'implémentation

- Ordre du seed vs création des admins (résolution des initiales QUI).
- Édition inline : champs cliquables vs petit formulaire par ligne.
