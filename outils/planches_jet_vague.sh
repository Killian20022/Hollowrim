#!/usr/bin/env bash
# Planches AVANT | APRÈS du jet de flammes (sorties de outils/captures_jet_vague.sh).
#   bash outils/planches_jet_vague.sh <dossier avant> <dossier après> <dossier des planches>
# Une planche par sujet : une ligne par prise (<sous-dossier>/<fichier sans .png>), avant à gauche, après à droite,
# tuiles de 960×540 (agrandissement au plus proche voisin), étiquettes en haut à gauche (filtre ass : ce ffmpeg n'a pas drawtext).
set -eu
AV="$1"; AP="$2"; OUT="$3"
mkdir -p "$OUT"
TMP="$(mktemp -d)"
planche() {   # $1 = nom, puis prises « sous-dossier/fichier|légende »
	local nom="$1"; shift
	local n=$# i=0 entrees=() filtre="" ass="$TMP/$nom.ass"
	{
		printf '[Script Info]\nScriptType: v4.00+\nPlayResX: 1920\nPlayResY: %d\n[V4+ Styles]\n' $((n * 540))
		printf 'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\n'
		printf 'Style: D,Arial,26,&H00FFFFFF,&H00FFFFFF,&H40000000,&H40000000,1,0,0,0,100,100,0,0,3,6,0,7,0,0,0,1\n[Events]\n'
		printf 'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'
	} > "$ass"
	for prise in "$@"; do
		local f="${prise%%|*}" leg="${prise#*|}"
		for cote in AV AP; do
			local src="${!cote}/$f.png"
			[ -f "$src" ] || { echo "manque : $src" >&2; src="$TMP/noir.png"; [ -f "$src" ] || ffmpeg -loglevel error -f lavfi -i color=c=black:s=1280x720 -frames:v 1 "$src"; }
			entrees+=(-i "$src")
		done
		printf 'Dialogue: 0,0:00:00.00,9:00:00.00,D,,0,0,0,,{\\pos(8,%d)}AVANT — %s\n' $((i * 540 + 6)) "$leg" >> "$ass"
		printf 'Dialogue: 0,0:00:00.00,9:00:00.00,D,,0,0,0,,{\\pos(968,%d)}APRÈS — %s\n' $((i * 540 + 6)) "$leg" >> "$ass"
		filtre+="[$((2*i)):v]scale=960:540:flags=neighbor[a$i];[$((2*i+1)):v]scale=960:540:flags=neighbor[b$i];[a$i][b$i]hstack[l$i];"
		i=$((i+1))
	done
	local pile=""
	for ((k=0; k<n; k++)); do pile+="[l$k]"; done
	if [ $n -gt 1 ]; then filtre+="${pile}vstack=inputs=$n[p];[p]ass=$ass[o]"; else filtre+="[l0]ass=$ass[o]"; fi
	ffmpeg -loglevel error -y "${entrees[@]}" -filter_complex "$filtre" -map "[o]" -frames:v 1 "$OUT/planche_$nom.png"
	ffmpeg -loglevel error -y -i "$OUT/planche_$nom.png" -vf "scale=1280:-2" -q:v 3 "$OUT/planche_${nom}_apercu.jpg"
	echo "$OUT/planche_$nom.png"
}
planche declenchement \
	"c3/crypte_fps_jet_feu_0.2|déclenchement, 1re image (crypte)" \
	"c3/crypte_fps_jet_feu_0.3|déclenchement +0,1 s (crypte)" \
	"c3/dehors_fps_jet_feu_0.2|déclenchement, 1re image (neige de jour)"
planche cible_3m \
	"c3/crypte_fps_jet_feu_0.6|cible à 3 m, 0,45 s de jet (crypte)" \
	"c3/crypte_fps_jet_feu_1.2|cible à 3 m, tenu (crypte)" \
	"c3/dehors_fps_jet_feu_1.2|cible à 3 m, tenu (neige de jour)"
planche cible_8m \
	"c8/crypte_fps_jet_feu_0.6|cible à 8 m, 0,45 s de jet (crypte)" \
	"c8/crypte_fps_jet_feu_1.2|cible à 8 m, tenu (crypte)" \
	"c8/dehors_fps_jet_feu_1.2|cible à 8 m, tenu (neige de jour)"
planche en_tournant \
	"tourne/crypte_fps_jet_feu_tourne_1.3|en tournant 70°/s, cible à 8 m (crypte)" \
	"tourne/crypte_fps_jet_feu_loin_tourne_1.6|en tournant 70°/s, dans le vide (crypte)" \
	"tourne/dehors_fps_jet_feu_tourne_1.6|en tournant 70°/s (neige de jour)"
planche double \
	"c3/crypte_fps_double_feu_1.2|double incantation, cible à 3 m (crypte)" \
	"c8/crypte_fps_double_feu_1.2|double incantation, cible à 8 m (crypte)" \
	"c8/dehors_fps_double_feu_1.2|double incantation, cible à 8 m (neige de jour)"
planche portee \
	"loin/crypte_fps_jet_feu_loin_1.5|dans le vide, portée entière (crypte)" \
	"loin/dehors_fps_jet_feu_loin_1.5|dans le vide, portée entière (neige de jour)"
