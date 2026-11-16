#!/usr/bin/env bash
# Lot 5b : captures de l'écran Multijoueur, rendu RÉEL mais hors écran (godot_slot.sh ajoute --hors-ecran : fenêtre à (-32000,-32000)).
# Le vrai écran titre est lancé en mode test (--test-titre=multi:<dossier>) : choix, Héberger, Rejoindre (adresse invalide), salon
# (vrai port local, refermé). Sortie : captures/ecran_multi/ecran_multi_*.png.
#   bash outils/captures_ecran_multi.sh [dossier_sortie]        (GODOT=… ; PORT=<n> de la plage 25031-25049 ; GODOT_MAX=4)
set -u
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT="${SLOT:-/tmp/godot_slot.sh}"
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
SORTIE="${1:-$P\\captures\\ecran_multi}"
mkdir -p "$ICI/captures/ecran_multi"
JOURNAL="$ICI/captures/ecran_multi/journal.log"
GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=240 bash "$SLOT" "$G" --path "$P" -- "--test-titre=multi:${PORT:-25035}:$SORTIE" > "$JOURNAL" 2>&1
grep -a "capture\|SCRIPT ERROR" "$JOURNAL"
n=$(ls "$ICI/captures/ecran_multi"/ecran_multi_*.png 2>/dev/null | wc -l)
echo "$n capture(s) dans captures/ecran_multi"
[[ "$n" -ge 2 ]] && ! grep -qa "SCRIPT ERROR" "$JOURNAL"
