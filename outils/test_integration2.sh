#!/bin/bash
# Intégration lot 2 (2a+2b+2c) : 2 Godot headless (hôte + invité) dans scenes/test_integration2.tscn ; asserts « TEST ok/ECHEC » dans les logs.
# Usage : bash outils/test_integration2.sh   (GODOT_MAX=${GODOT_MAX:-4} : deux instances en même temps ; headless, jamais de fenêtre)
cd "$(dirname "$0")/.." || exit 1
W=$(pwd -W 2>/dev/null || wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
PORT=${PORT:-24751}
GODOT_MAX=${GODOT_MAX:-4} GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" res://scenes/test_integration2.tscn -- --role=hote --port=$PORT > /tmp/int2_hote.log 2>&1 &
H=$!
for _ in $(seq 1 90); do grep -aq HOTE_PRET /tmp/int2_hote.log 2>/dev/null && break; sleep 1; done
sleep 1
GODOT_MAX=${GODOT_MAX:-4} GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" res://scenes/test_integration2.tscn -- --role=invite --port=$PORT > /tmp/int2_invite.log 2>&1
RI=$?
wait $H; RH=$?
echo "--- hôte (rc=$RH) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/int2_hote.log
echo "--- invité (rc=$RI) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/int2_invite.log
[ $RH = 0 ] && [ $RI = 0 ]
