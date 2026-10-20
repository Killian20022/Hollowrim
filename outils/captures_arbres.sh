#!/usr/bin/env bash
# Captures du lot 2 (arbres), jour et nuit, pour toutes les poses de outils/poses_arbres.txt.
#   bash outils/captures_arbres.sh <dossier_sortie> [poses...]
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$OUT"
declare -A POSE; ORDRE=()
while read -r nom coords; do
	[[ -z "${nom:-}" || "$nom" == \#* ]] && continue
	POSE[$nom]="$coords"; ORDRE+=("$nom")
done < "$ICI/outils/poses_arbres.txt"
[[ $# -gt 0 ]] && ORDRE=("$@")
for p in "${ORDRE[@]}"; do
	for ph in ${PHASES:-jour nuit}; do
		h=""; [[ "$ph" == jour ]] && h="--heure=12"
		f="$OUT/${p}_${ph}.png"
		timeout 150 "$G" --path "$(wslpath -w "$ICI")" -- $h --capture="$(wslpath -w "$f")" --pose="${POSE[$p]}" \
			--nouvelle --paisible --sans-particules --sans-mains --attente=200 > "$f.log" 2>&1 || echo "échec $p $ph"
	done
done
grep -l "SCRIPT ERROR" "$OUT"/*.log 2>/dev/null | sed 's/^/ERREURS DE SCRIPT dans /'
