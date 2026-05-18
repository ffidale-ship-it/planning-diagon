# Déploiement Firebase Authentication — Planning DIAGON

## Ordre strict des étapes

### 1. Activer Email/Password dans Firebase
- Console Firebase → `diagon-planning` → **Authentication** → bouton **Commencer**
- Onglet **Sign-in method** (Méthode de connexion)
- Activer **Email/Password** (cliquer dessus, cocher "Activer", enregistrer)
- ❌ Ne PAS activer "Email link (passwordless sign-in)"

### 2. Créer les 5 comptes utilisateurs
- Authentication → onglet **Users** (Utilisateurs)
- Bouton **Ajouter un utilisateur**
- Créer un compte par personne :
  - Frans : f.fidale@diagon.be
  - Kévin : (à définir)
  - Olivier : (à définir)
  - Laurent : (à définir)
  - Julie : (à définir)
- Mot de passe temporaire au choix (les utilisateurs pourront le changer via "Mot de passe oublié")
- ⚠️ Note les mots de passe initiaux pour les transmettre aux utilisateurs

### 3. Tester en local AVANT de déployer
- Ouvrir `index.html` dans le navigateur (double-clic)
- L'écran de login doit apparaître
- Tester avec un compte créé à l'étape 2
- Vérifier que le planning se charge avec toutes les données

### 4. Déployer sur GitHub Pages
```bash
cd "/Users/frans/Claude/Projects/CLAUDE PLANNING DIAGON/planning-diagon"
git add index.html firebase.rules.json DEPLOIEMENT_AUTH.md
git commit -m "Ajout Firebase Authentication (Email/Password)"
git push
```
GitHub Pages se met à jour automatiquement en 1-2 minutes.

### 5. Tester la version déployée
- Aller sur https://ffidale-ship-it.github.io/planning-diagon/
- Vérifier le login fonctionne
- Tester le drag & drop, etc.
- Vérifier la sync entre 2 onglets

### 6. SEULEMENT APRÈS confirmation que tout marche : sécuriser les règles
- Console Firebase → **Realtime Database** → onglet **Règles**
- Remplacer par le contenu de `firebase.rules.json` :
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
- Cliquer **Publier**
- ✅ L'avertissement orange "Vos règles ne sont pas sécurisées" doit disparaître

### 7. Communiquer aux utilisateurs
- Envoyer l'URL + email + mot de passe à chacun
- Leur dire qu'ils peuvent changer leur mot de passe via "Mot de passe oublié"

## En cas de problème

**"auth/operation-not-allowed"** → Email/Password pas activé à l'étape 1
**"auth/invalid-credential"** → Email ou mot de passe incorrect
**Page blanche après login** → Vérifier la console navigateur (F12). Si erreur "permission denied" → les règles Firebase sont trop restrictives, repasser temporairement à `.read: true, .write: true`

## Rollback rapide
Si la prod casse après déploiement :
```bash
git revert HEAD
git push
```
Et remettre les règles Firebase à `.read: true, .write: true` temporairement.
