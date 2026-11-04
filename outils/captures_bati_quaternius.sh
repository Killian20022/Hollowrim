#!/usr/bin/env bash
# Captures AVANT/APRÈS de l'essai bâti Quaternius : bash outils/captures_bati_quaternius.sh <dossier_sortie> [avec]
# (« avec » = option --bati-quaternius ; sinon rendu d'origine). Un seul lancement de Godot pour toutes les vues, jour et crépuscule.
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
LOTF="$OUT/_poses.txt"; : > "$LOTF"
while read -r nom coords; do
	[[ -z "${nom:-}" || "$nom" == \#* ]] && continue
	echo "${nom}_jour monde $coords heure=12" >> "$LOTF"
	echo "${nom}_crepuscule monde $coords heure=17.5" >> "$LOTF"
done < "$ICI/outils/poses_bati_quaternius.txt"
OPT=""; [[ "${2:-}" == avec ]] && OPT="--bati-quaternius"
GODOT_MAX=1 GODOT_TIMEOUT=600 /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" -- --captures="$(wslpath -w "$LOTF")" --sortie="$(wslpath -w "$OUT")" \
	--nouvelle --paisible --sans-particules --sans-mains --attente=200 $OPT > "$OUT/lot.log" 2>&1 || echo "échec du lot"
grep -E "^LOT|SCRIPT ERROR|Parse Error" "$OUT/lot.log" | head
