#!/bin/bash
# ==============================================================================
# Script: manage_watchtower_all.sh
# Description: Gestion de Watchtower pour tous les LXC (All states) via Tags.
# Features: Auto-start/stop LXC, Tag filtering (watchtower), Docker wait-loop,
#           migration Gotify legacy -> Shoutrrr, nettoyage des sauvegardes .bkp.
# Author: Amaury aka BlablaLinux
# Website: https://blablalinux.be
# Wiki: https://wiki.blablalinux.be/fr/script-gestion-watchtower
# License: GPL-3.0
# Version: 2.0.0
# ==============================================================================

MENU="
===============================================
   Gestion Watchtower - TAG 'watchtower' UNIQUE
===============================================
 [1] 🔍 Voir l'état actuel de Watchtower
 [2] 🚀 Démarrer Watchtower
 [3] 🛑 Arrêter Watchtower
 [4] 🔁 Redémarrer Watchtower
 [5] 📂 Voir le contenu du docker-compose.yml
 [6] 🔄 Définir restart policy (always/none)
 [7] ✏️  Modifier WATCHTOWER_NO_STARTUP_MESSAGE
 [8] ✏️  Modifier WATCHTOWER_CLEANUP
 [9] 📅 Modifier le schedule aléatoire (14h-20h le samedi)
 [10] 📅 Fixer le même schedule pour tous
 [11] ✏️  Modifier WATCHTOWER_TIMEOUT
 [12] ✏️  Modifier WATCHTOWER_NOTIFICATION_URL (Shoutrrr)
 [13] 🖼️  Modifier l'image Docker
 [14] 🧹 Nettoyer toutes les images (prune -a)
 [15] 🔀 Migrer Gotify legacy -> Shoutrrr (WATCHTOWER_NOTIFICATION_URL)
 [16] 🗑️  Supprimer les anciennes sauvegardes (*.bkp)
 [Q] ❌ Quitter
"

# --- FONCTION MAÎTRESSE (Filtrage par Tag et Gestion d'état) ---

run_action_on_all() {
    local action_func=$1

    for lxc_id in $(pct list | awk 'NR>1{print $1}'); do
        # Récupération des tags du LXC
        tags=$(pct config "$lxc_id" | grep "^tags:" | awk '{print $2}')

        # --- CORRECTION FILTRAGE PAR MOT ENTIER ---
        if echo "$tags" | grep -qE "(^|;)watchtower(;|$)" ; then
            initial_status=$(pct status "$lxc_id" | awk '{print $2}')
            hostname=$(pct config "$lxc_id" | grep "^hostname:" | awk '{print $2}')
            echo "--- Traitement LXC $lxc_id ($hostname) ---"
        else
            continue
        fi

        was_stopped=false
        if [ "$initial_status" == "stopped" ]; then
            echo "⚡ Démarrage du LXC..."
            pct start "$lxc_id"
            was_stopped=true

            # Boucle d'attente Docker
            echo -n "⏳ Attente Docker..."
            success=false
            for i in {1..15}; do
                if pct exec "$lxc_id" -- docker ps >/dev/null 2>&1; then
                    echo " OK !"
                    success=true
                    break
                fi
                echo -n "."
                sleep 1
            done

            if [ "$success" = false ]; then
                echo -e "\n❌ Docker injoignable. Passage au suivant."
                pct stop "$lxc_id"
                continue
            fi
        fi

        # Exécution de la commande
        if pct exec "$lxc_id" -- docker ps >/dev/null 2>&1; then
            if [ "$was_stopped" = true ]; then
                # Petite pause : juste après le boot, le FS/IO peut encore être chargé
                # (démarrage des services), on laisse le système se stabiliser avant
                # de scanner les fichiers.
                sleep 3
            fi
            $action_func "$lxc_id"
        else
            echo "🚫 Erreur : Docker non prêt."
        fi

        # Retour à l'état initial
        if [ "$was_stopped" = true ]; then
            echo "💤 Retour à l'état éteint..."
            pct stop "$lxc_id"
        fi
    done
    read -rp "Terminé. Appuyez sur [Entrée]..."
}

# --- FONCTIONS UNITAIRES ---

