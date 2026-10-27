#!/usr/bin/env bash
# Planches « Détail des sorts » (docs/MAGIE_EFFETS.md) : pour chaque école, la référence de l'utilisateur, un zoom ×2 du
# rendu fin, puis AVANT (rendu rétro 640x360, agrandi ×2 au plus proche voisin) | APRÈS (couche fine) en main, jet, impact.
#   bash outils/planches_magie_detail.sh [lieu]     (lieu : crypte par défaut)
# Entrées : captures/magie_detail/avant/<lieu>_fps_<plan>.png (galerie --detail-sorts=retro, ou capture de 70c9098)
#           captures/magie_detail/galerie/<lieu>_fps_<plan>.png (galerie, détail élevé)
#           ../references/magie/<ecole>_fps_1100.jpg
# Sorties : captures/magie_detail/planches/planche_<ecole>.png (2560 px de large) et planche_<ecole>_apercu.jpg (1280 px).
set -eu
ICI="$(cd "$(dirname "$0")/.." && pwd)"
LIEU="${1:-crypte}"
REF="$ICI/../references/magie"
AV="$ICI/captures/magie_detail/avant"
AP="$ICI/captures/magie_detail/galerie"
OUT="$ICI/captures/magie_detail/planches"
mkdir -p "$OUT"
# école|référence|plan main|plan jet|plan impact|zoom (plan:x:y du recadrage 640x360 dans l'image 1280x720)
ECOLES=(
	"feu|feu_fps_1100.jpg|aura_feu|jet_feu|explosion_feu|jet_feu:330:250"
	"glace|glace_fps_1100.jpg|aura_glace|souffle_givre|nova_gelee|souffle_givre:250:250"
	"electricite|electricite_fps_1100.jpg|aura_electricite|arc_electrique|chaine_eclairs|arc_electrique:200:250"
	"tenebres|tenebres_fps_1100.jpg|aura_tenebres|drain_vie|explosion_obscure|drain_vie:250:250"
)
TMP="$(mktemp -d)"
etiquettes() {   # $1 = fichier .ass ; puis 8 textes (gauche/droite, ligne par ligne) ; planche 2560x2880
	# filtre ass (ce ffmpeg n'a pas drawtext), UNE fois sur la planche entière : plusieurs filtres ass dans le même
	# graphe partagent l'état de libass (toutes les tuiles affichaient le dernier texte)
	local f="$1"; shift
	{
		printf '[Script Info]\nScriptType: v4.00+\nPlayResX: 2560\nPlayResY: 2880\n[V4+ Styles]\n'
		printf 'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n'
		printf 'Style: D,Arial,30,&H00FFFFFF,&H00FFFFFF,&H30000000,&H30000000,1,0,0,0,100,100,0,0,3,8,0,7,0,0,0,1\n[Events]\n'
		printf 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
		local i=0
		for t in "$@"; do
			printf 'Dialogue: 0,0:00:00.00,9:00:00.00,D,,0,0,0,,{\\pos(%d,%d)}%s\n' $(( (i % 2) * 1280 + 10 )) $(( (i / 2) * 720 + 10 )) "$t"
			i=$((i+1))
		done
	} > "$f"
}
for e in "${ECOLES[@]}"; do
	IFS='|' read -r ecole ref p1 p2 p3 zoom <<< "$e"
	IFS=':' read -r pz zx zy <<< "$zoom"
	f() { echo "$1/${LIEU}_fps_$2.png"; }
	etiquettes "$TMP/$ecole.ass" "Référence ($ref)" "Après, zoom x2 ($pz)" "AVANT - rétro 640x360 - $p1" "APRÈS - couche fine - $p1" \
		"AVANT - $p2" "APRÈS - $p2" "AVANT - $p3" "APRÈS - $p3"
	ffmpeg -loglevel error -y \
		-i "$REF/$ref" -i "$(f "$AP" "$pz")" \
		-i "$(f "$AV" "$p1")" -i "$(f "$AP" "$p1")" \
		-i "$(f "$AV" "$p2")" -i "$(f "$AP" "$p2")" \
		-i "$(f "$AV" "$p3")" -i "$(f "$AP" "$p3")" \
		-filter_complex "\
[0]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2[r];\
[1]crop=640:360:$zx:$zy,scale=1280:720:flags=neighbor[z];\
[2]scale=1280:720:flags=neighbor[a1];[3]scale=1280:720:flags=neighbor[b1];\
[4]scale=1280:720:flags=neighbor[a2];[5]scale=1280:720:flags=neighbor[b2];\
[6]scale=1280:720:flags=neighbor[a3];[7]scale=1280:720:flags=neighbor[b3];\
[r][z]hstack[l0];[a1][b1]hstack[l1];[a2][b2]hstack[l2];[a3][b3]hstack[l3];[l0][l1][l2][l3]vstack=inputs=4,ass=$TMP/$ecole.ass:fontsdir=/mnt/c/Windows/Fonts" \
		"$OUT/planche_$ecole.png"
	ffmpeg -loglevel error -y -i "$OUT/planche_$ecole.png" -vf "scale=1280:-1:flags=area" -q:v 3 "$OUT/planche_${ecole}_apercu.jpg"
	echo "planche $ecole : $OUT/planche_$ecole.png"
done
