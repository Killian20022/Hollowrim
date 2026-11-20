#!/usr/bin/env bash
# Banc FPS du JEU EXPORTÉ (ou de l'éditeur) : tous les lieux x jour (12 h) / nuit (21 h) x N répétitions ENTRELACÉES, fenêtre hors écran
# via /tmp/godot_slot.sh. Le banc lui-même est dans le jeu (scripts/banc_fps.gd, argument --banc-fps) : un JSON par lancement.
#   bash outils/banc_fps_exe.sh <Hollowrim.exe> [dossier_sortie]
#   bash outils/banc_fps_exe.sh editeur [dossier_sortie]        (même banc lancé par l'éditeur sur CE projet, pour comparer exe / éditeur)
# Variables : BANC_REPS (3), BANC_DUREE (20 s de mesure après 10 s de stabilisation), BANC_LIEUX ("temoin place foret halle grotte crypte combat"),
#   BANC_HEURES ("12 21"), GODOT (éditeur). Sortie : <dossier>/<lieu>_<heure>_<rep>.json (+ .charge = nombre maximal d'AUTRES Godot/Hollowrim
#   actifs pendant le lancement). Comparer deux dossiers : bash outils/compare_fps.sh <avant> <après>.
set -u
EXE="${1:?usage : banc_fps_exe.sh <exe|editeur> [dossier]}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
SORTIE="${2:-$ICI/captures/perf/banc_fps_$(date +%Y%m%d_%H%M)}"; mkdir -p "$SORTIE"
SW="$(wslpath -w "$SORTIE")"
REPS="${BANC_REPS:-3}"; DUREE="${BANC_DUREE:-20}"
LIEUX="${BANC_LIEUX:-temoin place foret halle grotte crypte combat}"; HEURES="${BANC_HEURES:-12 21}"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT=/tmp/godot_slot.sh
[[ -f "$SLOT" ]] || cp "$ICI/../godot_slot.sh" "$SLOT" 2>/dev/null
if [[ "$EXE" == editeur ]]; then CMD=("$G" --path "$(wslpath -w "$ICI")"); else CMD=("$EXE"); fi
nb_jeux() { tasklist.exe /fo csv /nh 2>/dev/null | tr -d '\r' | grep -aiE '^"(Godot|Hollowrim)' | grep -avic console; }
pose_de() { case "$1" in temoin) echo "--pose=2.5,8.5,16,4";; place) echo "--pose=35,30,221,-8";; *) echo "";; esac; }
for rep in $(seq 1 "$REPS"); do
	for lieu in $LIEUX; do
		for h in $HEURES; do
			base="${lieu}_${h}_${rep}"; autres=$(nb_jeux)
			( sleep 40; echo $(( $(nb_jeux) - 1 )) > "$SORTIE/$base.mi" ) &
			ECHANT=$!
			args=(--nouvelle --banc-fps="$lieu,$h,$DUREE" --banc-sortie="${SW//\\//}/$base.json"); [[ "$lieu" != "combat" ]] && args+=(--paisible)
			p="$(pose_de "$lieu")"; [[ -n "$p" ]] && args+=("$p")
			rm -f "$SORTIE/$base.json"
			GODOT_TIMEOUT=480 bash "$SLOT" "${CMD[@]}" --disable-vsync -- "${args[@]}" > "$SORTIE/$base.log" 2>&1
			rc=$?
			kill "$ECHANT" 2>/dev/null; wait "$ECHANT" 2>/dev/null
			apres=$(nb_jeux); mi=$(cat "$SORTIE/$base.mi" 2>/dev/null || echo 0); rm -f "$SORTIE/$base.mi"
			mx=$autres; [[ $mi -gt $mx ]] && mx=$mi; [[ $apres -gt $mx ]] && mx=$apres
			echo "$mx" > "$SORTIE/$base.charge"
			if [[ -s "$SORTIE/$base.json" ]]; then
				res=$(python3 -I -c 'import json,sys; r=json.load(open(sys.argv[1])); print("fps_moy=%.1f 1%%bas=%.1f dt_p99=%.2f >33=%d gpu_med=%.2f" % (r["fps_moy"], r["fps_1pc_bas"], r["dt_p99"], r["sup_33"], r["gpu_med"]))' "$SORTIE/$base.json" 2>/dev/null)
			else
				res="PAS DE JSON"
			fi
			echo "rep $rep $lieu $h : rc=$rc autres=$mx $res"
		done
	done
done
echo "résultats : $SORTIE"
