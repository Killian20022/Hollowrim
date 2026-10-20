#!/usr/bin/env bash
# Captures des intérieurs (lot « kit intérieur »), jour et nuit.
#   bash outils/captures_interieurs.sh <dossier_sortie> <bat> <nom_pose:x,z,lacet,tangage[:ouvert]> [...]
#   ex. : bash outils/captures_interieurs.sh /tmp/int halle a:0,2,0,-5 b:0,0,160,-10
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; BAT="${2:?bat}"; shift 2
mkdir -p "$OUT"
for spec in "$@"; do
	nom="${spec%%:*}"; reste="${spec#*:}"; pose="${reste%%:*}"; opt=""
	[[ "$reste" == *:* ]] && opt="--${reste#*:}"
	for ph in ${PHASES:-jour nuit}; do
		h=""; [[ "$ph" == jour ]] && h="--heure=12"
		f="$OUT/${BAT}_${nom}_${ph}.png"
		timeout 150 "$G" --path "$(wslpath -w "$ICI")" -- $h --capture="$(wslpath -w "$f")" --scenario=interieur --bat="$BAT" --ipose="$pose" $opt \
			--nouvelle --paisible --sans-particules --sans-mains --attente=60 > "$f.log" 2>&1 || echo "échec $nom $ph"
	done
done
grep -l "SCRIPT ERROR\|ERROR:" "$OUT"/*.log 2>/dev/null | sed 's/^/ERREURS dans /'
