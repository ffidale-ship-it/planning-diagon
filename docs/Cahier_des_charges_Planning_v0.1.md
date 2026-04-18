# Cahier des charges – Module Planning Diagone

**Version :** 0.1 (brouillon de travail)
**Date :** 16 avril 2026
**Auteur :** Frans (dirigeant Diagone) + Claude
**Statut :** En cours de cadrage

---

## 1. Contexte

Diagone réalise des travaux de bardage, parement de façade et structures métalliques. La planification des équipes sur les chantiers est actuellement gérée sous Excel, sans satisfaction : le rendu visuel est médiocre, le partage difficile, et les plannings finissent régulièrement refaits à la main.

Aucune application interne n'existe à ce jour. Ce module sera la première brique d'un futur ERP Diagone développé sur mesure.

## 2. Objectif du module

Remplacer Excel par une application web de planification des chantiers, offrant :

- Une vue claire et moderne sur 4 semaines glissantes
- Une affectation ressource par ressource, jour par jour
- Une souplesse totale pour recomposer les équipes (1, 2 ou 3 équipes par jour)
- À terme, un pilotage du planning par commande vocale/IA
- À terme, un accès mobile pour les chefs d'équipe (consultation + prépa dépôt)

## 3. Volumétrie cible

| Élément | Volume |
|---|---|
| Chantiers actifs simultanés | 5 à 10 |
| Chantiers par an | 40 maximum |
| Ressources chantier à planifier | ~10 ouvriers |
| Ressources atelier à planifier | 3 ouvriers |
| Ressources bureau (planning séparé) | 1 deviseur / dessinateur |
| Granularité | Journée |
| Horizon de vue | 4 semaines glissantes |

## 4. Utilisateurs

### Phase 1 (MVP – bureau uniquement)
- Direction (Frans) – pilotage, création/modif du planning
- Administratif / bureau – consultation et mise à jour

### Phase 2 (accès terrain)
- Chefs d'équipe – consultation mobile : "où je vais demain" + prépa matériel au dépôt

### Hors périmètre (pour l'instant)
- Ouvriers (pas d'accès individuel pour démarrer)
- Sous-traitants

## 5. Fonctionnalités – MVP (Phase 1)

### 5.1 Gestion des chantiers
- Créer un chantier (nom, client, adresse, dates estimées, description courte)
- Modifier / archiver un chantier
- Lister les chantiers actifs

### 5.2 Gestion des ressources
- Créer un ouvrier (nom, rôle, chantier/atelier, actif/inactif)
- Marquer un jour d'indisponibilité (congé, maladie, formation)

### 5.3 Planning – vue principale
- **Vue 4 semaines glissantes**, format tableau
- En lignes : les ressources (ouvriers)
- En colonnes : les jours ouvrés
- En cellule : le chantier affecté (code couleur par chantier)
- Distinction visuelle des indisponibilités (congé, maladie…)

### 5.4 Édition du planning
- Affectation d'une ressource à un chantier pour un ou plusieurs jours
- Déplacement rapide (glisser-déposer ou équivalent simple)
- Recomposition libre des équipes : 1, 2 ou 3 équipes par jour selon besoin
- Historique des modifications (traçabilité minimale)

### 5.5 Pilotage IA (spécificité Diagone)
- **Saisie vocale des modifications** (dictée) → interprétation LLM → modification automatique du planning
  - Exemples : "Demain, Julien passe sur le chantier Delhaize Namur."
  - "Mercredi, mets toute l'équipe sur Kinepolis Bruxelles."
  - "Pierre est malade jeudi et vendredi."
- Confirmation visuelle de la modification avant validation

### 5.6 Impression / export
- Export PDF ou image du planning pour affichage / diffusion
- Export Excel pour archivage (rétrocompatibilité)

## 6. Fonctionnalités – Phase 2 (après validation MVP)

- Application mobile (web responsive suffit probablement) pour les chefs d'équipe
- Vue "Mon planning" personnelle
- Vue "Prépa matériel" de la journée suivante
- Notifications de changement de planning
- Planning séparé du deviseur / dessinateur (à préciser)

## 7. Contraintes techniques et architecture

### 7.1 Hébergement (décision v0.1)

**Phase de développement et MVP** : en local
- PC de Frans pour le développement (dev local)
- NAS du bureau pour l'hébergement de la base PostgreSQL et de l'application
- Avantage : données physiquement chez Diagone, zéro dépendance cloud au démarrage
- Prérequis NAS : support Docker (vérifier modèle), minimum 4 Go de RAM, SSD recommandé

**Phase ultérieure (après validation MVP et avant ajout des pointages)** : migration vers hébergement sécurisé à définir (VPS Belgique/UE type OVH Roubaix, Combell, Scaleway, ou solution d'hébergement professionnel).

### 7.2 Séparation des données (architecture RGPD-ready)

Deux couches logiques à séparer dès le départ :

| Couche | Contenu | Accès IA |
|---|---|---|
| **Données opérationnelles** | Chantiers, ressources (noms), affectations jour/chantier, indisponibilités | Autorisé sur demande explicite (pilotage vocal) |
| **Données sensibles RH** | Pointages, heures, heures supp, à terme salaires | **Jamais exposé à l'IA** |

**Règle d'or** : l'IA (API Claude) est un copilote optionnel pour le planning. L'application fonctionne 100 % sans IA pour toutes les opérations RH et pointage.

### 7.3 Sauvegardes (règle 3-2-1 non négociable)

- 3 copies des données
- 2 supports différents (NAS + disque externe USB)
- 1 copie hors site (cloud chiffré type Backblaze/Hetzner ou disque externe ramené au domicile)
- Sauvegarde automatique quotidienne de la base PostgreSQL

### 7.4 Autres contraintes

- **Multi-utilisateurs** : édition simultanée sans conflit (verrous courts ou temps réel)
- **Accès** : navigateur (desktop en phase 1, mobile responsive en phase 2)
- **Authentification** : login simple, quelques comptes seulement (bureau + chefs d'équipe à terme)
- **Accès distant** : via VPN ou tunnel sécurisé (Tailscale recommandé pour sa simplicité)
- **Budget cible** : à définir

## 8. Points encore ouverts (à traiter en v0.2)

- Gestion du matériel / nacelles / échafaudages (ressources non humaines)
- Lien avec la facturation et les heures travaillées
- Gestion des sous-traitants éventuels
- Planning séparé du deviseur / dessinateur : pourquoi séparé ? Faut-il vraiment deux systèmes ?
- Budget de développement et délai souhaité
- Maintenance évolutive : qui, comment ?

## 9. Critères de succès du MVP

Le MVP sera considéré réussi si, après 1 mois d'usage réel :

1. Frans ne revient pas à Excel pour faire le planning
2. Le planning n'est plus refait à la main sur papier
3. La modification d'une affectation prend moins de 10 secondes
4. La vue 4 semaines est lisible d'un coup d'œil
5. Au moins une modification a été réalisée par commande vocale avec succès
