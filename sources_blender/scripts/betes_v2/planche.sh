#!/bin/bash
# Planche AVANT | APRÈS d'un animal (rendus Blender façon jeu) :
#   bash planche.sh <id_avant> <id_apres> <nom> [walk_frames] [run_frames]
# -> rendus/animaux_v2/<nom>_planche_480.png, <nom>_zoom3.png, <nom>_mouvement.gif
set -e
AV=$1; AP=$2; NOM=$3
WF=${4:-1,4,7,10,13,16,19,22}; RF=${5:-1,3,5,7,9,11,13}
BL=/mnt/c/Users/lopezk19/Outils/blender/blender.exe
WT='C:\Users\lopezk19\Jeux\nordique_animaux_v2'
OUTW='C:\Users\lopezk19\Jeux\rendus\animaux_v2'
OUT=/mnt/c/Users/lopezk19/Jeux/rendus/animaux_v2
TMPW="$OUTW\\tmp\\$NOM"; TMP="$OUT/tmp/$NOM"; mkdir -p "$TMP"
Q="$WT\\assets\\modeles\\persos_quat"
FONT=/mnt/c/Windows/Fonts/arial.ttf
rendre() { # id prefixe etiquette
  local tex=""; [ -f "/mnt/c/Users/lopezk19/Jeux/nordique_animaux_v2/assets/modeles/persos_quat/$1.png" ] && tex="tex=$Q\\$1.png"
  (cd /tmp && timeout 1500 $BL -b --python "$WT\\sources_blender\\scripts\\betes_v2\\rendu_planche.py" -- "glb=$Q\\$1.glb" $tex "sortie=$TMPW\\$2" \
    "anim=Walk:$WF;Run:$RF" "cadre_in=$TMPW\\cadre.json" "cadre_out=$TMPW\\cadre_$2.json" "etiquette=$3" "dist=${DIST:-1.0}" 2>&1 | grep -i "Traceback\|Error\|RENDU OK")
}
rm -f "$TMP/cadre.json"
rendre "$AV" av AVANT
cp "$TMP/cadre_av.json" "$TMP/cadre.json"
rendre "$AP" ap APRES
lab() { echo "null"; }
# 1. vues à 480x270 : lignes AVANT / APRÈS ; colonnes face, profil, 3/4 (jour), 3/4 et profil (nuit)
for v in av ap; do
  L=AVANT; [ $v = ap ] && L=APRES
  ffmpeg -loglevel error -y -i "$TMP/${v}_jour_face.png" -i "$TMP/${v}_jour_profil.png" -i "$TMP/${v}_jour_trois_quarts.png" \
    -i "$TMP/${v}_nuit_trois_quarts.png" -i "$TMP/${v}_nuit_profil.png" \
    -filter_complex "[0]$(lab "$L - face - jour")[a];[1]$(lab "profil - jour")[b];[2]$(lab "3/4 - jour")[c];[3]$(lab "3/4 - nuit")[d];[4]$(lab "profil - nuit")[e];[a][b][c][d][e]hstack=inputs=5" "$TMP/ligne_$v.png"
done
ffmpeg -loglevel error -y -i "$TMP/ligne_av.png" -i "$TMP/ligne_ap.png" -filter_complex vstack "$OUT/${NOM}_planche_480.png"
# 2. zoom x3 (pixels nets) du centre de la vue 3/4, jour et nuit
for e in jour nuit; do for v in av ap; do
  ffmpeg -loglevel error -y -i "$TMP/${v}_${e}_trois_quarts.png" -vf "crop=240:150:120:60,scale=720:450:flags=neighbor" "$TMP/z_${v}_${e}.png"
done; done
ffmpeg -loglevel error -y -i "$TMP/z_av_jour.png" -i "$TMP/z_ap_jour.png" -i "$TMP/z_av_nuit.png" -i "$TMP/z_ap_nuit.png" \
  -filter_complex "[0]$(lab "AVANT - jour - zoom x3")[a];[1]$(lab "APRES - jour - zoom x3")[b];[2]$(lab "AVANT - nuit")[c];[3]$(lab "APRES - nuit")[d];[a][b][c][d]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0" "$OUT/${NOM}_zoom3.png"
# 3. mouvement : Walk puis Run, avant | après, jour (haut) / nuit (bas), x2
for v in av ap; do for e in jour nuit; do
  i=0; rm -f "$TMP/seq_${v}_${e}_"*.png
  for f in "$TMP/${v}_${e}_Walk_"*.png "$TMP/${v}_${e}_Run_"*.png; do cp "$f" "$TMP/seq_${v}_${e}_$(printf %03d $i).png"; i=$((i+1)); done
done; done
ffmpeg -loglevel error -y -framerate 8 -i "$TMP/seq_av_jour_%03d.png" -framerate 8 -i "$TMP/seq_ap_jour_%03d.png" \
  -framerate 8 -i "$TMP/seq_av_nuit_%03d.png" -framerate 8 -i "$TMP/seq_ap_nuit_%03d.png" \
  -filter_complex "[0]$(lab "AVANT - marche puis course")[a];[1]$(lab "APRES")[b];[2]$(lab "AVANT - nuit")[c];[3]$(lab "APRES - nuit")[d];[a][b][c][d]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0,scale=iw*2:ih*2:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=255:stats_mode=full[p];[s1][p]paletteuse=dither=none" \
  -loop 0 "$OUT/${NOM}_mouvement.gif"
echo "PLANCHE $OUT/${NOM}_planche_480.png $OUT/${NOM}_zoom3.png $OUT/${NOM}_mouvement.gif"
