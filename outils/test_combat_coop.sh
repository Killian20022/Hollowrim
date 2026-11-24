#!/usr/bin/env bash
# Lot 4a multijoueur : 2 Godot HEADLESS (hôte + invité) — ciblage multi-joueurs, coups de l invité validés par l hôte, coups ennemis résolus par la victime, échelle PV,
# marionnettes, mort répliquée. Usage : bash outils/test_combat_coop.sh   (GODOT, PORT, GODOT_MAX>=2)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-24811}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_combat_coop"; mkdir -p "$LOG"
lance() {  # role
	GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=360 bash "$SLOT" "$G" --headless --path "$P" res://outils/test_combat_coop.tscn -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 60); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/invite.log"
if [[ $rh = 0 && $ri = 0 ]] && grep -aq "TEST_COMBAT_COOP hote OK" "$LOG/hote.log" && grep -aq "TEST_COMBAT_COOP invite OK" "$LOG/invite.log"; then
	echo "TEST COMBAT COOP : OK"; exit 0
fi
echo "TEST COMBAT COOP : ÉCHEC"; exit 1
