#!/usr/bin/env bash
# Planches avant | après du lot 6 : bash outils/planches_objets.sh  (lit captures/objets/avant et apres, écrit captures/objets/planches)
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"; P="$(wslpath -w "$ICI")"
A="$ICI/captures/objets/avant"; B="$ICI/captures/objets/apres"; S="$ICI/captures/objets/planches"; mkdir -p "$S"
planche() { # nom, vues...  (une ligne = avant à gauche | après à droite)
  local n="$1"; shift; local f=()
  for v in "$@"; do f+=("$(wslpath -w "$A/$v.png")" "$(wslpath -w "$B/$v.png")"); done
  "$G" --headless --path "$P" --script res://outils/montage.gd -- "$(wslpath -w "$S/$n.png")" 2 480 "${f[@]}" >/dev/null 2>&1
}
planche torche_gros_plans torche_repos torche_nuit torche_crypte torche_joueur torche_garde torche_frappe
planche epee_gros_plans epee_repos epee_dessus epee_face epee_crypte epee_garde epee_frappe
planche poignets_gauche poignet_g_repos poignet_g_armer poignet_g_charge poignet_g_frappe poignet_g_garde poignet_g_encaisse
planche poignets_droit poignet_d_repos poignet_d_armer poignet_d_charge poignet_d_frappe poignet_d_garde poignet_d_encaisse
planche jour_poses jour_repos jour_armer jour_charge jour_frappe jour_garde jour_encaisse
planche nuit_poses nuit_repos nuit_armer nuit_charge nuit_frappe nuit_garde nuit_encaisse
planche crypte_poses crypte_repos crypte_armer crypte_charge crypte_frappe crypte_garde crypte_encaisse
