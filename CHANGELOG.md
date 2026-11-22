# Changelog 📝

## [2.1.0] - 2026-11-22
### Ajouté
- Validation de la saisie de la restart policy (option 6) : seules les valeurs `always`, `no`, `unless-stopped` et `on-failure` sont acceptées.
- Détection des clés absentes dans `manage_watchtower_all.sh` : un avertissement est affiché si la clé à modifier (options 7, 8, 10, 11 et 12) ou la ligne `restart:` n'existe pas dans le compose du LXC.
- Demande de confirmation avant la suppression des sauvegardes (option 16).

### Modifié
- L'option de nettoyage des sauvegardes (16) supprime désormais les fichiers `*.bkp` **et** `*.bak` du dossier du compose Watchtower. Les `.bak` générés par la migration contiennent l'ancien token Gotify en clair et peuvent maintenant être supprimés une fois la migration validée.

### Corrigé
- Restart policy : la valeur `none` n'existe pas dans Docker et laissait Watchtower arrêté après le redémarrage. Elle est remplacée par `no`, écrit entre guillemets (`restart: "no"`) pour éviter son interprétation en booléen par YAML 1.1.
- Faux message « mis à jour » lorsque la clé n'existait pas dans le compose : le script ne modifie plus rien et ne redémarre plus Watchtower dans ce cas.

## [2.0.0] - 2026-08-01
### Ajouté
- Migration automatique des notifications Gotify legacy vers le format Shoutrrr (`WATCHTOWER_NOTIFICATION_URL`) via une nouvelle option de menu (15).
- Option de nettoyage des anciennes sauvegardes de compose `.bkp` (16), sans toucher aux `.bak` générés par la migration.
- Messages d'erreur explicites lorsque le `docker-compose.yml` de Watchtower est introuvable.

### Modifié
- Recherche du fichier compose en deux temps (chemin ciblé puis recherche par contenu) pour plus de fiabilité, notamment sur les LXC volumineux ou fraîchement démarrés.
- L'option 12 édite désormais directement `WATCHTOWER_NOTIFICATION_URL` (Shoutrrr) plutôt que l'ancienne variable `WATCHTOWER_NOTIFICATION_GOTIFY_URL`.

### Corrigé
- Ajout d'une pause de stabilisation (3s) après le démarrage d'un LXC éteint, pour éviter les faux négatifs de recherche liés à un système encore en cours de démarrage.

## [1.1.0] - 2026-01-05
### Ajouté
- Nouveau script `manage_watchtower_all.sh`.
- Filtrage par étiquettes (Tags) Proxmox.
- Boucle d'attente (wait-loop) pour l'initialisation de Docker au démarrage du LXC.

## [1.0.0] - 2025-12-XX
### Ajouté
- Script initial `manage_watchtower.sh` pour LXC allumés.
- Fonctions de base (start/stop/restart/config).
