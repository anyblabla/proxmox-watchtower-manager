# Proxmox Watchtower Manager 🐳

[🇫🇷 Français](#français) | [🇺🇸 English](#english)

---

<div align="center">
  <p><b>📺 Démonstration Vidéo / Video Demo :</b></p>
  <a href="https://mastodon.blablalinux.be/@blablalinux/115826788636738220" target="_blank">
    <img src="https://img.shields.io/badge/Mastodon-Video_Demo-563acc?style=for-the-badge&logo=mastodon&logoColor=white" alt="Video Demo">
  </a>
</div>

---

<a name="français"></a>
## 🇫🇷 Français

### Présentation
Une suite de scripts Bash conçus pour les administrateurs **Proxmox** souhaitant gérer Watchtower sur l'ensemble de leurs conteneurs **LXC** depuis l'hôte, sans avoir à se connecter à chaque instance.

### Points forts
- **Gestion intelligente :** Démarre les LXC éteints, applique les changements, et les éteint à nouveau.
- **Filtrage par Tags :** Utilise l'étiquette `watchtower` de Proxmox pour cibler les conteneurs.
- **Maintenance complète :** Modification du planning (Cron), nettoyage des images (`prune`), changement de politique de redémarrage (`always`, `no`, `unless-stopped`, `on-failure`, avec validation de la saisie).
- **Modifications sécurisées :** Si une clé à modifier est absente du compose d'un LXC, elle est signalée sans rien changer ni redémarrer Watchtower inutilement.
- **Migration Gotify → Shoutrrr :** Bascule automatiquement les notifications Gotify legacy vers le nouveau format d'URL Shoutrrr (`WATCHTOWER_NOTIFICATION_URL`), avec sauvegarde du fichier compose.
- **Nettoyage automatisé :** Supprime les anciennes sauvegardes de configuration (`.bkp`) et celles générées par la migration (`.bak`, qui contiennent l'ancien token Gotify), après confirmation.

### Documentation complète
Retrouvez le tutoriel détaillé sur notre wiki : 
👉 [wiki.blablalinux.be/fr/script-gestion-watchtower](https://wiki.blablalinux.be/fr/script-gestion-watchtower)

---

<a name="english"></a>
## 🇺🇸 English

### Overview
A suite of Bash scripts designed for **Proxmox** administrators to manage Watchtower across all **LXC** containers directly from the host, without individual logins.

### Key Features
- **Smart Management:** Automatically starts stopped LXCs, applies changes, and shuts them down again.
- **Tag Filtering:** Uses the Proxmox `watchtower` tag to target specific containers.
- **Full Maintenance:** Update schedules (Cron), image cleanup (`prune`), and restart policy management (`always`, `no`, `unless-stopped`, `on-failure`, with input validation).
- **Safe Edits:** If a key to modify is missing from an LXC's compose file, it is reported without changing anything or restarting Watchtower needlessly.
- **Gotify → Shoutrrr Migration:** Automatically converts legacy Gotify notification settings to the new Shoutrrr URL format (`WATCHTOWER_NOTIFICATION_URL`), with a compose file backup.
- **Automated Cleanup:** Removes old configuration backups (`.bkp`) and the ones created by the migration (`.bak`, which contain the old Gotify token), after confirmation.

### Full Documentation
Check out the detailed tutorial on our wiki:
👉 [wiki.blablalinux.be/en/script-gestion-watchtower](https://wiki.blablalinux.be/en/script-gestion-watchtower)

---

## 📜 License
This project is licensed under the **GPL-3.0 License**.
