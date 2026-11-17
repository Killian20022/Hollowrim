#!/usr/bin/env bash
# LOT 7 : tests de latence / perte / déconnexion, N processus Godot HEADLESS sur localhost (ports 25201-25299).
#   bash outils/test_resilience.sh [motif]     motifs : controle, cond_100, cond_250, depart, hote_perdu, reconnexion, depart_enet, hote_perdu_enet (détection par ENet seul), debit2, debit4
# Variables : GODOT, PORT0 (25210), GODOT_MAX (créneaux godot_slot, 4 : l'hôte + 3 invités tournent ensemble ; 2 suffit sauf debit4).
# Verdict lu dans les journaux (rc Godot non fiable) : « TEST_RESILIENCE <role> OK » sur chaque processus ET aucun « TEST ECHEC » / « SCRIPT ERROR ».
# Les lignes « METRIQUE » sont recopiées dans $LOG/metriques.txt (voir docs/reseau_lot7.md).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -m "$ICI")"
PORT0="${PORT0:-25210}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
LOG="${TMPDIR:-/tmp}/test_resilience"; mkdir -p "$LOG"
MOTIF="${1:-}"
[[ -z "$MOTIF" ]] && : > "$LOG/metriques.txt"

lance() {  # role scn port idx nb_inv délai [options sim]
	local role="$1" scn="$2" port="$3" idx="$4" nb="$5" delai="$6"; shift 6
	GODOT_MAX="${GODOT_MAX:-4}" GODOT_TIMEOUT="$delai" bash "$SLOT" "$G" --headless --path "$P" res://outils/test_resilience.tscn -- --role="$role" --scn="$scn" --port="$port" --idx="$idx" --invites="$nb" "$@" > "$LOG/$scn.$port.$role$idx.log" 2>&1
}

# scénario : nom port nb_invités délai [options sim...]
scenario() {
	local nom="$1" scn="$2" port="$3" nb="$4" delai="$5"; shift 5
	[[ -n "$MOTIF" && "$MOTIF" == =* && "$nom" != "${MOTIF#=}" ]] && return 0   # motif « =debit4 » : nom exact
	[[ -n "$MOTIF" && "$MOTIF" != =* && "$nom" != *"$MOTIF"* ]] && return 0
	[[ "$nom" == *sansgel* && "$MOTIF" != *sansgel* ]] && return 0   # contre-épreuve : ÉCHOUE exprès (erreurs de draugr.gd sans gel des ennemis)
	echo "=== $nom ($scn, $nb invité(s), port $port) $* ==="
	rm -f "$LOG/$scn.$port".*.log
	lance hote "$scn" "$port" 0 "$nb" "$delai" "$@" & local H=$!
	for _ in $(seq 1 180); do grep -aq HOTE_PRET "$LOG/$scn.$port.hote0.log" 2>/dev/null && break; sleep 1; done
	sleep 1
	local PIDS=()
	for i in $(seq 1 "$nb"); do lance invite "$scn" "$port" "$i" "$nb" "$delai" "$@" & PIDS+=($!); sleep 2; done
	for p in "${PIDS[@]}"; do wait "$p"; done
	wait "$H"
	local ok=1
	for f in "$LOG/$scn.$port".*.log; do
		role=$(basename "$f" | sed -E 's/.*\.(hote|invite)([0-9]+)\.log/\1\2/')
		if grep -aq "SCRIPT ERROR\|Parse Error" "$f"; then echo "  [$role] erreurs de script :"; grep -a -A3 "SCRIPT ERROR\|Parse Error" "$f" | head -12; ok=0; fi
		if grep -aq "TEST ECHEC" "$f"; then grep -a "TEST ECHEC" "$f"; ok=0; fi
		if ! grep -aq "TEST_RESILIENCE .* OK" "$f"; then echo "  [$role] pas de verdict OK"; ok=0; fi
		grep -a "METRIQUE" "$f" | sed "s/^/[$nom] /" >> "$LOG/metriques.txt"
	done
	if [[ $ok = 1 ]]; then echo "  -> $nom : OK"; else echo "  -> $nom : ECHEC"; NKO=$((NKO+1)); fi
}
NKO=0
scenario controle    conditions  $((PORT0+0)) 1 240
scenario cond_100    conditions  $((PORT0+1)) 1 300 --sim-latence=100 --sim-gigue=20 --sim-perte=5
scenario cond_250    conditions  $((PORT0+2)) 1 360 --sim-latence=250 --sim-gigue=40 --sim-perte=10
scenario depart      depart      $((PORT0+3)) 1 200
scenario hote_perdu  hote_perdu  $((PORT0+4)) 1 200
scenario reconnexion reconnexion $((PORT0+5)) 1 300
scenario depart_enet     depart      $((PORT0+8)) 1 200 --silence=999
scenario hote_perdu_sansgel hote_perdu $((PORT0+13)) 1 260 --sans-gel
scenario hote_perdu_enet hote_perdu  $((PORT0+9)) 1 260 --silence=999
scenario debit2_nu       debit       $((PORT0+10)) 1 200 --pnj=0 --ennemis=0
scenario debit2_pnj      debit       $((PORT0+11)) 1 200 --pnj=12 --ennemis=0
scenario debit2_ennemis  debit       $((PORT0+12)) 1 200 --pnj=0 --ennemis=6
scenario debit2      debit       $((PORT0+6)) 1 200
scenario debit4      debit       $((PORT0+7)) 3 240
echo "--- métriques ---"; cat "$LOG/metriques.txt"
if [[ $NKO = 0 ]]; then echo "TEST RESILIENCE : OK"; exit 0; fi
echo "TEST RESILIENCE : $NKO ECHEC(S)"; exit 1
