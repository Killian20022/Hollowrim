#!/bin/bash
# Captures du prototype coop (lot 1) : hôte + invité en RENDU RÉEL, fenêtres HORS ÉCRAN (godot_slot.sh ajoute --hors-ecran), jamais visibles.
# Écrit captures/coop/<moment>_<hote|invite>.png (moments : avatar, draugr, objet_avant, objet_apres, porte_avant, porte_apres).
# Usage : bash outils/captures_coop.sh [dossier_sortie]
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-captures/coop}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
W=$(wslpath -m "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/mnt/c/Users/lopezk19/Jeux/godot_slot.sh}
PORT=${PORT:-24580}
ARGS=(--sans-zone --sans-aide --coop-port=$PORT --coop-captures="$(wslpath -m "$OUT")")
export GODOT_MAX=2 GODOT_TIMEOUT=150
bash $SLOT $G --path "$W" --resolution 960x540 res://scenes/test_combat.tscn -- --coop=hote "${ARGS[@]}" > /tmp/coopcap_hote.log 2>&1 &
H=$!
sleep 6
bash $SLOT $G --path "$W" --resolution 960x540 res://scenes/test_combat.tscn -- --coop=127.0.0.1 "${ARGS[@]}" > /tmp/coopcap_invite.log 2>&1
RI=$?
wait $H; RH=$?
echo "hôte rc=$RH, invité rc=$RI"
grep -a "CAPTURE\|COOP \|SCRIPT ERROR" /tmp/coopcap_hote.log /tmp/coopcap_invite.log | sort | uniq -c | sort -rn | head -30
ls "$OUT"/*.png
