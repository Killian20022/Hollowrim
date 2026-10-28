#!/usr/bin/env bash
# Planches « feu sur le corps » (docs/MAGIE_IMPACT_CORPS.md) : par cas, RÉFÉRENCE (feu_fps_1100.jpg) | AVANT | APRÈS,
# puis une ligne de zoom ×2 sur le draugr (avant | après).
#   bash outils/planches_impact_feu.sh [dossier_avant] [dossier_apres]
# Entrées : captures/impact_feu/avant/<cas>_<t>.png (outil captures_impact_feu.gd --sans-impact-corps)
#           captures/impact_feu/apres/<cas>_<t>.png (outil captures_impact_feu.gd)
# Sorties : captures/impact_feu/planches/planche_<cas>_<t>.png (3840x1440) et ..._1100.jpg (1100 px de large).
set -eu
ICI="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ICI/../references/magie/feu_fps_1100.jpg"
AV="${1:-$ICI/captures/impact_feu/avant}"
AP="${2:-$ICI/captures/impact_feu/apres}"
OUT="$ICI/captures/impact_feu/planches"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
for f in "$AP"/*.png; do
	nom="$(basename "$f" .png)"
	case "$nom" in *_cote) continue;; esac
	[ -f "$AV/$nom.png" ] || { echo "pas d'avant pour $nom"; continue; }
	{
		printf '[Script Info]\nScriptType: v4.00+\nPlayResX: 3840\nPlayResY: 1440\n[V4+ Styles]\n'
		printf 'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n'
		printf 'Style: D,Arial,34,&H00FFFFFF,&H00FFFFFF,&H30000000,&H30000000,1,0,0,0,100,100,0,0,3,8,0,7,0,0,0,1\n[Events]\n'
		printf 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
		i=0
		for t in "Référence (feu_fps_1100.jpg)" "AVANT - $nom" "APRÈS - $nom" "" "AVANT - zoom x2" "APRÈS - zoom x2"; do
			printf 'Dialogue: 0,0:00:00.00,9:00:00.00,D,,0,0,0,,{\\pos(%d,%d)}%s\n' $(( (i % 3) * 1280 + 12 )) $(( (i / 3) * 720 + 10 )) "$t"
			i=$((i+1))
		done
	} > "$TMP/$nom.ass"
	ffmpeg -loglevel error -y -i "$REF" -i "$AV/$nom.png" -i "$f" -filter_complex "\
[0]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,split[r][r2];\
[1]scale=1280:720:flags=neighbor,split[a][a2];[2]scale=1280:720:flags=neighbor,split[b][b2];\
[r2]drawbox=c=black:t=fill[noir];\
[a2]crop=640:360:320:150,scale=1280:720:flags=neighbor[za];[b2]crop=640:360:320:150,scale=1280:720:flags=neighbor[zb];\
[r][a][b]hstack=inputs=3[l0];[noir][za][zb]hstack=inputs=3[l1];[l0][l1]vstack,ass=$TMP/$nom.ass:fontsdir=/mnt/c/Windows/Fonts" \
		"$OUT/planche_$nom.png"
	ffmpeg -loglevel error -y -i "$OUT/planche_$nom.png" -vf "scale=1100:-1:flags=area" -q:v 3 "$OUT/planche_${nom}_1100.jpg"
	echo "planche $nom : $OUT/planche_$nom.png"
done
rm -rf "$TMP"
