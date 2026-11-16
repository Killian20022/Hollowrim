#!/bin/bash
# Lot 2a : hôte + 2 invités (3 Godot headless) ; rejoindre en cours de partie, 3 joueurs, reconnexion, pertinence, interpolation.
# Usage : bash outils/test_rejoindre.sh   (GODOT_MAX=3)
cd "$(dirname "$0")/.." || exit 1
W=$(wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
PORT=${PORT:-24578}
L=/tmp/rejoindre; mkdir -p $L; rm -f $L/*.log
lance() { GODOT_MAX=3 GODOT_TIMEOUT=${DELAI:-240} bash $SLOT $G --headless --path "$W" --script res://outils/test_rejoindre.gd -- --role=$1 --port=$PORT > $L/$1.log 2>&1; }
lance hote & H=$!
for _ in $(seq 1 60); do grep -aq HOTE_PRET $L/hote.log 2>/dev/null && break; sleep 1; done
sleep 1
lance inv1 & I1=$!
for _ in $(seq 1 90); do grep -aq ETAT_MODIFIE $L/hote.log 2>/dev/null && break; sleep 1; done
lance inv2 & I2=$!
wait $I1; r1=$?; wait $I2; r2=$?; wait $H; rh=$?
for r in hote inv1 inv2; do echo "--- $r ---"; grep -a "TEST\|REJOINDRE\|ERROR\|SCRIPT" $L/$r.log; done
[ $rh = 0 ] && [ $r1 = 0 ] && [ $r2 = 0 ]
