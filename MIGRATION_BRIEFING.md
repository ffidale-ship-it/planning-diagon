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

## Ce qui reste à faire (par priorité)

### Court terme
1. **Éclater le monolithe** : le fichier unique de 134KB doit devenir un projet structuré (composants, modules)
2. **Backend PostgreSQL** : le schéma est documenté, il faut l'implémenter avec une API REST
3. **Authentification** : login simple pour quelques comptes

### Moyen terme
4. **Pilotage vocal IA** : interprétation LLM des commandes vocales → appel de stored procedures
5. **Docker** : déploiement sur NAS Synology
6. **Check-in@Work ONSS** : déclaration obligatoire BTP Belgique

### Long terme
7. **Mobile responsive** pour les chefs d'équipe
8. **Module RH** : pointages, heures sup (schéma `rh`, jamais exposé à l'IA)

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