_status() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- docker ps --filter name=watchtower
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_start() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose up -d"
        echo "🚀 Lancé."
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_stop() { pct exec "$1" -- docker stop watchtower >/dev/null 2>&1 && echo "🛑 Arrêté." || echo "🚫 Conteneur watchtower introuvable/déjà arrêté."; }
_restart() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "🔁 Redémarré."
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_view() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        echo "📄 $compose_file"
        pct exec "$1" -- sh -c "grep -E 'image:|restart:|WATCHTOWER_NO_STARTUP_MESSAGE|WATCHTOWER_CLEANUP|WATCHTOWER_SCHEDULE|WATCHTOWER_TIMEOUT|WATCHTOWER_NOTIFICATION_GOTIFY_URL|WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN|WATCHTOWER_NOTIFICATIONS|WATCHTOWER_NOTIFICATION_URL' $compose_file"
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_modify_key() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s|^\s*-\s*$GLOBAL_KEY=.*|      - $GLOBAL_KEY=$GLOBAL_VAL|" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ $GLOBAL_KEY mis à jour."
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_set_image() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s#^[[:space:]]*image: .*#    image: $GLOBAL_VAL#" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ Image mise à jour."
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_random_sched() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        hour=$((RANDOM % 7 + 14)) ; minute=$((RANDOM % 12 * 5)) ; schedule="0 $minute $hour ? * 6"
        pct exec "$1" -- sed -i "s|^\s*-\s*WATCHTOWER_SCHEDULE=.*|      - WATCHTOWER_SCHEDULE=$schedule|" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ Schedule fixé : $schedule"
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
_prune() { echo "🧹 Pruning images..."; pct exec "$1" -- docker image prune -a -f; }
_set_policy() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s/^[[:space:]]*restart: .*/    restart: $GLOBAL_VAL/" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ Restart policy mise à jour."
    else
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
    fi
}
# Recherche large : n'importe quel docker-compose.yml/.yaml contenant une image watchtower
# (containrrr/watchtower ou nickfedor/watchtower), quel que soit le nom du dossier parent.
# On évite de dépendre d'un dossier littéralement appelé "watchtower".
find_watchtower_compose() {
    local lxc_id="$1"
    local result

    # 1) Recherche rapide et ciblée : chemin contenant "watchtower", profondeur limitée.
    result=$(timeout 8s pct exec "$lxc_id" -- sh -c "find /root /opt /home -maxdepth 4 -type f \( -iname 'docker-compose.yml' -o -iname 'docker-compose.yaml' \) -path '*watchtower*' 2>/dev/null | head -n1")
    if [ -n "$result" ]; then
        echo "$result"
        return
    fi

    # 2) Repli : scan large par contenu (plus lent), au cas où le dossier ne contient
    #    pas "watchtower" dans son nom. Timeout plus généreux.
    timeout 20s pct exec "$lxc_id" -- sh -c "grep -rlE 'image:[[:space:]]*(containrrr|nickfedor)/watchtower' /root /opt /home 2>/dev/null | head -n1"
}

# --- MIGRATION GOTIFY LEGACY -> SHOUTRRR ---
#
# Lit WATCHTOWER_NOTIFICATION_GOTIFY_URL / _TOKEN, construit une URL
# gotify://host[:port]/token (avec ?disabletls=yes si l'URL d'origine est en http://),
# supprime les 3 anciennes clés (URL, TOKEN, TLS_SKIP_VERIFY) et l'entrée
# "gotify" de WATCHTOWER_NOTIFICATIONS si elle est seule, puis insère
# WATCHTOWER_NOTIFICATION_URL. Le fichier est sauvegardé en .bak avant modif.

_migrate_gotify() {
    lxc_id="$1"
    compose_file=$(find_watchtower_compose "$lxc_id")
    if [ -z "$compose_file" ]; then
        echo "🚫 Pas de compose trouvé, LXC ignoré."
        return
    fi

    url_line=$(pct exec "$lxc_id" -- grep -E 'WATCHTOWER_NOTIFICATION_GOTIFY_URL=' "$compose_file" 2>/dev/null)
    token_line=$(pct exec "$lxc_id" -- grep -E 'WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=' "$compose_file" 2>/dev/null)

    if [ -z "$url_line" ] || [ -z "$token_line" ]; then
        echo "ℹ️  Aucune config Gotify legacy trouvée (déjà migré ou non configuré). LXC ignoré."
        return
    fi

    # Détecter si un notifier autre que gotify est aussi déclaré (config plus complexe -> pas d'auto-suppression)
    notif_line=$(pct exec "$lxc_id" -- grep -E 'WATCHTOWER_NOTIFICATIONS=' "$compose_file" 2>/dev/null)
    notif_val=$(echo "$notif_line" | sed -E 's/.*WATCHTOWER_NOTIFICATIONS=//; s/"//g' | tr -d '[:space:]')

    old_url=$(echo "$url_line" | sed -E 's/.*WATCHTOWER_NOTIFICATION_GOTIFY_URL=//; s/"//g' | tr -d '[:space:]')
    old_token=$(echo "$token_line" | sed -E 's/.*WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=//; s/"//g' | tr -d '[:space:]')

    if echo "$old_url" | grep -qE '^https://'; then
        host_port=$(echo "$old_url" | sed -E 's#^https://##; s#/$##')
        tls_suffix=""
    else
        host_port=$(echo "$old_url" | sed -E 's#^http://##; s#/$##')
        tls_suffix="?disabletls=yes"
    fi

    new_url="gotify://${host_port}/${old_token}${tls_suffix}"

    echo "🔎 LXC $lxc_id : ancienne URL = $old_url"
    echo "   -> Nouvelle URL Shoutrrr : $new_url"

    # Sauvegarde
    pct exec "$lxc_id" -- cp "$compose_file" "${compose_file}.bak"

    # Suppression des anciennes clés
    pct exec "$lxc_id" -- sed -i '/WATCHTOWER_NOTIFICATION_GOTIFY_URL=/d' "$compose_file"
    pct exec "$lxc_id" -- sed -i '/WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN=/d' "$compose_file"
    pct exec "$lxc_id" -- sed -i '/WATCHTOWER_NOTIFICATION_GOTIFY_TLS_SKIP_VERIFY=/d' "$compose_file"

    if [ "$notif_val" = "gotify" ]; then
        pct exec "$lxc_id" -- sed -i '/WATCHTOWER_NOTIFICATIONS=/d' "$compose_file"
    elif [ -n "$notif_val" ]; then
        echo "⚠️  WATCHTOWER_NOTIFICATIONS contient '$notif_val' (pas seulement gotify)."
        echo "    Cette ligne n'a PAS été supprimée automatiquement, vérifie-la manuellement."
    fi

    # Insertion de la nouvelle clé juste après la ligne "environment:"
    pct exec "$lxc_id" -- sed -i "/^\s*environment:/a\\      - WATCHTOWER_NOTIFICATION_URL=${new_url}" "$compose_file"

    dir=$(dirname "$compose_file")
    pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
    echo "✅ Migration terminée pour LXC $lxc_id (sauvegarde : ${compose_file}.bak)"
}

