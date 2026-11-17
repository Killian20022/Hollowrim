#!/usr/bin/env bash
# Lot 4d multijoueur : 2 Godot HEADLESS (hôte + invité) — démembrement identique, cadavre recalé, corps fouillé une seule fois, faune répliquée,
# effets de coup, plafond de ragdolls. Usage : bash outils/test_cadavres.sh   (GODOT, PORT (24841), GODOT_MAX>=2)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-24841}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_cadavres"; mkdir -p "$LOG"
lance() {  # role
	GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=240 bash "$SLOT" "$G" --headless --path "$P" res://outils/test_cadavres.tscn -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 120); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/invite.log"
if grep -aq "SCRIPT ERROR\|Parse Error" "$LOG/hote.log" "$LOG/invite.log"; then echo "TEST CADAVRES : ECHEC (erreurs de script)"; exit 1; fi
if grep -aq "TEST_CADAVRES hote OK" "$LOG/hote.log" && grep -aq "TEST_CADAVRES invite OK" "$LOG/invite.log"; then
	echo "TEST CADAVRES : OK"; exit 0
fi
echo "TEST CADAVRES : ECHEC"; exit 1
