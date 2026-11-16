#!/usr/bin/env bash
# Lot 4b multijoueur : avatar distant complet — 2 Godot HEADLESS (hôte + invité) : position / vitesse / accroupi / garde / coup (clip + temps) /
# équipement + armure visibles / nom flottant / à terre + relevé / mort + réapparition / déconnexion.
# Usage : bash outils/test_avatars.sh   (GODOT, PORT [24821], GODOT_MAX>=2). Verdict lu dans les journaux (rc Godot peu fiable).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
PORT="${PORT:-24821}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_avatars"; mkdir -p "$LOG"
lance() {  # role
	GODOT_MAX="${GODOT_MAX:-2}" GODOT_TIMEOUT="${GODOT_TIMEOUT:-240}" bash "$SLOT" "$G" --headless --path "$P" res://outils/test_avatars.tscn -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 90); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; kill -0 $H 2>/dev/null || break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT\|Parse" "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT\|Parse" "$LOG/invite.log"
nko=$(grep -ac "TEST ECHEC\|SCRIPT ERROR\|Parse Error" "$LOG/hote.log" "$LOG/invite.log" | awk -F: '{s+=$2} END{print s+0}')
if [[ "$nko" = 0 ]] && grep -aq "TEST_AVATARS hote OK" "$LOG/hote.log" && grep -aq "TEST_AVATARS invite OK" "$LOG/invite.log"; then
	echo "TEST AVATARS : OK"; exit 0
fi
echo "TEST AVATARS : ÉCHEC"; exit 1