# --- NETTOYAGE DES SAUVEGARDES (.bkp) ---
#
# Cherche, dans le même dossier que le docker-compose.yml trouvé, tout fichier
# se terminant par .bkp (anciennes sauvegardes manuelles) et les supprime.
# Les .bak (générés par l'option 15) ne sont volontairement PAS touchés.

_cleanup_backups() {
    lxc_id="$1"
    compose_file=$(find_watchtower_compose "$lxc_id")
    if [ -z "$compose_file" ]; then
        echo "🚫 Compose Watchtower introuvable pour ce LXC."
        return
    fi

    dir=$(dirname "$compose_file")
    backups=$(pct exec "$lxc_id" -- find "$dir" -maxdepth 1 -type f -name "*.bkp" 2>/dev/null)

    if [ -z "$backups" ]; then
        echo "ℹ️  Aucune sauvegarde .bkp trouvée dans $dir."
        return
    fi

    echo "🗂️  Sauvegardes .bkp trouvées dans $dir :"
    echo "$backups" | sed 's/^/   - /'

    pct exec "$lxc_id" -- find "$dir" -maxdepth 1 -type f -name "*.bkp" -delete
    echo "✅ Sauvegardes .bkp supprimées."
}

# --- BOUCLE MENU ---

while true; do
    clear ; echo "$MENU" ; read -rp "Votre choix : " choice
    case $choice in
        1) run_action_on_all _status ;;
        2) run_action_on_all _start ;;
        3) run_action_on_all _stop ;;
        4) run_action_on_all _restart ;;
        5) run_action_on_all _view ;;
        6) read -rp "Policy (always/none) : " GLOBAL_VAL ; run_action_on_all _set_policy ;;
        7) GLOBAL_KEY="WATCHTOWER_NO_STARTUP_MESSAGE" ; read -rp "true/false : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        8) GLOBAL_KEY="WATCHTOWER_CLEANUP" ; read -rp "true/false : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        9) run_action_on_all _random_sched ;;
        10) GLOBAL_KEY="WATCHTOWER_SCHEDULE" ; read -rp "Spring Cron : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        11) GLOBAL_KEY="WATCHTOWER_TIMEOUT" ; read -rp "Valeur : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        12) GLOBAL_KEY="WATCHTOWER_NOTIFICATION_URL" ; read -rp "Nouvelle URL Shoutrrr (ex: gotify://host:port/token?disabletls=yes) : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        13) read -rp "Image : " GLOBAL_VAL ; run_action_on_all _set_image ;;
        14) read -rp "Confirmer prune (oui/non) : " conf ; [[ "$conf" =~ ^[Oo][Uu][Ii]$ ]] && run_action_on_all _prune ;;
        15) read -rp "⚠️  Migrer tous les LXC 'watchtower' vers Shoutrrr ? (oui/non) : " conf ; [[ "$conf" =~ ^[Oo][Uu][Ii]$ ]] && run_action_on_all _migrate_gotify ;;
        16) run_action_on_all _cleanup_backups ;;
        [Qq]) exit ;;
        *) echo "Option invalide." ; sleep 1 ;;
    esac
done
