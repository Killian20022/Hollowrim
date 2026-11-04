#!/usr/bin/env bash
# gen/abords : captures hors écran en UN lancement. bash outils/captures_gen_abords.sh <dossier> [options Godot...]
#   avant : ... --abords-anciens   (rochers, barrières, bordures, os et signes des bandits maison)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
POSES="$ICI/outils/poses_gen_abords.txt"
mkdir -p "$OUT"
GODOT_MAX=1 GODOT_TIMEOUT=900 bash /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" --disable-vsync -- --captures="$(wslpath -w "$POSES")" --sortie="$(wslpath -w "$OUT")" \
	--nouvelle --paisible --sans-particules --sans-mains --attente=120 "$@" > "$OUT/lot.log" 2>&1
grep -E "SCRIPT ERROR|Abords du|remplacements" "$OUT/lot.log" | head
