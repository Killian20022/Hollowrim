#!/usr/bin/env bash
# PvP coop : 2 Godot HEADLESS (hôte + invité) — sorts, flèches, répulsion, saisie + lancer entre joueurs ; deux passes : PvP actif, puis --sans-pvp.
# Usage : bash outils/test_pvp.sh [pvp|sans]   (GODOT, PORT, GODOT_MAX>=2)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-24851}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_pvp"; mkdir -p "$LOG"
passe() {  # nom port drapeau
	local nom="$1" port="$2" drap="$3"
	lance() {  # role
		GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=300 bash "$SLOT" "$G" --headless --path "$P" res://outils/test_pvp.tscn -- --role="$1" --port="$port" $drap > "$LOG/$nom-$1.log" 2>&1
	}
	rm -f "$LOG/$nom"-*.log
	lance hote & local H=$!
	for _ in $(seq 1 60); do grep -aqE "HOTE_PRET|SCRIPT ERROR|Parse error" "$LOG/$nom-hote.log" 2>/dev/null && break; sleep 1; done
	sleep 1
	lance invite & local I=$!
	wait "$I"; local ri=$?; wait "$H"; local rh=$?
	echo "--- $nom : hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/$nom-hote.log"
	echo "--- $nom : invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/$nom-invite.log"
	[[ $rh = 0 && $ri = 0 ]] && grep -aq "TEST_PVP hote OK" "$LOG/$nom-hote.log" && grep -aq "TEST_PVP invite OK" "$LOG/$nom-invite.log"
}
rc=0
if [[ "${1:-}" != "sans" ]]; then passe pvp "$PORT" "" && echo "PASSE PVP : OK" || { echo "PASSE PVP : ÉCHEC"; rc=1; }; fi
if [[ "${1:-}" != "pvp" ]]; then passe sans "$((PORT+2))" "--sans-pvp" && echo "PASSE SANS-PVP : OK" || { echo "PASSE SANS-PVP : ÉCHEC"; rc=1; }; fi
[[ $rc = 0 ]] && echo "TEST PVP : OK" || echo "TEST PVP : ÉCHEC"
exit $rc
