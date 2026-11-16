#!/usr/bin/env bash
# Integration lot 4 : 2 Godot HEADLESS (hote + invite) — combat a l echelle 2 joueurs, fleche, corps fouillable une fois, avatar equipe.
# Usage : bash outils/test_integration4.sh   (GODOT, PORT (24912), GODOT_MAX>=2)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-24912}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_integration4"; mkdir -p "$LOG"
lance() {  # role
	GODOT_MAX="${GODOT_MAX:-2}" GODOT_TIMEOUT=240 bash "$SLOT" "$G" --headless --path "$P" res://outils/test_integration4.tscn -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 120); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/invite.log"
if grep -aq "SCRIPT ERROR\|Parse Error" "$LOG/hote.log" "$LOG/invite.log"; then echo "TEST INTEGRATION4 : ECHEC (erreurs de script)"; exit 1; fi
if grep -aq "TEST_INTEGRATION4 hote OK" "$LOG/hote.log" && grep -aq "TEST_INTEGRATION4 invite OK" "$LOG/invite.log"; then
	echo "TEST INTEGRATION4 : OK"; exit 0
fi
echo "TEST INTEGRATION4 : ECHEC"; exit 1
