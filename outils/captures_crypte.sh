#!/usr/bin/env bash
# Captures de l'intérieur de la crypte : bash outils/captures_crypte.sh <dossier> [poses...]
# Poses (repère crypte : x,z,lacet°,tangage°) dans POSES ci-dessous ; SANS_TORCHE=1 ajoute la variante sans torche.
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; shift
mkdir -p "$ICI/$OUT"
declare -A POSE=(
 [entree]="0,3,0,-5" [couloir]="0,-7,0,0" [couloir2]="0,-12,0,0" [salle]="0,-19.5,0,-5" [salle2]="-5,-27,-35,0"
 [sortie]="0,0.5,180,-3" [sarco]="0,-47.2,0,-12" [niche]="0,-12,-90,0" [piliers]="5.5,-31,125,-5" [alcove]="-6,-25,90,-10" [herse]="0,-36,0,0" [tombe]="0,-43,0,-5" [tombe2]="-6,-55,-60,0"
 [gp_mur]="0.3,-9.5,90,0" [gp_mur2]="-0.3,-9.5,-90,-10" [gp_sol]="0,-5,0,-60" [gp_pilier]="2.5,-31,90,0" [gp_tombe]="5,-43,90,0" [gp_sarco]="0,-45,0,-25"
)
NOMS=("$@"); [[ ${#NOMS[@]} -eq 0 ]] && NOMS=(entree couloir couloir2 salle salle2 piliers alcove herse tombe tombe2)
for n in "${NOMS[@]}"; do
  for v in ${VARIANTES:-torche sans}; do
    extra=""; [[ $v == sans ]] && extra="--torche-eteinte"
    timeout 120 "$G" --path "$(wslpath -w "$ICI")" -- --capture="$(wslpath -w "$ICI/$OUT")\\${n}_${v}.png" --nouvelle --scenario=crypte --cpose="${POSE[$n]}" $extra --paisible --attente=60 > "$ICI/$OUT/${n}_${v}.log" 2>&1 || echo "échec $n $v"
  done
done
