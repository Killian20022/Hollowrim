#!/usr/bin/env bash
# Planches avant (1fff394, captures/batiments/base1fff) | après (captures/batiments/apres_v2) du lot 5, 2e passe :
# jour en haut, nuit en bas ; récapitulatifs jour et nuit (12 poses du village, paires avant/après).
#   bash outils/planches_bati_v2.sh
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
A="captures/batiments/base1fff"; B="captures/batiments/apres_v2"; O="captures/batiments/planches"
mkdir -p "$ICI/$O"
mont() { "$G" --headless --path "$P" --script outils/montage.gd -- "$@" > /dev/null 2>&1; }
for p in V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12 D1 T1 T2 T3 T4 Z1 Z2 Z3 Z4 Z5 G1 G2 G3 G4 G5 G6 G7 G8; do
	mont "res://$O/planche_${p}_v2.png" 2 480 "res://$A/${p}_jour.png" "res://$B/${p}_jour.png" "res://$A/${p}_nuit.png" "res://$B/${p}_nuit.png"
done
for ph in jour nuit; do
	f=()
	for p in V1 V2 V3 V4 V5 V6 V7 V8 V9 V10 V11 V12; do f+=("res://$A/${p}_$ph.png" "res://$B/${p}_$ph.png"); done
	mont "res://$O/planche_recap_${ph}_v2.png" 4 480 "${f[@]}"
done
