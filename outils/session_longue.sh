#!/usr/bin/env bash
# Session longue : hôte + N invités (VRAI monde, headless) avec simulateur réseau. Usage :
#   bash outils/session_longue.sh [--latence=40 --gigue=20 --perte=2] [--invites=3] [--echelle=1.0] [--port=25901] [--dossier=/tmp/session_longue]
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"; P="$(wslpath -m "$ICI")"
LAT=40; GIG=20; PER=2; N=3; ECH=1.0; PORT=25901; LOG=/tmp/session_longue
for a in "$@"; do case "$a" in --latence=*) LAT=${a#*=};; --gigue=*) GIG=${a#*=};; --perte=*) PER=${a#*=};; --invites=*) N=${a#*=};; --echelle=*) ECH=${a#*=};; --port=*) PORT=${a#*=};; --dossier=*) LOG=${a#*=};; esac; done
mkdir -p "$LOG"; rm -f "$LOG"/*.log
SIM="--sim-latence=$LAT --sim-gigue=$GIG --sim-perte=$PER"
lance() { # role [attendus]
	GODOT_MAX=8 GODOT_TIMEOUT=1500 bash /tmp/godot_slot.sh "$G" --headless --path "$P" --script res://outils/session_longue.gd -- --nouvelle --role="$1" --port=$PORT --attendus=${2:-$N} --echelle=$ECH $SIM > "$LOG/$1.log" 2>&1
}
lance hote $N & PH=$!
for _ in $(seq 1 300); do grep -aq HOTE_PRET "$LOG/hote.log" 2>/dev/null && break; sleep 1; done
for i in $(seq 1 $N); do lance i$i & eval "PI$i=$!"; sleep 2; done
wait
for r in hote $(seq -f 'i%g' 1 $N); do echo "--- $r ---"; grep -a "SL \|SL_SESSION\|SCRIPT ERROR\|Parse Error" "$LOG/$r.log" | grep -av "SL ok" | head -40; done
