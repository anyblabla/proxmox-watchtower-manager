#!/bin/bash
# ==============================================================================
# Script: manage_watchtower_all.sh
# Description: Gestion de Watchtower pour tous les LXC (All states) via Tags.
# Features: Auto-start/stop LXC, Tag filtering (watchtower), Docker wait-loop.
# Author: Amaury aka BlablaLinux
# Website: https://blablalinux.be
# Wiki: https://wiki.blablalinux.be/fr/script-gestion-watchtower
# License: GPL-3.0
# Version: 1.2.0
# ==============================================================================

MENU="
===============================================
   Gestion Watchtower - MAINTENANCE TOTALE (Tags)
===============================================
 [1] 🔍 Voir l’état actuel de Watchtower
 [2] 🚀 Démarrer Watchtower
 [3] 🛑 Arrêter Watchtower
 [4] 🔁 Redémarrer Watchtower
 [5] 📂 Voir le contenu du docker-compose.yml
 [6] 🔄 Définir restart policy (always/none)
 [7] ✏️  Modifier WATCHTOWER_NO_STARTUP_MESSAGE
 [8] ✏️  Modifier WATCHTOWER_CLEANUP
 [9] 📅 Modifier le schedule aléatoire (14h-20h)
 [10] 📅 Fixer le même schedule pour tous
 [11] ✏️  Modifier WATCHTOWER_TIMEOUT
 [12] ✏️  Modifier WATCHTOWER_NOTIFICATION_GOTIFY_URL
 [13] 🖼️  Modifier l'image Docker
 [14] 🧹 Nettoyer toutes les images (prune -a)
 [Q] ❌ Quitter
"

run_action_on_all() {
    local action_func=$1
    for lxc_id in $(pct list | awk 'NR>1{print $1}'); do
        tags=$(pct config "$lxc_id" | grep "^tags:" | awk '{print $2}')
        
        # --- CORRECTION FILTRAGE PAR MOT ENTIER ---
        # On ne traite QUE si le tag exact "watchtower" est présent, évite d'inclure "watchtower-custom"
        if [[ " $tags " =~ " watchtower " ]]; then
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

        if pct exec "$lxc_id" -- docker ps >/dev/null 2>&1; then
            $action_func "$lxc_id"
        else
            echo "🚫 Erreur : Docker non prêt."
        fi

        if [ "$was_stopped" = true ]; then
            echo "💤 Retour à l'état éteint..."
            pct stop "$lxc_id"
        fi
    done
    read -rp "Terminé. Appuyez sur [Entrée]..."
}

_status() {
    compose_file=$(find_watchtower_compose "$1")
    [ -n "$compose_file" ] && pct exec "$1" -- docker ps --filter name=watchtower || echo "Pas de compose."
}
_start() {
    compose_file=$(find_watchtower_compose "$1")
    [ -n "$compose_file" ] && { dir=$(dirname "$compose_file"); pct exec "$1" -- sh -c "cd $dir && docker compose up -d"; echo "🚀 Lancé."; }
}
_stop() { pct exec "$1" -- docker stop watchtower >/dev/null 2>&1 && echo "🛑 Arrêté."; }
_restart() {
    compose_file=$(find_watchtower_compose "$1")
    [ -n "$compose_file" ] && { dir=$(dirname "$compose_file"); pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"; echo "🔁 Redémarré."; }
}
_view() {
    compose_file=$(find_watchtower_compose "$1")
    [ -n "$compose_file" ] && pct exec "$1" -- sh -c "grep -E 'image:|restart:|WATCHTOWER_NO_STARTUP_MESSAGE|WATCHTOWER_CLEANUP|WATCHTOWER_SCHEDULE|WATCHTOWER_TIMEOUT|WATCHTOWER_NOTIFICATION_GOTIFY_URL' $compose_file"
}
_modify_key() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s|^\s*-\s*$GLOBAL_KEY=.*|      - $GLOBAL_KEY=$GLOBAL_VAL|" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ $GLOBAL_KEY mis à jour."
    fi
}
_set_image() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s#^[[:space:]]*image: .*#    image: $GLOBAL_VAL#" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
    fi
}
_random_sched() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        hour=$((RANDOM % 7 + 14)) ; minute=$((RANDOM % 12 * 5)) ; schedule="0 $minute $hour ? * 5"
        pct exec "$1" -- sed -i "s|^\s*-\s*WATCHTOWER_SCHEDULE=.*|      - WATCHTOWER_SCHEDULE=$schedule|" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        echo "✅ Schedule fixé : $schedule"
    fi
}
_prune() { echo "🧹 Pruning images..."; pct exec "$1" -- docker image prune -a -f; }
_set_policy() {
    compose_file=$(find_watchtower_compose "$1")
    if [ -n "$compose_file" ]; then
        pct exec "$1" -- sed -i "s/^[[:space:]]*restart: .*/    restart: $GLOBAL_VAL/" "$compose_file"
        dir=$(dirname "$compose_file")
        pct exec "$1" -- sh -c "cd $dir && docker compose down && docker compose up -d"
    fi
}
find_watchtower_compose() { timeout 5s pct exec "$1" -- find /root -type f -path "*/watchtower/docker-compose.yml" 2>/dev/null | head -n1; }

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
        10) GLOBAL_KEY="WATCHTOWER_SCHEDULE" ; read -rp "Cron : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        11) GLOBAL_KEY="WATCHTOWER_TIMEOUT" ; read -rp "Valeur : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        12) GLOBAL_KEY="WATCHTOWER_NOTIFICATION_GOTIFY_URL" ; read -rp "Nouvelle URL Gotify : " GLOBAL_VAL ; run_action_on_all _modify_key ;;
        13) read -rp "Image : " GLOBAL_VAL ; run_action_on_all _set_image ;;
        14) read -rp "Confirmer prune (oui/non) : " conf ; [[ "$conf" =~ ^[Oo][Uu][Ii]$ ]] && run_action_on_all _prune ;;
        [Qq]) exit ;;
    esac
done
