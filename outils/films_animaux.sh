#!/usr/bin/env bash
# gen/animaux : un film par animal. bash outils/films_animaux.sh <dossier sortie> [animaux séparés par des virgules]
set -u
G="${GODOT:-/mnt/c/Users/lopezk19/Outils/godot/Godot_v4.7.2-stable_win64_console.exe}"
ICI="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?dossier}"; SEUL="${2:-}"
mkdir -p "$OUT"
ARG=""; [ -n "$SEUL" ] && ARG="--seulement=$SEUL ${3:-}"
GODOT_MAX=3 GODOT_TIMEOUT=1500 bash /tmp/godot_slot.sh "$G" --path "$(wslpath -w "$ICI")" --write-movie "$(wslpath -w "$OUT")\\tout.avi" --fixed-fps 30 --resolution 960x540 \
	--script res://outils/film_animaux.gd -- --nouvelle --sans-mains $ARG > "$OUT/film.log" 2>&1
grep -E "^SEGMENT|SCRIPT ERROR|FILM" "$OUT/film.log"
# découpe (SEGMENT nom i0 i1 : numéros d'image du jeu ; l'avi commence à la première image enregistrée)
