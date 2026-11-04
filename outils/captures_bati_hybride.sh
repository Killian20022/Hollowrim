#!/usr/bin/env bash
# Captures AVANT/APRÈS du bâti hybride : bash outils/captures_bati_hybride.sh <dossier_sortie> avant|apres [poses.txt]
# (« avant » = `--bati-ancien` ; « apres » = mode par défaut). Un seul lancement de Godot (hors écran) pour toutes les vues, jour et crépuscule.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
POSES="${3:-$ICI/outils/poses_bati_hybride.txt}"
LOTF="$OUT/_poses.txt"; : > "$LOTF"
while read -r nom coords; do
	[[ -z "${nom:-}" || "$nom" == \#* ]] && continue
	echo "${nom}_jour monde $coords heure=12" >> "$LOTF"
	echo "${nom}_crepuscule monde $coords heure=17.5" >> "$LOTF"
done < "$POSES"
OPT=""; [[ "${2:-apres}" == avant ]] && OPT="--bati-ancien"
GODOT_MAX=1 GODOT_TIMEOUT=900 /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" -- --captures="$(wslpath -w "$LOTF")" --sortie="$(wslpath -w "$OUT")" \
	--nouvelle --paisible --sans-particules --sans-mains --attente=200 $OPT --hors-ecran > "$OUT/lot.log" 2>&1 || echo "échec du lot"
grep -E "^LOT|SCRIPT ERROR|Parse Error" "$OUT/lot.log" | head
