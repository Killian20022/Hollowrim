#!/usr/bin/env bash
# Mesure A/B du bâti hybride (mesure_perf.gd, fenêtre hors écran, vsync off) : bash outils/perf_bati_hybride.sh [series]
# Pour chaque pose : AVANT (--bati-ancien) puis APRÈS (défaut), en alternance, `series` fois (défaut 2).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-2}"
for pose in "place 42.5,38.7,-132,0" "rue 40,56,-146,8" "haute_rue 44,66,-160,6"; do
	set -- $pose
	for s in $(seq 1 "$N"); do
		for mode in avant apres; do
			OPT=""; [[ $mode == avant ]] && OPT="--bati-ancien"
			r=$(GODOT_MAX=1 GODOT_TIMEOUT=240 /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" --disable-vsync --resolution 1280x720 --script res://outils/mesure_perf.gd -- \
				--nouvelle --paisible --pose="$2" $OPT --hors-ecran 2>&1 | grep "^MESURE")
			echo "$1 $mode $s $r"
		done
	done
done
