#!/bin/bash
# Captures de l'avatar distant (lot 4b) : hôte + invité en RENDU RÉEL, fenêtres HORS ÉCRAN (godot_slot.sh ajoute --hors-ecran), jamais visibles.
# Même scénario que outils/test_avatars.sh ; à chaque moment clé, chaque instance photographie l'avatar de L'AUTRE
# (caméra d'observation devant lui). Écrit captures/avatars/<moment>_<hote|invite>.png
# (moments : armure, nom, accroupi, garde, coup, a_terre, mort) ; le nom du fichier porte l'observateur.
# Usage : bash outils/captures_avatars.sh [dossier_sortie]    (PORT, GODOT, SLOT)
cd "$(dirname "$0")/.." || exit 1
OUT=${1:-captures/avatars}
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
W=$(wslpath -w "$(pwd)")
G=${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}
SLOT=${SLOT:-/tmp/godot_slot.sh}
[[ -f "$SLOT" ]] || cp ../godot_slot.sh "$SLOT" 2>/dev/null
PORT=${PORT:-24826}
LOG=${TMPDIR:-/tmp}/captures_avatars; mkdir -p "$LOG"; rm -f "$LOG"/*.log
export GODOT_MAX=${GODOT_MAX:-2} GODOT_TIMEOUT=${GODOT_TIMEOUT:-600}
lance() {  # role
	bash $SLOT $G --path "$W" --resolution 960x540 res://outils/test_avatars.tscn -- --role="$1" --port=$PORT --captures="$(wslpath -m "$OUT")" > "$LOG/$1.log" 2>&1
}
lance hote & H=$!
for _ in $(seq 1 90); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; kill -0 $H 2>/dev/null || break; sleep 1; done
sleep 1
lance invite
RI=$?
wait $H; RH=$?
echo "hôte rc=$RH, invité rc=$RI"
grep -a "CAPTURE\|TEST_AVATARS\|TEST ECHEC\|SCRIPT ERROR" "$LOG"/hote.log "$LOG"/invite.log | cut -c1-200
ls "$OUT"/*.png
