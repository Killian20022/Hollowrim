#!/bin/bash
# Lot 2c multijoueur : 2 Godot HEADLESS (hôte + invité, localhost) ; salle_active (union), coffre « premier arrivé », porte, contenant, instantané.
# Usage : bash outils/test_lieux.sh   (PORT=… ; GODOT_MAX=2 : deux instances en même temps)
cd "$(dirname "$0")/.." || exit 1
W=$(wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
PORT=${PORT:-24578}
GODOT_MAX=2 GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" --script res://outils/test_lieux.gd -- --role=hote --port=$PORT > /tmp/lieux_hote.log 2>&1 &
H=$!
for _ in $(seq 1 60); do grep -aq HOTE_PRET /tmp/lieux_hote.log 2>/dev/null && break; sleep 1; done
sleep 1
GODOT_MAX=2 GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" --script res://outils/test_lieux.gd -- --role=invite --port=$PORT > /tmp/lieux_invite.log 2>&1
RI=$?
wait $H; RH=$?
echo "--- hôte (rc=$RH) ---"; grep -a "TEST\|ERROR\|SCRIPT\|Parse" /tmp/lieux_hote.log
echo "--- invité (rc=$RI) ---"; grep -a "TEST\|ERROR\|SCRIPT\|Parse" /tmp/lieux_invite.log
[ $RH = 0 ] && [ $RI = 0 ]
