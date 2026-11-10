#!/usr/bin/env bash
# Planches AVANT | APRÈS de la passe palette Tripo (une par modèle), à partir des photos de outils/capture_palette_tripo.gd.
#   bash outils/planche_palette_tripo.sh <dossier des photos> <dossier de sortie>
# Chaque ligne = un plan : la photo « _avant » (réglages d'origine, --palette-tripo-ancienne) à gauche, « _apres » (PaletteTripo) à droite.
set -eu
SRC="${1:?dossier des photos}"
DST="${2:?dossier de sortie}"
mkdir -p "$DST"
planche() {   # $1 = nom de la planche, $2... = plans
	local nom="$1"; shift
	local args=() filtre="" n=0
	for p in "$@"; do
		args+=(-i "$SRC/${p}_avant.png" -i "$SRC/${p}_apres.png")
		filtre+="[$((2*n)):v][$((2*n+1)):v]hstack=inputs=2[l$n];"
		n=$((n+1))
	done
	if [ $n -eq 1 ]; then
		filtre="${filtre%;}"; filtre="${filtre%\[l0\]}"
	else
		for ((i=0; i<n; i++)); do filtre+="[l$i]"; done
		filtre+="vstack=inputs=$n"
	fi
	ffmpeg -hide_banner -loglevel error -y "${args[@]}" -filter_complex "$filtre" -frames:v 1 "$DST/planche_$nom.png"
	echo "PLANCHE $DST/planche_$nom.png ($n plans)"
}
planche armure_doree village_garde_dore village_garde_dore_gros
planche draugrs crypte_draugrs crypte_draugrs_gros
planche squelette crypte_squelettes crypte_squelettes_gros
planche gobelin grotte_gobelin grotte_gobelin_gros
planche puits village_puits
