#!/usr/bin/env bash
# Banc réseau : 2 Godot HEADLESS (hôte + invité) sur localhost ; prouve connexion, liste des joueurs, évènement, déconnexion.
#   bash outils/banc_reseau.sh          (GODOT=… pour changer l'exe ; PORT=… ; GODOT_MAX = créneaux godot_slot, 2 minimum)
# Code de sortie 0 si les deux instances impriment « BANC_RESEAU … OK ».
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
PORT="${PORT:-24577}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/banc_reseau"; mkdir -p "$LOG"
lance() {  # role
	if [[ -f "$SLOT" ]]; then
		GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT=90 bash "$SLOT" "$G" --headless --path "$P" --script res://outils/banc_reseau.gd -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
	else
		timeout 90 "$G" --headless --path "$P" --script res://outils/banc_reseau.gd -- --role="$1" --port="$PORT" > "$LOG/$1.log" 2>&1
	fi
}
rm -f "$LOG"/*.log
lance hote & H=$!
for _ in $(seq 1 60); do grep -q HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
sleep 1
lance invite & I=$!
wait "$I"; ri=$?; wait "$H"; rh=$?
echo "--- hôte (rc=$rh) ---"; cat "$LOG/hote.log"
echo "--- invité (rc=$ri) ---"; cat "$LOG/invite.log"
if [[ $rh = 0 && $ri = 0 ]] && grep -q "BANC_RESEAU hote OK" "$LOG/hote.log" && grep -q "BANC_RESEAU invite OK" "$LOG/invite.log"; then
	echo "BANC RÉSEAU : OK"; exit 0
fi
echo "BANC RÉSEAU : ÉCHEC"; exit 1
