#!/bin/bash
# ==============================================================================
# Script: manage_watchtower.sh
# Description: Gestion centralisée de Watchtower pour LXC (allumés uniquement).
# Author: Amaury aka BlablaLinux
# Website: https://blablalinux.be
# Wiki: https://wiki.blablalinux.be/fr/script-gestion-watchtower
# License: GPL-3.0
# Version: 1.1.0
# ==============================================================================

MENU="
===============================================
    Gestion de Watchtower dans les conteneurs LXC
===============================================
 [1] 🔍 Voir l’état actuel de Watchtower
 [2] 🚀 Démarrer Watchtower
 [3] 🛑 Arrêter Watchtower
 [4] 🔁 Redémarrer Watchtower
 [5] 📂 Voir le contenu modifiable du docker-compose.yml
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

get_running_docker_lxc() {
    pct list | awk 'NR>1 && $2=="running"{print $1}' | while read lxc; do
        if pct exec "$lxc" -- docker ps >/dev/null 2>&1; then
            echo "$lxc"
        fi
    done
}

find_watchtower_compose() {
    timeout 5s pct exec "$1" -- find /root -type f -path "*/watchtower/docker-compose.yml" 2>/dev/null | head -n1
}

status_watchtower() {
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        echo "→ LXC $lxc_id"
        [ -n "$compose_file" ] && pct exec "$lxc_id" -- docker ps --filter name=watchtower || echo "Non trouvé."
    done
    read -rp "Appuyez sur [Entrée]..."
}

start_watchtower() {
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose up -d"
            echo "🚀 Démarré dans LXC $lxc_id"
        fi
    done
    read -rp "Terminé. [Entrée]..."
}

stop_watchtower() {
    for lxc_id in $(get_running_docker_lxc); do
        pct exec "$lxc_id" -- docker stop watchtower >/dev/null 2>&1 && echo "🛑 Arrêté dans LXC $lxc_id"
    done
    read -rp "Terminé. [Entrée]..."
}

restart_watchtower() {
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
            echo "🔁 Redémarré dans LXC $lxc_id"
        fi
    done
    read -rp "Terminé. [Entrée]..."
}

view_compose() {
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        echo "→ LXC $lxc_id"
        [ -n "$compose_file" ] && pct exec "$lxc_id" -- sh -c "grep -E 'image:|restart:|WATCHTOWER_NO_STARTUP_MESSAGE|WATCHTOWER_CLEANUP|WATCHTOWER_SCHEDULE|WATCHTOWER_TIMEOUT|WATCHTOWER_NOTIFICATION_GOTIFY_URL' $compose_file"
    done
    read -rp "Appuyez sur [Entrée]..."
}

modify_key_restart() {
    key=$1
    val=$2
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            pct exec "$lxc_id" -- sed -i "s|^\s*-\s*$key=.*|      - $key=$val|" "$compose_file"
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
            echo "✅ $key mis à jour dans LXC $lxc_id"
        fi
    done
}

set_restart_policy() {
    read -rp "Policy (always/none) : " new_policy
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            pct exec "$lxc_id" -- sed -i "s/^[[:space:]]*restart: .*/    restart: $new_policy/" "$compose_file"
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
            echo "✅ Policy $new_policy dans LXC $lxc_id"
        fi
    done
}

random_schedule() {
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            hour=$((RANDOM % 7 + 14))
            minute=$((RANDOM % 12 * 5))
            schedule="0 $minute $hour ? * 5"
            pct exec "$lxc_id" -- sed -i "s|^\s*-\s*WATCHTOWER_SCHEDULE=.*|      - WATCHTOWER_SCHEDULE=$schedule|" "$compose_file"
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
            echo "✅ Schedule $schedule pour LXC $lxc_id"
        fi
    done
}

set_watchtower_image() {
    read -rp "Image (ex: containrrr/watchtower:latest): " img
    for lxc_id in $(get_running_docker_lxc); do
        compose_file=$(find_watchtower_compose "$lxc_id")
        if [ -n "$compose_file" ]; then
            pct exec "$lxc_id" -- sed -i "s#^[[:space:]]*image: .*#    image: $img#" "$compose_file"
            dir=$(dirname "$compose_file")
            pct exec "$lxc_id" -- sh -c "cd $dir && docker compose down && docker compose up -d"
        fi
    done
}

prune_docker_images() {
    read -rp "Confirmer prune -a sur TOUS les LXC actifs? (oui/non): " conf
    if [[ "$conf" =~ ^[Oo][Uu][Ii]$ ]]; then
        for lxc_id in $(get_running_docker_lxc); do
            pct exec "$lxc_id" -- docker delete image prune -a -f
        done
    fi
}

while true; do
    clear ; echo "$MENU" ; read -rp "Choix : " choice
    case $choice in
        1) status_watchtower ;;
        2) start_watchtower ;;
        3) stop_watchtower ;;
        4) restart_watchtower ;;
        5) view_compose ;;
        6) set_restart_policy ;;
        7) read -rp "true/false : " v; modify_key_restart "WATCHTOWER_NO_STARTUP_MESSAGE" "$v" ;;
        8) read -rp "true/false : " v; modify_key_restart "WATCHTOWER_CLEANUP" "$v" ;;
        9) random_schedule ;;
        10) read -rp "Cron : " v; modify_key_restart "WATCHTOWER_SCHEDULE" "$v" ;;
        11) read -rp "Timeout : " v; modify_key_restart "WATCHTOWER_TIMEOUT" "$v" ;;
        12) read -rp "Nouvelle URL Gotify : " v; modify_key_restart "WATCHTOWER_NOTIFICATION_GOTIFY_URL" "$v" ;;
        13) set_watchtower_image ;;
        14) prune_docker_images ;;
        [Qq]) exit ;;
    esac
done
