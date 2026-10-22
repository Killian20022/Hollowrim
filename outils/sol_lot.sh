#!/bin/bash
# usage: sol_lot.sh <poses> <dossier de sortie> [options Godot après --]
G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe; W=C:/Users/lopezk19/Jeux/nordique_sol_v2
P=$1; S=$2; shift 2
bash /tmp/godot_slot.sh $G --path $W --disable-vsync -- --captures=$W/$P --sortie=$W/$S --nouvelle --paisible --sans-particules --sans-mains --sans-hud --attente=120 "$@" 2>&1 | grep -E "LOT|ERROR|SCRIPT|Parse|error" | head -20
