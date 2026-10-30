#!/usr/bin/env bash
# Captures du jet de flammes (galerie de la magie, couche fine) : déclenchement, en tournant, cible à 3 m et 8 m,
# crypte de nuit et neige de jour, double incantation ; images PNG + vidéos (Movie Maker 30 i/s → mp4).
#   bash outils/captures_jet_vague.sh <dossier de sortie> [images|videos|tout]
# Toujours via godot_slot.sh (fenêtre hors écran, délai max).
set -u
ICI="$(cd "$(dirname "$0")/.." && pwd)"
P="$(wslpath -w "$ICI")"
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
SLOT=/mnt/c/Users/lopezk19/Jeux/godot_slot.sh
OUT="$1"; QUOI="${2:-tout}"
mkdir -p "$OUT"
W="$(wslpath -w "$OUT")"
galerie() {   # $1 = suffixe de fichier, puis arguments de la galerie
	local suf="$1"; shift
	GODOT_TIMEOUT=400 timeout 1500 bash "$SLOT" "$G" --path "$P" --disable-vsync res://scenes/galerie_magie.tscn -- "$@" 2>&1 | grep -E "CAPTURE|ERROR|rror" | head -40
}
if [ "$QUOI" != videos ]; then
	for lieu in crypte dehors; do
		for d in 3 8; do
			galerie x --lieu=$lieu --cible=$d --plans=jet_feu,double_feu --instants=0.2,0.3,0.6,1.2 --captures="$W\\c$d"
		done
		galerie x --lieu=$lieu --plans=jet_feu_loin --instants=0.2,0.6,1.5 --captures="$W\\loin"
		galerie x --lieu=$lieu --cible=8 --plans=jet_feu,jet_feu_loin --tourne=70 --instants=1.0,1.3,1.6,1.9 --captures="$W\\tourne"
	done
fi
if [ "$QUOI" != images ]; then
	TMPV="$OUT/../_avi_$(basename "$OUT")"; mkdir -p "$TMPV"; WV="$(wslpath -w "$TMPV")"   # AVI bruts (gardés à côté)
	for lieu in crypte dehors; do
		GODOT_TIMEOUT=400 timeout 1500 bash "$SLOT" "$G" --path "$P" --write-movie "$WV\\$lieu.avi" --fixed-fps 30 res://scenes/galerie_magie.tscn -- --lieu=$lieu --cible=8 --plans=jet_feu,jet_feu_loin,double_feu >/dev/null 2>&1
		GODOT_TIMEOUT=400 timeout 1500 bash "$SLOT" "$G" --path "$P" --write-movie "$WV\\${lieu}_tourne.avi" --fixed-fps 30 res://scenes/galerie_magie.tscn -- --lieu=$lieu --cible=3 --plans=jet_feu,double_feu --tourne=70 >/dev/null 2>&1
	done
	for f in "$TMPV"/*.avi; do
		[ -f "$f" ] || continue
		ffmpeg -loglevel error -y -i "$f" -vf "scale=1280:-2:flags=neighbor" -c:v libx264 -pix_fmt yuv420p -crf 18 "$OUT/$(basename "${f%.avi}").mp4"
	done
fi
ls "$OUT"
