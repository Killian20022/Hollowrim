#!/usr/bin/env bash
# Captures de l'intérieur de la crypte : bash outils/captures_crypte.sh <dossier> [poses...]
# Poses (repère crypte : x,z,lacet°,tangage°) dans POSES ci-dessous ; VARIANTES="torche sans" (défaut), LOT=0 : un lancement par vue.
# Par défaut UN seul lancement de Godot pour toutes les vues (--captures, docs/SOCLE_TECHNIQUE.md).
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$ICI/$OUT"
declare -A POSE=(
 [entree]="0,3,0,-5" [couloir]="0,-7,0,0" [couloir2]="0,-12,0,0" [salle]="0,-19.5,0,-5" [salle2]="-5,-27,-35,0"
 [sortie]="0,0.5,180,-3" [sarco]="0,-47.2,0,-12" [niche]="0,-12,-90,0" [piliers]="5.5,-31,125,-5" [alcove]="-6,-25,90,-10" [herse]="0,-36,0,0" [tombe]="0,-43,0,-5" [tombe2]="-6,-55,-60,0"
 [oss_n]="-35,-10,0,-5" [oss_sq]="-35,-24.5,0,-3" [oss_sq2]="-35.5,-26,20,-2" [oss_arch]="-32.5,-19.5,-90,-2" [oss_o]="-27,-20,90,-5" [oss_se]="-26,-10,43,-5" [rel_n]="-38,-51.5,0,-5" [rel_o]="-27,-60,90,-5" [tresor]="-52,-59,90,-5"
 [g0]="10,-29.7,-90,-3" [g1a]="26,-29.7,-90,-5" [g1b]="35,-19,0,-5" [g4]="62,-30,-90,-5" [g6]="40,-9.6,-90,0" [d1_haut]="34,-38,0,-22" [d1_bas]="34,-47,0,-5,-4"
 [lb1]="34,-55,0,-5,-6" [lb2]="20,-66,90,0,-6" [lb3]="-22,-66,90,-5,-6" [arene]="0,-60,0,-8" [arene2]="-11,-67,-60,-8" [anti]="0,-44,0,-5" [sarco2]="0,-66,0,-12"
 [rit]="0,-43,0,-4" [rit2]="5.5,-43.5,35,-4" [rit3]="-5.5,-52,-130,-6" [cor]="0,-5.5,0,-2" [cor2]="1.0,-15,-25,-3"
 [rit4]="1.0,-51.5,120,-6" [rit_5]="0.05,-43,0,-4" [rit4_5]="1.05,-51.5,120,-6" [cor_5]="0.05,-5.5,0,-2"
 [sol_rit]="2,-44,20,-55" [sol_cor]="0.5,-4.5,0,-50"
 [gp_mur]="0.3,-9.5,90,0" [gp_mur2]="-0.3,-9.5,-90,-10" [gp_sol]="0,-5,0,-60" [gp_pilier]="2.5,-31,90,0" [gp_tombe]="5,-43,90,0" [gp_sarco]="0,-45,0,-25"
)
NOMS=("$@"); [[ ${#NOMS[@]} -eq 0 ]] && NOMS=(entree couloir couloir2 salle salle2 piliers alcove herse tombe tombe2)
if [[ "${LOT:-1}" != 0 ]]; then
  LOTF="$ICI/$OUT/_poses.txt"; : > "$LOTF"
  for n in "${NOMS[@]}"; do
    for v in ${VARIANTES:-torche sans}; do
      extra=""; [[ $v == sans ]] && extra="torche-eteinte"
      echo "${n}_${v} crypte ${POSE[$n]} $extra" >> "$LOTF"
    done
  done
  timeout $((3600 + 12 * ${#NOMS[@]} * 2)) bash /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" -- --captures="$(wslpath -w "$LOTF")" --sortie="$(wslpath -w "$ICI/$OUT")" \
    --nouvelle --paisible --attente=60 ${CAP_ARGS:-} > "$ICI/$OUT/lot.log" 2>&1 || echo "échec du lot"
  grep -E "^LOT" "$ICI/$OUT/lot.log"
  exit 0
fi
for n in "${NOMS[@]}"; do
  for v in ${VARIANTES:-torche sans}; do
    extra=""; [[ $v == sans ]] && extra="--torche-eteinte"
    timeout 120 "$G" --path "$(wslpath -w "$ICI")" -- --capture="$(wslpath -w "$ICI/$OUT")\\${n}_${v}.png" --nouvelle --scenario=crypte --cpose="${POSE[$n]}" --couvre=s1,s2,s3,secret,herse $extra --paisible --attente=60 > "$ICI/$OUT/${n}_${v}.log" 2>&1 || echo "échec $n $v"
  done
done
