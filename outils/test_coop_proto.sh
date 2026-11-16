#!/bin/bash
# Lot 1 multijoueur : 2 Godot headless sur localhost (hôte + invité) dans scenes/test_combat.tscn ; asserts « TEST ok/ECHEC » dans les logs.
# Usage : bash outils/test_coop_proto.sh   (GODOT_MAX=2 : deux instances en même temps)
cd "$(dirname "$0")/.." || exit 1
W=$(pwd -W 2>/dev/null || wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
PORT=${PORT:-24579}
ARGS=(--sans-zone --sans-aide --coop-test --coop-port=$PORT)
GODOT_MAX=2 GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" res://scenes/test_combat.tscn -- --coop=hote "${ARGS[@]}" > /tmp/coop_hote.log 2>&1 &
H=$!
sleep 6
GODOT_MAX=2 GODOT_TIMEOUT=120 bash $SLOT $G --headless --path "$W" res://scenes/test_combat.tscn -- --coop=127.0.0.1 "${ARGS[@]}" > /tmp/coop_invite.log 2>&1
RI=$?
wait $H; RH=$?
echo "--- hôte (rc=$RH) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/coop_hote.log
echo "--- invité (rc=$RI) ---"; grep -a "COOP\|TEST\|ERROR\|SCRIPT" /tmp/coop_invite.log
[ $RH = 0 ] && [ $RI = 0 ]
