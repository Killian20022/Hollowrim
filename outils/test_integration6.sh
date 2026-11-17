#!/usr/bin/env bash
# Integration lot 7 (final) : hote + invite sous 100 ms / 5 % de perte, l invite frappe et prend un coffre, l hote est tue : personnage sauvegarde + message au titre. Usage : bash outils/test_integration6.sh   (PORT (25301), GODOT_MAX>=2)

set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT="${PORT:-25301}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_integration6"; mkdir -p "$LOG"
lance() {  # role
	GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=240 bash "$SLOT" "$G" --headless --path "$P" res://outils/test_integration6.tscn -- --role="$1" --port="$PORT" --sim-latence=100 --sim-gigue=20 --sim-perte=5 > "$LOG/$1.log" 2>&1
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 60); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; grep -a "TEST\|ERROR\|SCRIPT" "$LOG/invite.log"
# verdict lu dans les journaux (le code de sortie de la console Godot n'est pas fiable)
if grep -aq "TEST_INTEGRATION6 hote OK" "$LOG/hote.log" && grep -aq "TEST_INTEGRATION6 invite OK" "$LOG/invite.log" \
		&& ! grep -aq "TEST ECHEC\|SCRIPT ERROR\|Parse Error" "$LOG/hote.log" "$LOG/invite.log"; then
	echo "TEST INTEGRATION6 : OK"; exit 0
fi
echo "TEST INTEGRATION6 : ÉCHEC"; exit 1
