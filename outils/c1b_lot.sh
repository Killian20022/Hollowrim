#!/bin/bash
# usage: c1b_lot.sh (C1b : est/sud + dalles) <poses> <dossier de sortie> [options]
G=/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe; W=C:/Users/lopezk19/Jeux/nordique_C1b
P=$1; S=$2; shift 2
L=/tmp/c1b_lot_$(basename $P .txt).log
timeout 900 bash /tmp/godot_slot.sh $G --path $W --disable-vsync -- --captures=$W/$P --sortie="$S" --nouvelle --paisible --sans-particules --sans-mains --sans-hud --attente=120 "$@" > $L 2>&1
grep -E "LOT|ERROR|SCRIPT|Parse|SolV2" $L | head -20
