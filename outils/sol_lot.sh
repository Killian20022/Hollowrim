#!/bin/bash
# usage: sol_lot.sh <poses> <dossier de sortie> [options Godot]  -- journal complet dans /tmp/sol_lot_<nom>.log
G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe; W=C:/Users/lopezk19/Jeux/nordique_sol_v2
P=$1; S=$2; shift 2
L=/tmp/sol_lot_$(basename $P .txt).log
timeout 900 bash /tmp/godot_slot.sh $G --path $W --disable-vsync -- --captures=$W/$P --sortie=$W/$S --nouvelle --paisible --sans-particules --sans-mains --sans-hud --attente=120 "$@" > $L 2>&1
grep -E "LOT|ERROR|SCRIPT|Parse|SolV2" $L | head -20
