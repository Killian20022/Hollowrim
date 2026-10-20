#!/usr/bin/env bash
# Captures de la grotte vitrine : bash outils/captures_grotte.sh <dossier> [poses...]
# Poses (s,décalage,lacet°,tangage°) : s = mètres le long du parcours (0-124), décalage + = droite, lacet 0 = vers le fond.
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$ICI/$OUT"
declare -A POSE=(
 [entree]="3,0,0,-8" [pente]="9,0,0,-6" [retour]="11,0,180,0" [boyau]="20,0,0,-3" [boyau2]="29,0,0,-4"
 [caverne]="37,2.5,0,-4" [lac]="41,1.5,-50,-6" [faille]="45,1.5,-25,5" [rai]="53,2.4,-55,-4" [lac2]="60,2.0,-60,0"
 [galerie]="69,0,0,-3" [galerie2]="76,0,0,-6" [marches]="82,0,0,-18" [camp_entree]="91,0,0,-2" [camp]="95,0,15,-6" [camp2]="98,-1,-35,-8"
 [camp3]="105,0,180,-6" [fond]="109,0,0,-2" [cristaux]="114,0,0,-4" [cristaux2]="118,1,-30,0"
)
SM="--sans-mains"; [[ -n "$MAINS" ]] && SM=""
NOMS=("$@"); [[ ${#NOMS[@]} -eq 0 ]] && NOMS=(entree pente boyau caverne lac rai galerie marches camp camp2 fond cristaux)
if [[ "${LOT:-1}" != 0 ]]; then  # un seul lancement (--captures) ; LOT=0 : un lancement par vue
  LOTF="$ICI/$OUT/_poses.txt"; : > "$LOTF"
  for n in "${NOMS[@]}"; do echo "$n grotte ${POSE[$n]:-$n} $([[ -z "$SM" ]] || echo sans-mains)" >> "$LOTF"; done
  timeout $((120 + 12 * ${#NOMS[@]})) "$G" --path "$(wslpath -w "$ICI")" -- --captures="$(wslpath -w "$LOTF")" --sortie="$(wslpath -w "$ICI/$OUT")" \
    --nouvelle --paisible --attente=40 > "$ICI/$OUT/lot.log" 2>&1 || echo "échec du lot"
  grep -E "^LOT" "$ICI/$OUT/lot.log"
  exit 0
fi
for n in "${NOMS[@]}"; do
  v="${POSE[$n]:-$n}"
  timeout 120 "$G" --path "$(wslpath -w "$ICI")" -- --nouvelle --paisible --scenario=grotte --gpose="$v" --capture="$(wslpath -w "$ICI/$OUT")\\${n}.png" --attente=40 $SM > "$ICI/$OUT/${n}.log" 2>&1 || echo "échec $n"
done
