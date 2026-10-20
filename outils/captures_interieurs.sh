#!/usr/bin/env bash
# Captures des intérieurs (lot « kit intérieur »), en un seul lancement (captures groupées, docs/SOCLE_TECHNIQUE.md § 7).
#   bash outils/captures_interieurs.sh <dossier_sortie> [fichier_poses]       (défaut : outils/poses_interieurs.txt)
# Format des poses : `nom interieur x,z,lacet°,tangage° bat=<id> [ouvert] [heure=12]` (repère du bâtiment ; lacet 0 = vers -Z ;
# z > demi-largeur = dehors). Jour = heure=12 ; sans option = nuit. PHASES="jour nuit" duplique chaque ligne (défaut : les deux).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; POSES="${2:-$ICI/outils/poses_interieurs.txt}"
mkdir -p "$OUT"
TMP="$OUT/poses_lot.txt"; : > "$TMP"
while read -r nom type reste; do
	[[ -z "${nom:-}" || "$nom" == \#* ]] && continue
	for ph in ${PHASES:-jour nuit}; do
		if [[ "$ph" == jour ]]; then echo "${nom}_jour $type $reste heure=12" >> "$TMP"; else echo "${nom}_nuit $type $reste" >> "$TMP"; fi
	done
done < "$POSES"
"$G" --path "$(wslpath -w "$ICI")" --disable-vsync -- --captures="$(wslpath -w "$TMP")" --sortie="$(wslpath -w "$OUT")" \
	--nouvelle --paisible --sans-particules --sans-mains --attente=120 > "$OUT/lot.log" 2>&1
grep -E "LOT|ERROR" "$OUT/lot.log" | head
