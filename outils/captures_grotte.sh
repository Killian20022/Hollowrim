#!/usr/bin/env bash
# Captures de la grotte vitrine : bash outils/captures_grotte.sh <dossier> [poses...]
# Poses (s,décalage,lacet°,tangage°) : s GLOBAL = decalage de branche + mètres le long d'elle (T1 0, mine A 100, lac B 200, camp T2 300, cristaux C 400, cache H 500), décalage + = droite.
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$ICI/$OUT"
declare -A POSE=(
 [entree]="3,0,0,-8" [pente]="9,0,0,-6" [retour]="11,0,180,0" [boyau]="20,0,0,-3" [carrefour]="29.5,0,0,-4" [fourche]="31.5,0,-35,-5" [fourche2]="31.5,0,35,-5"
 [mine_acces]="103,1.5,0,-4" [mine_galerie]="114,0,0,-4" [mine_galerie2]="126,0,0,-4" [mine_chambre]="137,0,0,-6" [mine_chambre2]="146,-1,60,-6"
 [eboulis]="156,0,0,-5" [eboulis2]="160,0,-70,-5" [mine_retour]="167,0,0,-4" [mine_fin]="171,3,0,-3"
 [lac_acces]="203,0,0,-3" [lac_gorge]="210,0,0,-4" [lac_caverne]="214,0,-30,-6" [lac_rivage]="222,1,-50,-5" [faille]="224,1,-20,6" [corniche]="244,1,90,-6"
 [ilot]="231,-3,-95,-6" [ilot2]="236,-6,-90,-10" [lac_sortie]="252,0,0,-3" [lac_fin]="268,2,0,-3"
 [camp_entree]="300.5,0,0,-2" [camp]="304,0,15,-6" [camp2]="308,-1,-35,-8" [camp_corniche]="308,-1,75,-5" [camp3]="314,0,180,-6" [camp4]="311,3,-60,-8"
 [goulot]="401,0,0,-2" [cristaux]="412,0,0,-4" [cristaux2]="420,1,30,0" [cristaux3]="427,0,180,2"
 [mur_cache]="503,0,0,-3" [cache]="510,0,0,-3" [cache2]="515,0,180,-3"
)
SM="--sans-mains"; [[ -n "$MAINS" ]] && SM=""
NOMS=("$@"); [[ ${#NOMS[@]} -eq 0 ]] && NOMS=(entree boyau carrefour fourche mine_galerie mine_chambre eboulis lac_gorge lac_caverne faille corniche ilot camp camp_corniche camp3 goulot cristaux mur_cache cache)
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
