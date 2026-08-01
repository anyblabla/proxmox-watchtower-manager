# Changelog 📝

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
