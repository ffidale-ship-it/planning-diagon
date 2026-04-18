-- Migration 001 : Création du schéma planning (opérationnel, IA OK)
-- Voir docs/Schema_base_de_donnees_v0.1.md pour le détail complet

CREATE SCHEMA IF NOT EXISTS planning;

-- Types ENUM
CREATE TYPE planning.categorie_ressource AS ENUM (
  'ouvrier_chantier',
  'ouvrier_atelier',
  'encadrement',
  'interim',
  'sous_traitant_equipe'
);

CREATE TYPE planning.type_equipement AS ENUM (
  'nacelle',
  'echafaudage',
  'camion',
  'remorque',
  'outillage_lourd',
  'autre'
);

CREATE TYPE planning.motif_indispo AS ENUM (
  'conge',
  'maladie',
  'formation',
  'rdv_medical',
  'autre'
);

-- Tables
CREATE TABLE planning.clients (
  id            SERIAL PRIMARY KEY,
  nom           VARCHAR(100) NOT NULL,
  actif         BOOLEAN DEFAULT TRUE,
  cree_le       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.chantiers (
  id              INT PRIMARY KEY,
  client_id       INT REFERENCES planning.clients(id),
  nom             VARCHAR(150) NOT NULL,
  adresse         TEXT,
  code_postal     VARCHAR(10),
  ville           VARCHAR(80),
  onss_id         VARCHAR(30),
  statut          VARCHAR(20) DEFAULT 'actif',
  date_debut      DATE,
  date_fin_prevue DATE,
  couleur_hex     VARCHAR(7),
  notes           TEXT,
  cree_le         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.ressources (
  id                          SERIAL PRIMARY KEY,
  prenom                      VARCHAR(50) NOT NULL,
  categorie                   planning.categorie_ressource NOT NULL,
  imputable_planning_chantier BOOLEAN NOT NULL DEFAULT TRUE,
  fiche_id                    INT,
  actif                       BOOLEAN DEFAULT TRUE,
  cree_le                     TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.equipements (
  id              SERIAL PRIMARY KEY,
  nom             VARCHAR(100) NOT NULL,
  type            planning.type_equipement NOT NULL,
  numero_serie    VARCHAR(80),
  hauteur_max_m   NUMERIC(5,2),
  capacite_kg     INT,
  date_revision   DATE,
  actif           BOOLEAN DEFAULT TRUE,
  notes           TEXT,
  cree_le         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.affectations (
  id             BIGSERIAL PRIMARY KEY,
  date_jour      DATE NOT NULL,
  chantier_id    INT NOT NULL REFERENCES planning.chantiers(id),
  ressource_id   INT REFERENCES planning.ressources(id),
  equipement_id  INT REFERENCES planning.equipements(id),
  commentaire    TEXT,
  cree_par       VARCHAR(50),
  cree_le        TIMESTAMPTZ DEFAULT now(),
  modifie_le     TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT ressource_xor_equipement
    CHECK ((ressource_id IS NOT NULL)::int + (equipement_id IS NOT NULL)::int = 1),
  CONSTRAINT unique_ressource_jour
    UNIQUE (ressource_id, date_jour),
  CONSTRAINT unique_equipement_jour
    UNIQUE (equipement_id, date_jour)
);

CREATE INDEX idx_aff_date ON planning.affectations(date_jour);
CREATE INDEX idx_aff_chantier_date ON planning.affectations(chantier_id, date_jour);

CREATE TABLE planning.indisponibilites (
  id            SERIAL PRIMARY KEY,
  ressource_id  INT NOT NULL REFERENCES planning.ressources(id),
  date_debut    DATE NOT NULL,
  date_fin      DATE NOT NULL,
  motif         planning.motif_indispo NOT NULL,
  commentaire   TEXT,
  cree_le       TIMESTAMPTZ DEFAULT now(),
  CHECK (date_fin >= date_debut)
);

CREATE TABLE planning.taches (
  id            SERIAL PRIMARY KEY,
  chantier_id   INT REFERENCES planning.chantiers(id),
  libelle       TEXT NOT NULL,
  priorite      INT DEFAULT 2,
  echeance      DATE,
  fait          BOOLEAN DEFAULT FALSE,
  fait_le       TIMESTAMPTZ,
  cree_le       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.utilisateurs (
  id              SERIAL PRIMARY KEY,
  email           VARCHAR(120) UNIQUE NOT NULL,
  nom_complet     VARCHAR(100),
  hash_mdp        VARCHAR(255) NOT NULL,
  role            VARCHAR(30) NOT NULL,
  actif           BOOLEAN DEFAULT TRUE,
  derniere_conn   TIMESTAMPTZ,
  cree_le         TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE planning.audit_log (
  id            BIGSERIAL PRIMARY KEY,
  utilisateur   VARCHAR(120),
  action        VARCHAR(50),
  table_cible   VARCHAR(50),
  id_cible      TEXT,
  avant         JSONB,
  apres         JSONB,
  cree_le       TIMESTAMPTZ DEFAULT now()
);
