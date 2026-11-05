#!/usr/bin/env bash
# Banc de perf, PARTIE MESURE (fenêtre hors écran via godot_slot) : 6 lieux x jour/nuit x N répétitions (médiane faite par banc_perf.gd).
#   bash outils/banc_perf.sh [dossier_journaux]       puis   godot --headless --script res://outils/banc_perf.gd -- --logs=<dossier>
#   Variables : BANC_REPS (3), BANC_DUREE (12 s de mesure après 10 s de stabilisation), BANC_LIEUX ("temoin place foret grotte crypte combat"),
#   BANC_HEURES ("12 21"), GODOT. Répétitions ENTRELACÉES (toutes les cases, puis on recommence) : une charge passagère ne ruine pas une seule case.
#   Chaque lancement note, dans <lieu>_<heure>_<rep>.charge, le nombre MAXIMAL d'AUTRES Godot actifs (avant, pendant, après).
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
LOGS="${1:-$ICI/captures/perf/banc_logs}"; mkdir -p "$LOGS"
REPS="${BANC_REPS:-3}"; DUREE="${BANC_DUREE:-12}"
LIEUX="${BANC_LIEUX:-temoin place foret grotte crypte combat}"; HEURES="${BANC_HEURES:-12 21}"
SLOT=/tmp/godot_slot.sh
# Godot « réels » (hors enveloppe _console.exe) en cours sur la machine
nb_godot() { tasklist.exe /fo csv /nh 2>/dev/null | tr -d '\r' | grep -ai '^"Godot' | grep -avic console; }
pose_de() { case "$1" in temoin) echo "--pose=2.5,8.5,16,4";; place) echo "--pose=35,30,221,-8";; *) echo "";; esac; }
for rep in $(seq 1 "$REPS"); do
	for lieu in $LIEUX; do
		for h in $HEURES; do
			base="$LOGS/${lieu}_${h}_${rep}"; autres=$(nb_godot)
			# échantillon pendant la mesure : 1 de ces Godot est le nôtre
			( sleep 25; echo $(( $(nb_godot) - 1 )) > "$base.mi" ) &
			ECHANT=$!
			args=(--nouvelle --lieu="$lieu" --heure="$h" --duree="$DUREE"); [[ "$lieu" != "combat" ]] && args+=(--paisible)
			p="$(pose_de "$lieu")"; [[ -n "$p" ]] && args+=("$p")
			if [[ -f "$SLOT" ]]; then
				GODOT_TIMEOUT=420 bash "$SLOT" "$G" --path "$P" --disable-vsync --script res://outils/audit_mesure_lieu.gd -- "${args[@]}" > "$base.log" 2>&1
			else
				timeout 420 "$G" --path "$P" --disable-vsync --script res://outils/audit_mesure_lieu.gd -- "${args[@]}" --hors-ecran > "$base.log" 2>&1
			fi
			rc=$?
			kill "$ECHANT" 2>/dev/null; wait "$ECHANT" 2>/dev/null
			apres=$(nb_godot); mi=$(cat "$base.mi" 2>/dev/null || echo 0); rm -f "$base.mi"
			mx=$autres; [[ $mi -gt $mx ]] && mx=$mi; [[ $apres -gt $mx ]] && mx=$apres
			echo "$mx" > "$base.charge"
			echo "rep $rep $lieu $h : rc=$rc, autres Godot=$mx, $(grep -E '^LIEU [a-z]+ heure' "$base.log" | grep -o 'gpu_med=[0-9.]*' | head -1)"
		done
	done
done
echo "journaux : $LOGS"
