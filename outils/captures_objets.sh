#!/usr/bin/env bash
# Captures du lot 6 (objets tenus) : bash outils/captures_objets.sh <dossier de sortie sous captures/objets>
# Une fenêtre Godot par vue (--camera-main n'existe qu'en capture simple). Jour = --heure=12, nuit = défaut.
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"; P="$(wslpath -w "$ICI")"
S="$ICI/captures/objets/$1"; mkdir -p "$S"; SW="$(wslpath -w "$S")"
COM="--nouvelle --paisible --attente=70"
vue() { # nom, arguments...
  local n="$1"; shift
  timeout 120 "$G" --path "$P" --disable-vsync -- --capture="$SW\\$n.png" $COM "$@" >/dev/null 2>&1 || echo "ECHEC $n"
}
CR="--scenario=crypte --cpose=-4,-9,90,0"
for p in repos armer charge frappe garde encaisse; do
  vue torche_$p      --mains=$p --heure=12 --camera-main=g,dehors,0.55
  vue epee_$p        --mains=$p --heure=12 --camera-main=d,dehors,0.5
  vue poignet_d_$p   --mains=$p --heure=12 --camera-main=d,dedans,0.35
  vue poignet_g_$p   --mains=$p --heure=12 --camera-main=g,dedans,0.35
  vue jour_$p        --mains=$p --heure=12
  vue nuit_$p        --mains=$p
  vue crypte_$p      --mains=$p $CR
done
vue torche_nuit    --mains=repos --camera-main=g,dehors,0.55
vue torche_joueur  --mains=repos --camera-main=g,joueur,0.5
vue torche_crypte  --mains=repos $CR --camera-main=g,dehors,0.55
vue epee_crypte    --mains=repos $CR --camera-main=d,dehors,0.5
vue epee_dessus    --mains=repos --heure=12 --camera-main=d,dessus,0.5
vue epee_face      --mains=repos --heure=12 --camera-main=d,face,0.5
