#!/usr/bin/env bash
# Rendus du SANG V3 : planches avant/après (intérieur + neige), film ~15 s, banc FPS (avant/après).
#   bash outils/rendus_sang_v3.sh [planches|film|banc|tout]   → $SORTIE (défaut rendus/telekinesie_2026-11-23/sang)
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
SORTIE="${SORTIE:-/mnt/c/Users/lopezk19/Jeux/rendus/telekinesie_2026-11-23/sang}"
QUOI="${1:-tout}"
mkdir -p "$SORTIE"
lancer() { GODOT_TIMEOUT=900 bash /tmp/godot_slot.sh "$G" "$@"; }

if [[ "$QUOI" == planches || "$QUOI" == tout ]]; then
	for lieu in ${LIEUX:-interieur neige}; do
		for v in avant apres; do
			d="$SORTIE/_vues_${lieu}_${v}"; rm -rf "$d"; mkdir -p "$d"
			extra=(); [[ $v == avant ]] && extra=(--sans-sang-v3)
			lancer --path "$P" --disable-vsync --script res://outils/captures_sang_v3.gd -- --nouvelle --sortie="$(wslpath -w "$d")" --lieu=$lieu "${extra[@]}" 2>&1 | grep -E "VUE|TRACES|SCRIPT ERROR" | tail -12
		done
		# planche : rangée AVANT puis rangée APRÈS, 6 vues chacune (3 x 2 par état), 640x360 par vue
		ent=(); f=""; i=0
		for v in avant apres; do
			for n in 1 2 3 4 5 6; do
				im=$(ls "$SORTIE/_vues_${lieu}_${v}/vue_${n}_"*.png 2>/dev/null | head -1)
				[[ -z "$im" ]] && continue
				ent+=(-i "$im"); f+="[$i:v]scale=640:360:flags=neighbor[v$i];"; i=$((i+1))
			done
		done
		if [[ $i == 12 ]]; then
			lay=""; for r in 0 1 2 3; do for c in 0 1 2; do lay+="$((c*640))_$((r*360))|"; done; done
			ffmpeg -y -loglevel error "${ent[@]}" -filter_complex "${f}$(for k in $(seq 0 11); do printf '[v%d]' $k; done)xstack=inputs=12:layout=${lay%|}" "$SORTIE/planche_avant_apres_${lieu}.png"
			echo "PLANCHE $SORTIE/planche_avant_apres_${lieu}.png"
		else
			echo "planche $lieu : $i vues seulement"
		fi
	done
fi

if [[ "$QUOI" == film || "$QUOI" == tout ]]; then
	avi="$SORTIE/film_sang_v3.avi"
	lancer --path "$P" --write-movie "$(wslpath -w "$avi")" --fixed-fps 30 --script res://outils/captures_sang_v3.gd -- --nouvelle --film --lieu=neige 2>&1 | grep -E "SCRIPT ERROR" | head
	ffmpeg -y -loglevel error -i "$avi" -vf "scale=1280:720:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 18 "$SORTIE/film_sang_v3.mp4" && rm -f "$avi"
	echo "FILM $SORTIE/film_sang_v3.mp4"
fi

if [[ "$QUOI" == banc || "$QUOI" == tout ]]; then
	for v in avant apres avant apres; do
		extra=(); [[ $v == avant ]] && extra=(--sans-sang-v3)
		lancer --path "$P" --disable-vsync --script res://outils/captures_sang_v3.gd -- --nouvelle --banc --lieu=interieur "${extra[@]}" 2>&1 | grep -E "^BANC|SCRIPT ERROR"
	done
fi
