#!/usr/bin/env bash
# Captures du souffle de givre (galerie de la magie, couche fine) : cible à 6 m, vers le sol, dans le vide, en tournant ;
# crypte de nuit et neige de jour ; images PNG + vidéos en tournant (Movie Maker 30 i/s → mp4).
#   bash outils/captures_givre_vague.sh <dossier de sortie> [images|videos|tout]
# Toujours via godot_slot.sh (fenêtre hors écran, délai max).
set -u
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT=/mnt/c/Users/lopezk19/Jeux/godot_slot.sh
OUT="$1"; QUOI="${2:-tout}"
mkdir -p "$OUT"
W="$(wslpath -w "$OUT")"
if [ "$QUOI" != videos ]; then
	for lieu in crypte dehors; do
		GODOT_TIMEOUT=500 bash "$SLOT" "$G" --path "$P" --disable-vsync res://scenes/galerie_magie.tscn -- --lieu=$lieu \
			--plans=souffle_givre,souffle_givre_sol,souffle_givre_loin --instants=0.3,0.7,1.4,1.9 --captures="$W" 2>&1 | grep -E "CAPTURE|SCRIPT ERROR|ERROR" | head -20
	done
fi
if [ "$QUOI" != images ]; then
	TMPV="$OUT/_avi"; mkdir -p "$TMPV"; WV="$(wslpath -w "$TMPV")"
	for lieu in crypte dehors; do
		GODOT_TIMEOUT=500 bash "$SLOT" "$G" --path "$P" --write-movie "$WV\\${lieu}_tourne.avi" --fixed-fps 30 res://scenes/galerie_magie.tscn -- --lieu=$lieu --plans=souffle_givre,souffle_givre_loin --tourne=70 >/dev/null 2>&1
	done
	for f in "$TMPV"/*.avi; do
		[ -f "$f" ] || continue
		ffmpeg -loglevel error -y -i "$f" -vf "scale=1280:-2:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 18 "$OUT/$(basename "${f%.avi}").mp4"
	done
	rm -rf "$TMPV"
fi
ls "$OUT"
