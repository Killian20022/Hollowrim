#!/usr/bin/env bash
# props/remplacement : captures hors écran en UN lancement. bash outils/captures_props_remplacement.sh <dossier> [poses] [options Godot...]
#   avant : ... -- --sans-remplacement   (anciens props maison ; Quaternius de lots 2 inchangés)   |   --sans-props-q : aucun Quaternius
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; POSES="${2:-$ICI/outils/poses_props_remplacement.txt}"; shift; shift
mkdir -p "$OUT"
GODOT_MAX=1 bash /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" --disable-vsync -- --captures="$(wslpath -w "$POSES")" --sortie="$(wslpath -w "$OUT")" \
	--nouvelle --paisible --sans-particules --sans-mains --attente=120 "$@" > "$OUT/lot.log" 2>&1
grep -E "LOT|ERROR|SCRIPT" "$OUT/lot.log" | head
