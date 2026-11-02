#!/usr/bin/env bash
# RÉGÉNÈRE les icônes d'objets (atlas assets/ui/icones/icones_16.png + icones_32.png + icones.json) depuis les modèles 3D, puis
# réimporte. Une seule commande, à relancer après l'arrivée de nouveaux modèles (armures « sol », objets…) :
#   bash outils/generer_icones.sh [--planche=C:/chemin/dossier]
# Le rendu exige une FENÊTRE (un Godot --headless ne dessine rien) : elle passe par godot_slot.sh (hors écran, 3 Godot max) s'il
# est là, sinon Godot est lancé directement. Variables : GODOT (exécutable), SLOT (script de créneau, défaut /tmp/godot_slot.sh).
set -eu
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT="${SLOT:-/tmp/godot_slot.sh}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
lancer() { if [ -f "$SLOT" ]; then GODOT_TIMEOUT="${GODOT_TIMEOUT:-900}" bash "$SLOT" "$G" "$@"; else "$G" "$@"; fi; }
lancer --path "$P" --script res://outils/generer_icones.gd -- "$@" 2>&1 | grep -E "ICONES|ATLAS|PLANCHE|ERROR|generer_icones" || true
lancer --headless --path "$P" --import >/dev/null 2>&1 || true
ls -l "$ICI/assets/ui/icones/"
