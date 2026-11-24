#!/bin/bash
# Lot 2b multijoueur : 2 Godot headless (hôte + invité) dans scenes/test_monde_vivant.tscn ; asserts « TEST ok/ECHEC » dans les logs.
# Usage : bash outils/test_monde_vivant.sh   (GODOT_MAX=${GODOT_MAX:-4} : deux instances en même temps ; headless, jamais de fenêtre)
cd "$(dirname "$0")/.." || exit 1
W=$(pwd -W 2>/dev/null || wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
PORT=${PORT:-24741}
GODOT_MAX=${GODOT_MAX:-4} GODOT_TIMEOUT=400 bash $SLOT $G --headless --path "$W" res://scenes/test_monde_vivant.tscn -- --role=hote --port=$PORT > /tmp/mv_hote.log 2>&1 &
H=$!
for _ in $(seq 1 90); do grep -aq HOTE_PRET /tmp/mv_hote.log 2>/dev/null && break; sleep 1; done
sleep 1
GODOT_MAX=${GODOT_MAX:-4} GODOT_TIMEOUT=400 bash $SLOT $G --headless --path "$W" res://scenes/test_monde_vivant.tscn -- --role=invite --port=$PORT > /tmp/mv_invite.log 2>&1
RI=$?
wait $H; RH=$?
echo "--- hôte (rc=$RH) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/mv_hote.log
echo "--- invité (rc=$RI) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/mv_invite.log
[ $RH = 0 ] && [ $RI = 0 ]
