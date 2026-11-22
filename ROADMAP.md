# Roadmap 🚀

### Prochaines étapes (Short-term)
- [ ] Ajouter une option de sauvegarde du `docker-compose.yml` avant chaque modification (aujourd'hui, seule la migration Gotify → Shoutrrr crée un `.bak`).
- [ ] Permettre la personnalisation du chemin de recherche du fichier compose (actuellement `/root`, `/opt` et `/home` pour `manage_watchtower_all.sh`, et `/root` uniquement pour `manage_watchtower.sh`).
- [ ] Reporter dans `manage_watchtower.sh` les correctifs de la v2.1.0 de `manage_watchtower_all.sh` : restart policy valide (`no` au lieu de `none`) et détection des clés absentes.
- [ ] Masquer le token Gotify dans l'affichage de la migration (l'URL Shoutrrr complète est actuellement affichée en clair).

### Idées à l'étude (Long-term)
- [ ] Support des VMs via le QEMU Guest Agent.
- [ ] Création d'un installeur automatique pour Watchtower dans les nouveaux LXC.
- [ ] Intégration d'une interface de log centralisée.
- [ ] Version anglaise des scripts publiée dans le dépôt, en plus de la version française.
